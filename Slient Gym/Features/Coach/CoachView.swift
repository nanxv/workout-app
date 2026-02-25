//
//  CoachView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import SwiftData

struct CoachView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var sessionCoordinator: SessionCoordinator
    @Query(sort: \Routine.name) private var routines: [Routine]
    @State private var inputText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var pendingAction: AppAction?
    @State private var showConfirmSheet = false
    @State private var useOpenAI = false // 切换本地/OpenAI 解析
    
    init() {
        // Initialize with a temporary context, will be updated in onAppear
        let tempContext = ModelContext(PersistenceController.shared.container)
        _sessionCoordinator = StateObject(wrappedValue: SessionCoordinator(modelContext: tempContext))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if messages.isEmpty {
                                emptyStateView
                            }
                        }
                        .padding()
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: messages.count) { _, _ in
                        if let lastId = messages.last?.id {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                quickActionsBar
                
                HStack {
                    TextField("询问教练...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: {
                        sendMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("教练")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle("使用 AI", isOn: $useOpenAI)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                sessionCoordinator.modelContext = modelContext
            }
            .animation(.easeInOut(duration: 0.2), value: messages.count)
            .sheet(isPresented: $showConfirmSheet) {
                if let action = pendingAction {
                    ConfirmActionSheet(action: action, onConfirm: {
                        executeAction(action)
                        showConfirmSheet = false
                        pendingAction = nil
                    }, onCancel: {
                        showConfirmSheet = false
                        pendingAction = nil
                    })
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userMessage = ChatMessage(content: inputText, isUser: true)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            messages.append(userMessage)
        }
        
        let command = inputText
        inputText = ""
        
        // Parse command (local or OpenAI)
        Task {
            let action: AppAction?
            
            if useOpenAI {
                // Use OpenAI (requires backend)
                #if os(iOS)
                let context = AppContext(
                    currentState: String(describing: sessionCoordinator.state),
                    currentRoutine: sessionCoordinator.currentSession?.routineNameSnapshot,
                    currentExercise: nil, // Could be enhanced
                    availableRoutines: []
                )
                action = await OpenAICommandClient.shared.processCommand(command, context: context)
                #else
                action = CoachCommandRouter.parse(command)
                #endif
            } else {
                // Use local parser
                action = CoachCommandRouter.parse(command)
            }
            
            await MainActor.run {
                if let action = action {
                    let needsConfirmation = needsConfirmationForAction(action)
                    
                    if needsConfirmation {
                        pendingAction = action
                        showConfirmSheet = true
                    } else {
                        executeAction(action)
                    }
                } else {
                    let coachMessage = ChatMessage(
                        content: "I didn't understand that command. Try:\n- 开始 Day A\n- 结束训练\n- 跳过休息\n- 总结",
                        isUser: false
                    )
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        messages.append(coachMessage)
                    }
                }
            }
        }
    }

    private func sendQuick(_ text: String) {
        inputText = text
        sendMessage()
    }
    
    private func needsConfirmationForAction(_ action: AppAction) -> Bool {
        switch action {
        case .startRoutine, .endSession, .addToCalendar:
            return true
        default:
            return false
        }
    }
    
    private func executeAction(_ action: AppAction) {
        switch action {
        case .startRoutine(let nameOrId):
            // Find routine by name or ID
            let descriptor = FetchDescriptor<Routine>()
            if let routines = try? modelContext.fetch(descriptor),
               let routine = routines.first(where: { $0.name == nameOrId || $0.id.uuidString == nameOrId }) {
                _ = sessionCoordinator.startSession(routineId: routine.id)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    messages.append(ChatMessage(content: "Started \(routine.name)", isUser: false))
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    messages.append(ChatMessage(content: "Routine '\(nameOrId)' not found", isUser: false))
                }
            }
            
        case .endSession:
            sessionCoordinator.endSession()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                messages.append(ChatMessage(content: "Session ended", isUser: false))
            }
            
        case .updateExerciseConfig(let exerciseName, _, _):
            // This would update the current routine's exercise config
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                messages.append(ChatMessage(content: "Updated \(exerciseName) config", isUser: false))
            }
            
        case .extendRest(let seconds):
            sessionCoordinator.extendRest(by: seconds)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                messages.append(ChatMessage(content: "Extended rest by \(seconds) seconds", isUser: false))
            }
            
        case .skipRest:
            sessionCoordinator.skipRest()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                messages.append(ChatMessage(content: "Skipped rest", isUser: false))
            }
            
        case .addToCalendar(let sessionId):
            // Add to calendar
            if let sessionId = sessionId {
                // Find session by ID
                let descriptor = FetchDescriptor<Session>(
                    predicate: #Predicate { $0.id == sessionId }
                )
                if let session = try? modelContext.fetch(descriptor).first {
                    addSessionToCalendar(session: session)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        messages.append(ChatMessage(content: "未找到训练记录", isUser: false))
                    }
                }
            } else if let currentSession = sessionCoordinator.currentSession {
                addSessionToCalendar(session: currentSession)
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    messages.append(ChatMessage(content: "没有活动训练可添加到日历", isUser: false))
                }
            }
            
        case .summarize(let period):
            let summary = generateSummary(period: period)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                messages.append(ChatMessage(content: summary, isUser: false))
            }
        }
    }
    
    private func generateSummary(period: String) -> String {
        // Simple summary for now
        let descriptor = FetchDescriptor<Session>()
        if let sessions = try? modelContext.fetch(descriptor) {
            return "您已记录 \(sessions.count) 次训练。"
        }
        return "暂无训练数据。"
    }
    
    #if os(iOS)
    private func addSessionToCalendar(session: Session) {
        // Get the root view controller to present EKEventEditViewController
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                messages.append(ChatMessage(content: "无法访问视图控制器", isUser: false))
            }
            return
        }
        
        // Find the topmost view controller
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        
        CalendarManager.shared.createEventForSession(
            session: session,
            presentingViewController: topViewController
        ) { eventId in
            if let eventId = eventId {
                session.calendarEventId = eventId
                try? modelContext.save()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    messages.append(ChatMessage(content: "已成功添加到日历", isUser: false))
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    messages.append(ChatMessage(content: "添加到日历失败", isUser: false))
                }
            }
        }
    }
    #endif
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            Text(message.content)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color(.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(8)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

extension CoachView {
    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("你可以这样问")
                .font(.subheadline)
                .foregroundColor(.secondary)
            ForEach(samplePrompts, id: \.self) { prompt in
                Button(prompt) {
                    sendQuick(prompt)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("开始训练") {
                    if let routine = routines.first {
                        sendQuick("开始 \(routine.name)")
                    } else {
                        sendQuick("开始训练")
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("结束训练") {
                    sendQuick("结束训练")
                }
                .buttonStyle(.bordered)
                
                Button("跳过休息") {
                    sendQuick("跳过休息")
                }
                .buttonStyle(.bordered)
                
                Button("总结") {
                    sendQuick("总结")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
    }
    
    private var samplePrompts: [String] {
        [
            "开始 Day A",
            "跳过休息",
            "延长休息 30 秒",
            "总结"
        ]
    }
}

struct ConfirmActionSheet: View {
    let action: AppAction
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("确认操作")
                    .font(.title2)
                    .bold()
                
                Text(actionDescription)
                    .multilineTextAlignment(.center)
                    .padding()
                
                HStack(spacing: 20) {
                    Button("取消", role: .cancel) {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("确认") {
                        onConfirm()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
    
    private var actionDescription: String {
        switch action {
        case .startRoutine(let name):
            return "开始训练计划：\(name)？"
        case .endSession:
            return "结束当前训练？"
        case .addToCalendar:
            return "将此训练添加到日历？"
        default:
            return "执行此操作？"
        }
    }
}

#Preview {
    CoachView()
        .modelContainer(for: [Routine.self], inMemory: true)
}