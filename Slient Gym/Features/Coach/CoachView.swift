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
    @State private var inputText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var pendingAction: AppAction?
    @State private var showConfirmSheet = false
    
    init() {
        // Initialize with a temporary context, will be updated in onAppear
        let tempContext = ModelContext(PersistenceController.shared.container)
        _sessionCoordinator = StateObject(wrappedValue: SessionCoordinator(modelContext: tempContext))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                        }
                    }
                    .padding()
                }
                
                HStack {
                    TextField("Ask coach...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: {
                        sendMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Coach")
            .onAppear {
                sessionCoordinator.modelContext = modelContext
            }
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
        messages.append(userMessage)
        
        let command = inputText
        inputText = ""
        
        // Parse command
        if let action = CoachCommandRouter.parse(command) {
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
            messages.append(coachMessage)
        }
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
                messages.append(ChatMessage(content: "Started \(routine.name)", isUser: false))
            } else {
                messages.append(ChatMessage(content: "Routine '\(nameOrId)' not found", isUser: false))
            }
            
        case .endSession:
            sessionCoordinator.endSession()
            messages.append(ChatMessage(content: "Session ended", isUser: false))
            
        case .updateExerciseConfig(let exerciseName, _, _):
            // This would update the current routine's exercise config
            messages.append(ChatMessage(content: "Updated \(exerciseName) config", isUser: false))
            
        case .extendRest(let seconds):
            sessionCoordinator.extendRest(by: seconds)
            messages.append(ChatMessage(content: "Extended rest by \(seconds) seconds", isUser: false))
            
        case .skipRest:
            sessionCoordinator.skipRest()
            messages.append(ChatMessage(content: "Skipped rest", isUser: false))
            
        case .addToCalendar(_):
            // This will be implemented in Milestone 2
            messages.append(ChatMessage(content: "Calendar integration coming soon", isUser: false))
            
        case .summarize(let period):
            let summary = generateSummary(period: period)
            messages.append(ChatMessage(content: summary, isUser: false))
        }
    }
    
    private func generateSummary(period: String) -> String {
        // Simple summary for now
        let descriptor = FetchDescriptor<Session>()
        if let sessions = try? modelContext.fetch(descriptor) {
            return "You have \(sessions.count) training sessions recorded."
        }
        return "No training data yet."
    }
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
                .padding()
                .background(message.isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(16)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct ConfirmActionSheet: View {
    let action: AppAction
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Confirm Action")
                    .font(.title2)
                    .bold()
                
                Text(actionDescription)
                    .multilineTextAlignment(.center)
                    .padding()
                
                HStack(spacing: 20) {
                    Button("Cancel", role: .cancel) {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Confirm") {
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
            return "Start routine: \(name)?"
        case .endSession:
            return "End current training session?"
        case .addToCalendar:
            return "Add this session to calendar?"
        default:
            return "Execute this action?"
        }
    }
}

#Preview {
    CoachView()
        .modelContainer(for: [Routine.self], inMemory: true)
}

