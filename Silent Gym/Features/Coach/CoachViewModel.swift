//
//  CoachViewModel.swift
//  Silent Gym
//
//  Phase 5 rewrite.
//  Key additions:
//  • Streaming AI replies via OpenAICommandClient.streamChat
//  • Character-by-character typewriter animation (15 ms / char)
//  • Dynamic system prompt with last-3-session training context
//    + Home Gym equipment inventory
//  • Graceful fallback to CoachCommandRouter when AI is disabled
//

import Foundation
import Combine
import SwiftData
#if os(iOS)
import UIKit
#endif

// MARK: - Chat message model

/// Mutable content to support in-place streaming updates.
struct ChatMessage: Identifiable {
    let id: UUID
    var content: String
    let isUser: Bool
    let timestamp: Date

    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = .now) {
        self.id        = id
        self.content   = content
        self.isUser    = isUser
        self.timestamp = timestamp
    }
}

// MARK: - ViewModel

@MainActor
final class CoachViewModel: ObservableObject {

    // MARK: Published state

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var pendingAction: AppAction?
    @Published var showConfirmSheet = false
    @Published var useOpenAI = false
    @Published private(set) var isStreaming = false

    /// Increments every streaming chunk — lets the View observe content growth
    /// for auto-scroll even when message count is unchanged.
    @Published private(set) var streamGeneration: Int = 0

    // MARK: Dependencies

    private let coordinator: SessionCoordinator
    private var modelContext: ModelContext
    private var streamTask: Task<Void, Never>?

    // In-memory conversation history sent to OpenAI (assistant + user turns).
    // Keeps the last N turns to manage context length.
    private var chatHistory: [OpenAIMessage] = []
    private static let maxHistoryTurns = 8

    // MARK: Init

    init(coordinator: SessionCoordinator) {
        self.coordinator = coordinator
        self.modelContext = ModelContext(PersistenceController.shared.container)
    }

    // MARK: - Public interface

    func updateModelContext(_ context: ModelContext) {
        modelContext = context
        coordinator.modelContext = context
    }

    /// Main entry — decides between command execution and free AI chat.
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard !isStreaming else { return }

        let command = inputText.trimmingCharacters(in: .whitespaces)
        inputText = ""

        let userMsg = ChatMessage(content: command, isUser: true)
        messages.append(userMsg)

        // Always try the local router first (instant, no network).
        if let action = CoachCommandRouter.parse(command) {
            handleAction(action, rawInput: command)
            return
        }

