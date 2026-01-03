//
//  CoachViewWireframe.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Based on Wireframe v1.8.3 - Minimalist coach with quick buttons
//

import SwiftUI
import SwiftData

struct CoachViewWireframe: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var sessionCoordinator: SessionCoordinator
    @State private var messages: [ChatMessage] = [
        ChatMessage(content: "你好！我是你的训练教练。试试输入：'开始 Day A'。", isUser: false)
    ]
    @State private var inputText = ""
    
    private let quickCommands = ["开始 Day A", "休息 +30 秒", "写入日历"]
    
    init() {
        let tempContainer = PersistenceController.shared.container
        let tempContext = ModelContext(tempContainer)
        _sessionCoordinator = StateObject(wrappedValue: SessionCoordinator(modelContext: tempContext))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部
                HStack {
                    Text("教练")
                        .font(.headline)
                    Spacer()
                    Text("极简")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // 快捷建议行
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickCommands, id: \.self) { command in
                            Button(action: {
                                sendMessage(command)
                            }) {
                                Text(command)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                
                // 消息区（只显示最近 3 条）
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(messages.suffix(3))) { message in
                            ChatBubbleWireframe(message: message)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // 底部输入
                HStack(spacing: 8) {
                    TextField("与教练对话…（Enter 发送）", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: {
                        sendMessage()
                    }) {
                        Text("发送")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(inputText.isEmpty ? Color.gray : Color.black)
                            .cornerRadius(12)
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("教练")
        }
        .onAppear {
            sessionCoordinator.modelContext = modelContext
        }
    }
    
    private func sendMessage(_ text: String? = nil) {
        let textToSend = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty else { return }
        
        inputText = ""
        
        // 添加用户消息
        let userMessage = ChatMessage(content: textToSend, isUser: true)
        messages.append(userMessage)
        
        // 限制消息数量（只保留最近 10 条）
        if messages.count > 10 {
            messages.removeFirst(messages.count - 10)
        }
        
        // 简单规则回复
        var reply = "收到，稍后我会给出训练建议。"
        if textToSend.lowercased().contains("开始") && textToSend.lowercased().contains("day a") {
            reply = "已开始 Day A（示意）。完成后可写入日历并同步健康。"
        } else if textToSend.contains("+30") || textToSend.contains("30秒") {
            reply = "好的，本组休息时间已+30s（示意）。"
        } else if textToSend.lowercased().contains("日历") || textToSend.lowercased().contains("calendar") {
            reply = "完成后会写入你的日历（示意）。"
        }
        
        let coachMessage = ChatMessage(content: reply, isUser: false)
        messages.append(coachMessage)
        
        // 限制消息数量
        if messages.count > 10 {
            messages.removeFirst(messages.count - 10)
        }
    }
}

struct ChatBubbleWireframe: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !message.isUser {
                // 教练头像
                Circle()
                    .fill(Color.black)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("教")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                    )
            }
            
            Text(message.content)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(message.isUser ? Color.black : Color(.systemGray6))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(16)
                .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if message.isUser {
                // 用户头像
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("我")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
}

