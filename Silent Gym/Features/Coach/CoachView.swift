//
//  CoachView.swift
//  Silent Gym
//
//  Phase 5 rewrite.
//  Key additions:
//  • Live streaming chat bubbles that fill character-by-character
//  • Auto-scroll on message count change AND on streaming chunk arrival
//  • Stop button cancels in-progress stream
//  • API Key setup prompt when AI is enabled but not configured
//  • Improved bubble design: user (right/accent) vs assistant (left/surface)
//

import SwiftUI
import SwiftData

struct CoachView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.name) private var routines: [Routine]
    @StateObject private var vm: CoachViewModel
    @State private var showAPIKeySetup = false

    init(coordinator: SessionCoordinator) {
        _vm = StateObject(wrappedValue: CoachViewModel(coordinator: coordinator))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageScrollView
                Divider()
                quickActionsBar
                inputBar
            }
            .navigationTitle("AI 教练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { trailingMenu }
            .onAppear {
                vm.updateModelContext(modelContext)
            }
            .sheet(isPresented: $vm.showConfirmSheet) {
                if let action = vm.pendingAction {
                    ConfirmActionSheet(
                        action: action,
                        onConfirm: { vm.confirmPendingAction() },
                        onCancel:  { vm.cancelPendingAction()  }
                    )
                }
            }
            .sheet(isPresented: $showAPIKeySetup) {
                APIKeySetupView()
            }
        }
    }

    // MARK: - Message scroll view

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if vm.messages.isEmpty {
                        emptyStateView
                            .padding(.top, 40)
                    } else {
                        ForEach(vm.messages) { message in
                            ChatBubble(message: message, isStreaming: isLastStreamingBubble(message))
                                .id(message.id)
                        }
                    }
                    // Invisible bottom anchor — always scrolls here.
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            // Scroll when a new message arrives.
            .onChange(of: vm.messages.count) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)
            }
            // Scroll while streaming content grows (message count unchanged).
            .onChange(of: vm.streamGeneration) { _, _ in
                scrollToBottom(proxy: proxy, animated: false)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func isLastStreamingBubble(_ message: ChatMessage) -> Bool {
        guard vm.isStreaming, !message.isUser else { return false }
        return message.id == vm.messages.last(where: { !$0.isUser })?.id
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("询问教练…", text: $vm.inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if !vm.isStreaming { vm.sendMessage() }
                }
                .disabled(vm.isStreaming)

            if vm.isStreaming {
                Button(action: { vm.cancelStream() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            } else {
                Button(action: { vm.sendMessage() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(vm.inputText.isEmpty ? Color.secondary : Color.primary)
                }
                .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Quick actions

    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickChip("开始训练 🏋️") {
                    if let r = routines.first { vm.sendQuick("开始 \(r.name)") }
                    else { vm.sendQuick("开始训练") }
                }
                quickChip("结束训练") { vm.sendQuick("结束训练") }
                quickChip("跳过休息") { vm.sendQuick("跳过休息") }
                quickChip("总结本周") { vm.sendQuick("总结本周训练") }
                quickChip("今日建议") { vm.sendQuick("根据我的训练历史和现有器材，给我一个今天的训练建议") }
                quickChip("疲劳分析") { vm.sendQuick("分析我最近训练的肌肉疲劳状态，哪些部位需要休息？") }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func quickChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(vm.isStreaming)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var trailingMenu: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Toggle(isOn: $vm.useOpenAI) {
                    Label("使用 AI 教练", systemImage: "brain")
                }
                if vm.useOpenAI {
                    Button {
                        showAPIKeySetup = true
                    } label: {
                        Label("配置 API Key", systemImage: "key.fill")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    vm.messages.removeAll()
                } label: {
                    Label("清空对话", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("AI 训练教练")
                .font(.title3.weight(.semibold))

            Text(vm.useOpenAI
                 ? "AI 模式已开启，我会结合你的训练历史和器材环境给出建议。"
                 : "可直接发送指令，或开启 AI 模式获得智能建议。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 6) {
                Text("试试这些问题：")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(samplePrompts, id: \.self) { prompt in
                    Button(prompt) { vm.sendQuick(prompt) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private let samplePrompts = [
        "根据我的器材，推荐今天训练什么",
        "分析我最近的肌肉疲劳状态",
        "开始 Day A",
        "跳过休息"
    ]
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    var isStreaming: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.isUser {
                Spacer(minLength: 48)
                bubble
            } else {
                assistantAvatar
                bubble
                Spacer(minLength: 48)
            }
        }
    }

    private var assistantAvatar: some View {
        Image(systemName: "brain.head.profile")
            .font(.caption)
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(Color.accentColor.gradient, in: Circle())
    }

    private var bubble: some View {
        Group {
            if message.isUser {
                Text(message.content)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.accentColor, in: BubbleShape(corners: [.topLeft, .topRight, .bottomLeft]))
                    .foregroundStyle(.white)
            } else {
                ZStack(alignment: .bottomTrailing) {
                    Text(message.content.isEmpty ? " " : message.content)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.secondarySystemBackground, in: BubbleShape(corners: [.topLeft, .topRight, .bottomRight]))
                        .foregroundStyle(.primary)

                    if isStreaming {
                        // Blinking cursor
                        BlinkingCursor()
                            .padding(6)
                    }
                }
            }
        }
        .font(.body)
        .textSelection(.enabled)
    }
}

// MARK: - Bubble shape

struct BubbleShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Blinking cursor

private struct BlinkingCursor: View {
    @State private var visible = true
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.accentColor)
            .frame(width: 2, height: 14)
            .opacity(visible ? 1 : 0)
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: visible)
            .onAppear { visible = false }
    }
}

// MARK: - Background extension (cross-platform)

private extension ShapeStyle where Self == Color {
    static var secondarySystemBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }
}

// MARK: - API Key Setup Sheet

struct APIKeySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = OpenAICommandClient.shared.config.apiKey
    @State private var baseURL: String = OpenAICommandClient.shared.config.baseURL
    @State private var model: String = OpenAICommandClient.shared.config.model

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-…", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("建议使用后端代理保护 API Key。直接填写仅供开发测试。")
                }

                Section("API 端点（可选）") {
                    TextField("https://api.openai.com/v1", text: $baseURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("gpt-4o-mini", text: $model)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("AI 配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        OpenAICommandClient.shared.configure(
                            apiKey: apiKey,
                            baseURL: baseURL.isEmpty ? nil : baseURL,
                            model: model.isEmpty ? nil : model
                        )
                        dismiss()
                    }
                    .disabled(apiKey.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Confirm Sheet

struct ConfirmActionSheet: View {
    let action: AppAction
    let onConfirm: () -> Void
    let onCancel:  () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: actionIcon)
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)

                Text("确认操作")
                    .font(.title2.bold())

                Text(actionDescription)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                HStack(spacing: 16) {
                    Button("取消", role: .cancel) { onCancel() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                    Button("确认") { onConfirm() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
            .padding(32)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private var actionDescription: String {
        switch action {
        case .startRoutine(let name): return "开始训练计划：\(name)？"
        case .endSession:             return "结束当前训练并保存记录？"
        case .addToCalendar:          return "将此训练添加到系统日历？"
        default:                      return "执行此操作？"
        }
    }

    private var actionIcon: String {
        switch action {
        case .startRoutine:  return "play.circle"
        case .endSession:    return "checkmark.circle"
        case .addToCalendar: return "calendar.badge.plus"
        default:             return "bolt.circle"
        }
    }
}

#Preview {
    CoachView(coordinator: SessionCoordinator(
        modelContext: ModelContext(PersistenceController.shared.container)
    ))
}