        // If no structural command matched, route to AI.
        if useOpenAI {
            #if os(iOS)
            streamAIReply(for: command)
            #else
            appendAssistant("AI 教练仅在 iOS 上可用。")
            #endif
        } else {
            appendAssistant("未识别命令。可尝试：\n• 开始 Day A\n• 结束训练\n• 跳过休息\n• 总结")
        }
    }

    func sendQuick(_ text: String) {
        inputText = text
        sendMessage()
    }

    func confirmPendingAction() {
        guard let action = pendingAction else { return }
        execute(action)
        showConfirmSheet = false
        pendingAction    = nil
    }

    func cancelPendingAction() {
        showConfirmSheet = false
        pendingAction    = nil
    }

    /// Cancel an in-progress stream (e.g., user taps stop button).
    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        if isStreaming {
            isStreaming = false
            // Mark last message as interrupted
            if let idx = messages.indices.last(where: { !messages[$0].isUser }) {
                if messages[idx].content.isEmpty {
                    messages.remove(at: idx)
                } else {
                    messages[idx].content += " ✦"
                }
            }
        }
    }

    // MARK: - Streaming AI reply

    #if os(iOS)
    private func streamAIReply(for userText: String) {
        guard OpenAICommandClient.shared.isConfigured else {
            appendAssistant("请先在设置中配置 OpenAI API Key。")
            return
        }

        let systemPrompt = buildSystemPrompt()

        // Create an empty placeholder bubble that we'll fill via streaming.
        var assistantMsg = ChatMessage(content: "", isUser: false)
        let msgId = assistantMsg.id
        messages.append(assistantMsg)

        isStreaming = true
        var fullReply = ""

        streamTask = Task {
            do {
                let stream = OpenAICommandClient.shared.streamChat(
                    userMessage: userText,
                    history: chatHistory,
                    systemPrompt: systemPrompt
                )

                for try await chunk in stream {
                    guard !Task.isCancelled else { break }

                    // Typewriter: yield each character with a small delay for realism.
                    for char in chunk {
                        guard !Task.isCancelled else { break }
                        fullReply.append(char)

                        // Update the message in-place.
                        if let idx = messages.firstIndex(where: { $0.id == msgId }) {
                            messages[idx].content = fullReply
                        }
                        streamGeneration &+= 1

                        // 15 ms per character → ~67 chars/sec — feels natural.
                        try? await Task.sleep(nanoseconds: 15_000_000)
                    }
                }
            } catch {
                if let idx = messages.firstIndex(where: { $0.id == msgId }) {
                    if messages[idx].content.isEmpty {
                        messages[idx].content = "抱歉，请求失败：\(error.localizedDescription)"
                    }
                }
            }

            isStreaming = false
            streamTask  = nil

            // Commit to conversation history (only if non-empty reply).
            if !fullReply.isEmpty {
                trimHistory()
                chatHistory.append(OpenAIMessage(role: "user",      content: userText))
                chatHistory.append(OpenAIMessage(role: "assistant", content: fullReply))
            }
        }
    }

    // MARK: - Dynamic system prompt + context injection

    /// Builds the system prompt injected with:
    /// (a) Last 3 training session summaries
    /// (b) Home Gym equipment list from EquipmentManager
    func buildSystemPrompt() -> String {
        var parts: [String] = []

        parts.append("""
        你是 Silent Gym 的 AI 训练教练，具备专业健身知识和对用户当前身体状态的深度感知能力。
        请用中文回答。回答要简洁专业，避免不必要的废话，对用户的具体问题给出可执行的建议。
        """)

        // ── Equipment context ────────────────────────────────────────────────
        let equipment = EquipmentManager.shared.availableEquipment
        if equipment.isEmpty {
            parts.append("## 当前训练环境\n- 无特定器材（自重训练）")
        } else {
            let list = equipment.map { "- \($0.rawValue)" }.sorted().joined(separator: "\n")
            parts.append("## 当前训练环境（Home Gym 可用器材）\n\(list)")
        }

        // ── Recent session context ────────────────────────────────────────────
        let sessions = fetchRecentSessions(limit: 3)
        if sessions.isEmpty {
            parts.append("## 训练历史\n- 暂无历史训练记录")
        } else {
            var sessionSummaries = "## 最近训练摘要（最近 \(sessions.count) 次）"
            for session in sessions {
                sessionSummaries += "\n\n**\(formatSessionDate(session.startAt))**"
                sessionSummaries += "\n\(buildSessionSummary(session))"
            }
            parts.append(sessionSummaries)
        }

        // ── Current session status ────────────────────────────────────────────
        if let current = coordinator.currentSession {
            let status = "## 当前训练\n- 计划：\(current.routineNameSnapshot ?? "未知")\n- 状态：进行中"
            parts.append(status)
        }

        parts.append("""
        ## 指导原则
        - 根据当前器材环境提供可执行的动作替代建议
        - 参考最近训练的肌肉疲劳状态，合理分配训练强度
        - 若用户需要动作替代，优先推荐其拥有器材可完成的变体
        - 建议要具体（给出重量、次数、组数），不要泛泛而谈
        """)

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Session data helpers

    private func fetchRecentSessions(limit: Int) -> [Session] {
        var desc = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\Session.startAt, order: .reverse)]
        )
        desc.fetchLimit = limit
        return (try? modelContext.fetch(desc)) ?? []
    }

    private func buildSessionSummary(_ session: Session) -> String {
        var lines: [String] = []
        var totalVolume = 0.0
        var maxWeight   = 0.0
        var muscleGroups = Set<String>()

        for se in session.exercises ?? [] {
            let name = (se.exercise?.name ?? "").lowercased()
            for set in se.sets ?? [] where set.isCompleted {
                let w = set.weightKg ?? 0
                totalVolume += w * Double(set.reps)
                maxWeight    = max(maxWeight, w)
            }
            muscleGroups.formUnion(inferMuscleGroups(from: name))
        }

        let routineName = session.routineNameSnapshot
        if !routineName.isEmpty {
            lines.append("计划：\(routineName)")
        }
        if !muscleGroups.isEmpty {
            lines.append("训练部位：\(muscleGroups.sorted().joined(separator: "、"))")
        }
        if totalVolume > 0 {
            lines.append("总容量：\(Int(totalVolume)) kg·次")
        }
        if maxWeight > 0 {
            lines.append("最大重量：\(Int(maxWeight)) kg")
        }
        if let end = session.endAt {
            let minutes = Int(end.timeIntervalSince(session.startAt) / 60)
            lines.append("时长：\(minutes) 分钟")
        }

        return lines.isEmpty ? "（无详细数据）" : lines.map { "  \($0)" }.joined(separator: "\n")
    }

    private func inferMuscleGroups(from exerciseName: String) -> Set<String> {
        var groups = Set<String>()
        let name = exerciseName
        let matches: [(keywords: [String], group: String)] = [
            (["bench", "push", "chest", "胸", "卧推", "俯卧撑", "夹胸"], "胸"),
            (["row", "pull", "lat", "背", "划船", "引体", "高位"], "背"),
            (["squat", "leg", "lunge", "腿", "深蹲", "弓步", "腿推", "腿弯"], "腿"),
            (["shoulder", "press", "delt", "肩", "推举", "侧平"], "肩"),
            (["curl", "bicep", "hammer", "二头", "弯举"], "二头"),
            (["tricep", "dip", "extension", "三头", "臂屈伸", "下压"], "三头"),
            (["core", "plank", "crunch", "abs", "核心", "平板", "卷腹"], "核心"),
            (["deadlift", "hip", "glute", "臀", "硬拉", "臀推"], "臀"),
        ]
        for (keywords, group) in matches {
            if keywords.contains(where: { name.contains($0) }) {
                groups.insert(group)
            }
        }
        return groups
    }

    private func formatSessionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    private func trimHistory() {
        // Keep only the last maxHistoryTurns message pairs.
        let maxMessages = Self.maxHistoryTurns * 2
        if chatHistory.count > maxMessages {
            chatHistory = Array(chatHistory.suffix(maxMessages))
        }
    }
    #endif

    // MARK: - Action execution

    private func handleAction(_ action: AppAction, rawInput: String) {
        if needsConfirmation(for: action) {
            pendingAction    = action
            showConfirmSheet = true
        } else {
            execute(action)
        }
    }

    private func needsConfirmation(for action: AppAction) -> Bool {
        switch action {
        case .startRoutine, .endSession, .addToCalendar: return true
        default: return false
        }
    }

    func execute(_ action: AppAction) {
        switch action {
        case .startRoutine(let nameOrId):
            let descriptor = FetchDescriptor<Routine>()
            if let routines = try? modelContext.fetch(descriptor),
               let routine  = routines.first(where: { $0.name == nameOrId || $0.id.uuidString == nameOrId }) {
                _ = coordinator.startSession(routineId: routine.id)
                appendAssistant("已开始「\(routine.name)」训练 💪")
            } else {
                appendAssistant("未找到训练计划「\(nameOrId)」，请检查计划名称。")
            }

        case .endSession:
            coordinator.endSession()
            appendAssistant("训练已结束，干得漂亮！🎉")

        case .updateExerciseConfig(let name, _, _):
            appendAssistant("已更新「\(name)」的配置。")

        case .extendRest(let seconds):
            coordinator.extendRest(by: seconds)
            appendAssistant("休息延长 \(seconds) 秒，放松一下 😌")

        case .skipRest:
            coordinator.skipRest()
            appendAssistant("已跳过休息，继续冲！")

        case .addToCalendar(let sessionId):
            addToCalendar(sessionId: sessionId)

        case .summarize(let period):
            appendAssistant(generateSummary(period: period))
        }
    }

    // MARK: - Calendar

    private func addToCalendar(sessionId: UUID?) {
        #if os(iOS)
        let targetSession: Session?
        if let id = sessionId {
            let d = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
            targetSession = try? modelContext.fetch(d).first
        } else {
            targetSession = coordinator.currentSession
        }

        guard let session = targetSession else {
            appendAssistant("没有可添加到日历的训练。")
            return
        }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController
        else {
            appendAssistant("无法访问视图控制器。")
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }

        CalendarManager.shared.createEventForSession(session: session, presentingViewController: topVC) { [weak self] eventId in
            guard let self else { return }
            if let eventId {
                session.calendarEventId = eventId
                try? modelContext.save()
                appendAssistant("已成功添加到日历 📅")
            } else {
                appendAssistant("添加到日历失败，请检查日历权限。")
            }
        }
        #endif
    }

    // MARK: - Summary (local fallback)

    private func generateSummary(period: String) -> String {
        let desc = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\Session.startAt, order: .reverse)]
        )
        guard let sessions = try? modelContext.fetch(desc), !sessions.isEmpty else {
            return "暂无训练数据。"
        }

        let cutoff: Date
        if period.contains("月") {
            cutoff = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
        } else if period.contains("两周") {
            cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        } else {
            cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: .now) ?? .now
        }

        let filtered = sessions.filter { $0.startAt >= cutoff }
        if filtered.isEmpty { return "该时间段内暂无训练记录。" }

        var totalVolume = 0.0
        var totalSets   = 0
        for s in filtered {
            for se in s.exercises ?? [] {
                for set in se.sets ?? [] where set.isCompleted {
                    totalVolume += (set.weightKg ?? 0) * Double(set.reps)
                    totalSets   += 1
                }
            }
        }

        return """
        📊 \(period)训练总结
        ・训练次数：\(filtered.count) 次
        ・完成组数：\(totalSets) 组
        ・累计容量：\(Int(totalVolume)) kg·次
        """
    }

    // MARK: - Helpers

    private func appendAssistant(_ content: String) {
        messages.append(ChatMessage(content: content, isUser: false))
    }
}
