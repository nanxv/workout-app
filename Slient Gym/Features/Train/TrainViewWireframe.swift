//
//  TrainViewWireframe.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Based on Wireframe v1.8.3 - New training view with expandable exercise details
//

import SwiftUI
import SwiftData
import Combine
#if os(iOS)
import UIKit
#endif

struct TrainViewWireframe: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.name) private var routines: [Routine]
    @StateObject private var sessionCoordinator: SessionCoordinator
    @StateObject private var restTimer = RestTimerManager()
    @State private var selectedRoutineId: UUID?
    @State private var showRestTimer = false
    @State private var capsuleHidden = false
    @State private var openDayIds: Set<UUID> = []
    @State private var floatVisible = false
    @State private var bubbleOpen = false
    #if os(iOS)
    @State private var showCalendarSheet = false
    @State private var endedSession: Session?
    #endif
    
    init() {
        let tempContainer = PersistenceController.shared.container
        let tempContext = ModelContext(tempContainer)
        _sessionCoordinator = StateObject(wrappedValue: SessionCoordinator(modelContext: tempContext))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    #if os(iOS)
                    if case .idle = sessionCoordinator.state, !capsuleHidden {
                        StatusCapsuleView()
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                    #endif
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // 标题栏
                            HStack {
                                Text("今天")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Button(action: {
                                    capsuleHidden.toggle()
                                }) {
                                    Text(capsuleHidden ? "显示状态" : "隐藏状态")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .underline()
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                            
                            // 训练计划列表
                            VStack(spacing: 12) {
                                ForEach(Array(routines.prefix(3))) { routine in
                                    RoutineDayCard(
                                        routine: routine,
                                        isOpen: openDayIds.contains(routine.id),
                                        sessionCoordinator: sessionCoordinator,
                                        modelContext: modelContext,
                                        onToggle: {
                                            withAnimation {
                                                if openDayIds.contains(routine.id) {
                                                    openDayIds.remove(routine.id)
                                                } else {
                                                    openDayIds.insert(routine.id)
                                                }
                                            }
                                        },
                                        onStart: {
                                            startTraining(routine: routine)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100) // 为悬浮球留空间
                        }
                    }
                }
                
                // 悬浮球（仅在训练中显示）
                if floatVisible, let currentSession = sessionCoordinator.currentSession {
                    FloatingWorkoutBall(
                        title: "当前训练 · \(currentSession.routine?.name ?? "未设置")",
                        subtitle: getCurrentExerciseSubtitle(),
                        restSeconds: restTimer.remainingSeconds,
                        onToggle: {
                            bubbleOpen.toggle()
                        },
                        onStartRest: {
                            if let restSec = getCurrentRestSeconds() {
                                restTimer.start(seconds: restSec)
                                sessionCoordinator.startRest(seconds: restSec)
                            }
                        },
                        onAddRest: {
                            restTimer.extend(by: 30)
                            sessionCoordinator.extendRest(by: 30)
                        },
                        onEnd: {
                            sessionCoordinator.endSession()
                            floatVisible = false
                            bubbleOpen = false
                        }
                    )
                }
            }
            .navigationTitle("训练")
        }
        .onAppear {
            sessionCoordinator.modelContext = modelContext
            #if os(iOS)
            sessionCoordinator.onSessionEnded = { session in
                endedSession = session
                showCalendarSheet = true
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartRestTimer"))) { notification in
            if let restSeconds = notification.userInfo?["restSeconds"] as? Int {
                restTimer.start(seconds: restSeconds)
                sessionCoordinator.startRest(seconds: restSeconds)
                floatVisible = true
                bubbleOpen = true
            }
        }
        .onChange(of: sessionCoordinator.state) { oldValue, newValue in
            handleStateChange(newValue)
        }
        #if os(iOS)
        .sheet(isPresented: $showCalendarSheet) {
            if let session = endedSession {
                CalendarEventSheet(session: session)
            }
        }
        #endif
    }
    
    private func startTraining(routine: Routine) {
        guard let session = sessionCoordinator.startSession(routineId: routine.id) else {
            return
        }
        
        floatVisible = true
        openDayIds.insert(routine.id)
        
        // 后台尝试启动 watch
        #if os(iOS)
        Task.detached(priority: .userInitiated) {
            await MainActor.run {
                WatchWorkoutLauncher.shared.startWatchWorkout(sessionId: session.id) { _, _ in }
            }
        }
        #endif
    }
    
    private func getCurrentExerciseSubtitle() -> String? {
        guard let session = sessionCoordinator.currentSession,
              let exercises = session.exercises?.sorted(by: { $0.order < $1.order }),
              let firstExercise = exercises.first,
              let routine = session.routine,
              let routineExercise = routine.exercises?.first(where: { $0.exercise?.id == firstExercise.exercise?.id }) else {
            return nil
        }
        
        let sets = routineExercise.targetSets
        let detail: String
        if routineExercise.isHoldType, let holdSec = routineExercise.holdSecDefault {
            detail = "×\(holdSec)秒"
        } else if let repTarget = routineExercise.repTarget {
            detail = "×\(repTarget)次"
        } else {
            detail = ""
        }
        
        return "\(firstExercise.exercise?.name ?? "") · \(sets)组\(detail) · 休\(routineExercise.restSecondsDefault)秒"
    }
    
    private func getCurrentRestSeconds() -> Int? {
        guard let session = sessionCoordinator.currentSession,
              let exercises = session.exercises?.sorted(by: { $0.order < $1.order }),
              let currentExercise = exercises[safe: sessionCoordinator.currentExerciseIndex],
              let routine = session.routine,
              let routineExercise = routine.exercises?.first(where: { $0.exercise?.id == currentExercise.exercise?.id }) else {
            return 90
        }
        return routineExercise.restSecondsDefault
    }
    
    private func handleStateChange(_ newState: TrainingSessionState) {
        switch newState {
        case .resting(_, let remaining):
            showRestTimer = true
            if case .off = restTimer.state {
                restTimer.start(seconds: remaining)
            } else {
                restTimer.stop()
                restTimer.start(seconds: remaining)
            }
            restTimer.onFinish = {
                sessionCoordinator.restFinished()
                showRestTimer = false
            }
            floatVisible = true
            bubbleOpen = true
        case .finished:
            floatVisible = false
            bubbleOpen = false
        default:
            break
        }
    }
}

/// 训练计划卡片（可展开）
struct RoutineDayCard: View {
    let routine: Routine
    let isOpen: Bool
    let sessionCoordinator: SessionCoordinator
    let modelContext: ModelContext
    let onToggle: () -> Void
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let exercises = routine.exercises, !exercises.isEmpty {
                            let firstExercise = exercises.sorted(by: { $0.order < $1.order }).first
                            let exerciseName = firstExercise?.exercise?.name ?? "无"
                            let estimatedMinutes = estimateMinutes(for: routine)
                            Text("\(exerciseName) 等 · 约 \(estimatedMinutes) 分钟")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Text(isOpen ? "（点击收起）" : "（点击展开）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        onStart()
                    }) {
                        Text("开始")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // 展开内容
            if isOpen {
                VStack(spacing: 0) {
                    if let exercises = routine.exercises?.sorted(by: { $0.order < $1.order }) {
                        ForEach(exercises) { routineExercise in
                            if let session = sessionCoordinator.currentSession,
                               let sessionExercise = session.exercises?.first(where: { $0.exercise?.id == routineExercise.exercise?.id }) {
                                ExerciseDetailsView(
                                    sessionExercise: sessionExercise,
                                    routineExercise: routineExercise,
                                    defaultExpanded: true
                                )
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            } else {
                                // 未开始训练时显示计划
                                ExercisePlanPreview(routineExercise: routineExercise)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .padding(.bottom)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func estimateMinutes(for routine: Routine) -> Int {
        guard let exercises = routine.exercises else { return 0 }
        let totalSeconds = exercises.reduce(0) { acc, re in
            let exerciseTime: Int
            if re.isHoldType, let holdSec = re.holdSecDefault {
                exerciseTime = re.targetSets * (holdSec + re.restSecondsDefault)
            } else {
                let repTime = 6 // 假设每次 rep 6 秒
                exerciseTime = re.targetSets * (re.restSecondsDefault + (re.repTarget ?? 10) * repTime)
            }
            return acc + exerciseTime
        }
        return max(20, min(120, totalSeconds / 60))
    }
}

/// 动作计划预览（未开始训练时显示）
struct ExercisePlanPreview: View {
    let routineExercise: RoutineExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(routineExercise.exercise?.name ?? "未知动作")
                .font(.headline)
            
            let planText: String
            if routineExercise.isHoldType, let holdSec = routineExercise.holdSecDefault {
                planText = "\(routineExercise.targetSets)组 × \(holdSec)秒"
            } else if let repTarget = routineExercise.repTarget {
                planText = "\(routineExercise.targetSets)组 × \(repTarget)次"
            } else {
                planText = "\(routineExercise.targetSets)组"
            }
            
            Text("计划：\(planText) · 休息：\(routineExercise.restSecondsDefault)秒")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

