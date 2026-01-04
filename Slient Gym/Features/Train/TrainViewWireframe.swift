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
    @StateObject private var ballState = FloatingBallState()
    @State private var selectedRoutineId: UUID?
    @State private var showRestTimer = false
    @State private var capsuleHidden = false
    @State private var openDayIds: Set<UUID> = []
    @State private var showEndSessionConfirmation = false
    
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
                FloatingWorkoutBall(
                    state: ballState,
                    onSingleTap: {
                        ballState.showPanel.toggle()
                    },
                    onDoubleTap: {
                        // 双击：暂停/继续休息
                        if ballState.isResting {
                            if case .running = restTimer.state {
                                restTimer.pause()
                            } else if case .paused = restTimer.state {
                                restTimer.resume()
                            }
                        } else {
                            // 如果不在休息中，开始休息
                            if let restSec = getCurrentRestSeconds() {
                                restTimer.start(seconds: restSec)
                                sessionCoordinator.startRest(seconds: restSec)
                            }
                        }
                    },
                    onLongPress: {
                        // 长按：结束训练确认
                        showEndSessionConfirmation = true
                    },
                    onDragEnd: { point, frame in
                        snapToEdges(point: point, in: frame)
                    }
                )
            }
            .sheet(isPresented: $ballState.showPanel) {
                FloatingBallPanel(
                    state: ballState,
                    onPlus15: {
                        restTimer.extend(by: 15)
                        sessionCoordinator.extendRest(by: 15)
                    },
                    onSkip: {
                        restTimer.skip()
                        sessionCoordinator.restFinished()
                    },
                    onEnd: {
                        sessionCoordinator.endSession()
                        ballState.showPanel = false
                    }
                )
                .presentationDetents([.height(200)])
            }
            .alert("结束训练", isPresented: $showEndSessionConfirmation) {
                Button("取消", role: .cancel) {}
                Button("确认", role: .destructive) {
                    sessionCoordinator.endSession()
                    ballState.showPanel = false
                }
            } message: {
                Text("确定要结束当前训练吗？")
            }
            .navigationTitle("训练")
        }
        .onAppear {
            sessionCoordinator.modelContext = modelContext
            // 移除自动弹出日历的逻辑，用户可以在需要时手动添加
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartRestTimer"))) { notification in
            if let restSeconds = notification.userInfo?["restSeconds"] as? Int {
                restTimer.start(seconds: restSeconds)
                sessionCoordinator.startRest(seconds: restSeconds)
            }
        }
        .onChange(of: sessionCoordinator.state) { oldValue, newValue in
            handleStateChange(newValue)
        }
        // 监听训练状态，控制悬浮球显示
        .onChange(of: sessionCoordinator.currentSession) { oldValue, newValue in
            ballState.isVisible = newValue != nil
            if newValue == nil {
                ballState.showPanel = false
            }
        }
        // 监听休息计时器状态
        .onChange(of: restTimer.state) { oldValue, newValue in
            switch newValue {
            case .running(let remaining):
                // 获取总休息时长（从当前动作的默认休息时间）
                let totalRest = getCurrentRestSeconds() ?? 90
                ballState.updateRestState(
                    isActive: true,
                    remaining: TimeInterval(remaining),
                    total: TimeInterval(totalRest)
                )
                // 休息结束时震动反馈
                if remaining == 0 {
                    #if os(iOS)
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    #endif
                }
            case .paused(let remaining):
                // 保持总时长不变
                ballState.updateRestState(
                    isActive: true,
                    remaining: TimeInterval(remaining),
                    total: ballState.restTotal > 0 ? ballState.restTotal : TimeInterval(remaining)
                )
            case .off:
                ballState.updateRestState(isActive: false, remaining: 0, total: 0)
            }
        }
        // 移除自动弹出日历的 sheet，用户可以通过其他方式手动添加
    }
    
    private func startTraining(routine: Routine) {
        guard let session = sessionCoordinator.startSession(routineId: routine.id) else {
            return
        }
        
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
            // 更新悬浮球休息状态
            ballState.updateRestState(
                isActive: true,
                remaining: TimeInterval(remaining),
                total: TimeInterval(remaining)
            )
        case .finished:
            ballState.isVisible = false
            ballState.showPanel = false
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
                    
                    // 根据训练状态显示"开始"或"结束"按钮
                    let isActive = sessionCoordinator.currentSession?.routine?.id == routine.id
                    Button(action: {
                        if isActive {
                            // 结束训练
                            sessionCoordinator.endSession()
                        } else {
                            // 开始训练
                            onStart()
                        }
                    }) {
                        Text(isActive ? "结束" : "开始")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isActive ? Color.red : Color.black)
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
            
            let planText: String = {
                if routineExercise.isHoldType, let holdSec = routineExercise.holdSecDefault {
                    return "\(routineExercise.targetSets)组 × \(holdSec)秒"
                } else if let repTarget = routineExercise.repTarget {
                    return "\(routineExercise.targetSets)组 × \(repTarget)次"
                } else {
                    return "\(routineExercise.targetSets)组"
                }
            }()
            
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

