//
//  TrainView.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct TrainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.name) private var routines: [Routine]
    @StateObject private var sessionCoordinator: SessionCoordinator
    @StateObject private var restTimer = RestTimerManager()
    @StateObject private var ballState = FloatingBallState()
    @State private var selectedRoutineId: UUID?
    @State private var currentReps: String = ""
    @State private var currentRIR: Int = 1
    @State private var showRestTimer = false
    @State private var showEndSessionConfirmation = false
    #if os(iOS)
    @State private var showCalendarSheet = false
    @State private var endedSession: Session?
    #endif
    
    init() {
        // Initialize with a temporary context, will be updated in onAppear
        // Use lazy initialization to avoid blocking
        let tempContainer = PersistenceController.shared.container
        let tempContext = ModelContext(tempContainer)
        _sessionCoordinator = StateObject(wrappedValue: SessionCoordinator(modelContext: tempContext))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    #if os(iOS)
                    if case .idle = sessionCoordinator.state {
                        StatusCapsuleView()
                            .padding(.vertical, 4)
                    }
                    #endif
                    
                    Group {
                        switch sessionCoordinator.state {
                        case .idle:
                            routineSelectionView
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        case .starting:
                            VStack {
                                ProgressView()
                                Text("正在启动...")
                            }
                            .transition(.opacity)
                        case .running(let sessionId, let exerciseIndex, let setIndex):
                            trainingView(sessionId: sessionId, exerciseIndex: exerciseIndex, setIndex: setIndex)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .resting(let sessionId, let remaining):
                            // During rest, we should show the current exercise (will be updated after rest)
                            // For now, use the sessionCoordinator's tracked indices
                            trainingView(sessionId: sessionId, exerciseIndex: sessionCoordinator.currentExerciseIndex, setIndex: sessionCoordinator.currentSetIndex)
                                .overlay(restTimerOverlay(remaining: remaining))
                                .transition(.opacity)
                        case .paused:
                            Text("已暂停")
                                .transition(.opacity)
                        case .ending:
                            VStack {
                                ProgressView()
                                Text("正在结束训练...")
                            }
                            .transition(.opacity)
                        case .finished:
                            routineSelectionView
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        case .error(let message):
                            VStack {
                                Text("错误: \(message)")
                                Button("返回") {
                                    sessionCoordinator.state = .idle
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                }
                
                FloatingWorkoutBall(
                    state: ballState,
                    onSingleTap: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            ballState.showPanel.toggle()
                        }
                    },
                    onDoubleTap: {
                        if ballState.isResting {
                            if case .running = restTimer.state {
                                restTimer.pause()
                                ballState.updatePauseState(isPaused: true)
                            } else if case .paused = restTimer.state {
                                restTimer.resume()
                                ballState.updatePauseState(isPaused: false)
                            }
                        } else {
                            if let restSec = getCurrentRestSeconds() {
                                restTimer.start(seconds: restSec)
                                sessionCoordinator.startRest(seconds: restSec)
                            }
                        }
                    },
                    onLongPress: {
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
                    quickReps: $currentReps,
                    quickRIR: $currentRIR,
                    onPlus15: {
                        restTimer.extend(by: 15)
                        sessionCoordinator.extendRest(by: 15)
                    },
                    onTogglePause: {
                        if case .running = restTimer.state {
                            restTimer.pause()
                            ballState.updatePauseState(isPaused: true)
                        } else if case .paused = restTimer.state {
                            restTimer.resume()
                            ballState.updatePauseState(isPaused: false)
                        }
                    },
                    onSkip: {
                        restTimer.skip()
                        sessionCoordinator.restFinished()
                    },
                    onStartRest: {
                        if let restSec = getCurrentRestSeconds() {
                            restTimer.start(seconds: restSec)
                            sessionCoordinator.startRest(seconds: restSec)
                        }
                    },
                    onCompleteSet: {
                        if let reps = Int(currentReps) {
                            sessionCoordinator.completeSet(reps: reps, rir: currentRIR)
                            currentReps = ""
                            currentRIR = 1
                        }
                    },
                    onEnd: {
                        sessionCoordinator.endSession()
                        ballState.showPanel = false
                    }
                )
                .presentationDetents([.height(360)])
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
            .background(Color(.systemBackground))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sessionCoordinator.state)
        .onAppear {
            // Update sessionCoordinator with actual modelContext
            sessionCoordinator.modelContext = modelContext
            print("TrainView appeared, routines count: \(routines.count)")
            print("SessionCoordinator state: \(sessionCoordinator.state)")
            
            // 移除自动弹出日历的逻辑，用户可以在需要时手动添加
        }
        .onChange(of: sessionCoordinator.state) { oldValue, newValue in
            handleStateChange(newValue)
            updateBallExerciseInfo()
        }
        .onChange(of: sessionCoordinator.currentSession) { oldValue, newValue in
            ballState.isVisible = newValue != nil
            if newValue == nil {
                ballState.showPanel = false
                ballState.updateSubtitle(nil)
                ballState.updateExerciseInfo(name: nil, setIndex: 0, totalSets: 0, nextName: nil)
            } else {
                ballState.updateSubtitle(getCurrentExerciseSubtitle())
                updateBallExerciseInfo()
            }
        }
        .onChange(of: restTimer.state) { oldValue, newValue in
            switch newValue {
            case .running(let remaining):
                let totalRest = getCurrentRestSeconds() ?? 90
                ballState.updateRestState(
                    isActive: true,
                    remaining: TimeInterval(remaining),
                    total: TimeInterval(totalRest)
                )
                ballState.updatePauseState(isPaused: false)
            case .paused(let remaining):
                ballState.updateRestState(
                    isActive: true,
                    remaining: TimeInterval(remaining),
                    total: ballState.restTotal > 0 ? ballState.restTotal : TimeInterval(remaining)
                )
                ballState.updatePauseState(isPaused: true)
            case .off:
                ballState.updateRestState(isActive: false, remaining: 0, total: 0)
                ballState.updatePauseState(isPaused: false)
            }
        }
        // 移除自动弹出日历的 sheet，用户可以通过其他方式手动添加
    }
    
    private var routineSelectionView: some View {
        VStack(spacing: 12) {
            Text("选择训练计划")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
            if routines.isEmpty {
                Text("暂无训练计划")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            } else {
                List(routines) { routine in
                    Button(action: {
                        print("Starting routine: \(routine.name)")
                        selectedRoutineId = routine.id
                        
                        // 先本地开始训练（不阻塞）
                        guard let session = sessionCoordinator.startSession(routineId: routine.id) else {
                            print("Failed to start session: routine not found or invalid")
                            return
                        }
                        
                        print("Session started: \(session.id)")
                        
                        // 后台尝试启动 watch（非阻塞）
                        #if os(iOS)
                        Task.detached(priority: .userInitiated) {
                            await MainActor.run {
                                WatchWorkoutLauncher.shared.startWatchWorkout(sessionId: session.id) { success, error in
                                    if success {
                                        print("Watch workout started successfully")
                                    } else {
                                        print("Watch workout failed (non-blocking): \(error?.localizedDescription ?? "Unknown")")
                                    }
                                }
                            }
                        }
                        #endif
                    }) {
                        Text(routine.name)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .scrollIndicators(.hidden)
            }
        }
        .padding(.bottom, 4)
    }
    
    /// Renders all exercises for the active session using the zero-friction ExerciseDetailsView.
    /// Replaces the old TextField+Picker approach entirely.
    private func trainingView(sessionId: UUID, exerciseIndex: Int, setIndex: Int) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                if let session = sessionCoordinator.currentSession,
                   session.id == sessionId,
                   let exercises = session.exercises?.sorted(by: { $0.order < $1.order }) {

                    // Progress header
                    HStack {
                        Text(session.routineNameSnapshot)
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text("\(exercises.filter { ($0.sets?.filter(\.isCompleted).count ?? 0) > 0 }.count)/\(exercises.count) 动作")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal)

                    ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, sessionExercise in
                        let routineExercise = getRoutineExercise(for: sessionExercise)
                        ExerciseDetailsView(
                            sessionExercise: sessionExercise,
                            routineExercise: routineExercise,
                            defaultExpanded: idx == exerciseIndex,
                            restTimer: restTimer,
                            onSetCompleted: { restSec in
                                restTimer.start(seconds: restSec)
                                sessionCoordinator.startRest(seconds: restSec)
                            }
                        )
                        .padding(.horizontal)
                    }

                    Button("结束训练") {
                        sessionCoordinator.endSession()
                    }
                    .buttonStyle(SGPrimaryButtonStyle(isDestructive: true))
                    .padding(.horizontal)
                    .padding(.top, 8)

                } else {
                    Text("无活动动作")
                        .foregroundColor(AppTheme.textSecondary)
                }

                // 底部安全缓冲：撑开滚动区域，避免内容被 Tab Bar 和悬浮球遮挡
                // 130pt = 底部导航高度(~83) + 悬浮球直径(56) + 余量
                Color.clear.frame(height: 130)
            }
            .padding(.vertical)
        }
        .scrollIndicators(.hidden)
        // 额外保险：把可滚动内容推入安全区内边距，防止系统 Tab Bar 遮挡底部
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
    }
    
    private func restTimerOverlay(remaining: Int) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("休息")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(restTimer.remainingSeconds)s")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    Button("+15s") {
                        sessionCoordinator.extendRest(by: 15)
                        restTimer.extend(by: 15)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    
                    Button("跳过") {
                        sessionCoordinator.skipRest()
                        restTimer.skip()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }
        }
    }
    
    private func getRoutineExercise(for sessionExercise: SessionExercise) -> RoutineExercise? {
        guard let session = sessionExercise.session,
              let routine = session.routine,
              let exercise = sessionExercise.exercise else {
            return nil
        }
        return routine.exercises?.first { $0.exercise?.id == exercise.id }
    }

    private func getCurrentExerciseSubtitle() -> String? {
        guard let session = sessionCoordinator.currentSession,
              let exercises = session.exercises?.sorted(by: { $0.order < $1.order }),
              let currentExercise = exercises[safe: sessionCoordinator.currentExerciseIndex],
              let routineExercise = getRoutineExercise(for: currentExercise) else {
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
        
        return "\(currentExercise.exercise?.name ?? "") · \(sets)组\(detail) · 休\(routineExercise.restSecondsDefault)秒"
    }

    private func getCurrentRestSeconds() -> Int? {
        guard let session = sessionCoordinator.currentSession,
              let exercises = session.exercises?.sorted(by: { $0.order < $1.order }),
              let currentExercise = exercises[safe: sessionCoordinator.currentExerciseIndex],
              let routineExercise = getRoutineExercise(for: currentExercise) else {
            return 90
        }
        return routineExercise.restSecondsDefault
    }

    private func updateBallExerciseInfo() {
        guard let session = sessionCoordinator.currentSession,
              let exercises = session.exercises?.sorted(by: { $0.order < $1.order }),
              !exercises.isEmpty else {
            ballState.updateExerciseInfo(name: nil, setIndex: 0, totalSets: 0, nextName: nil)
            return
        }
        
        let currentIndex = min(sessionCoordinator.currentExerciseIndex, exercises.count - 1)
        let currentExercise = exercises[safe: currentIndex]
        let routineExercise = currentExercise.map { getRoutineExercise(for: $0) } ?? nil
        let totalSets = max(1, routineExercise?.targetSets ?? 1)
        
        let completedSets: Int
        switch sessionCoordinator.state {
        case .resting:
            completedSets = min(sessionCoordinator.currentSetIndex + 1, totalSets)
        default:
            completedSets = min(sessionCoordinator.currentSetIndex, totalSets)
        }
        
        let nextName: String?
        if currentIndex + 1 < exercises.count {
            nextName = exercises[currentIndex + 1].exercise?.name
        } else {
            nextName = nil
        }
        
        ballState.updateExerciseInfo(
            name: currentExercise?.exercise?.name,
            setIndex: completedSets,
            totalSets: totalSets,
            nextName: nextName
        )
    }
    
    private func handleStateChange(_ newState: TrainingSessionState) {
        switch newState {
        case .resting(_, let remaining):
            showRestTimer = true
            ballState.updateSubtitle(getCurrentExerciseSubtitle())
            if case .off = restTimer.state {
                restTimer.start(seconds: remaining)
            } else {
                // Update existing timer
                restTimer.stop()
                restTimer.start(seconds: remaining)
            }
            restTimer.onFinish = {
                sessionCoordinator.restFinished()
                showRestTimer = false
            }
            restTimer.onTick = { remaining in
                // Update state if needed
                if case .resting = sessionCoordinator.state {
                    // State is already correct, just update display
                }
            }
            ballState.updateRestState(
                isActive: true,
                remaining: TimeInterval(remaining),
                total: TimeInterval(remaining)
            )
            ballState.updatePauseState(isPaused: false)
        case .running:
            ballState.updateSubtitle(getCurrentExerciseSubtitle())
            ballState.updatePauseState(isPaused: false)
            updateBallExerciseInfo()
        case .paused:
            ballState.updateSubtitle(getCurrentExerciseSubtitle())
            updateBallExerciseInfo()
        case .finished:
            ballState.isVisible = false
            ballState.showPanel = false
            ballState.updateSubtitle(nil)
            ballState.updatePauseState(isPaused: false)
            ballState.updateExerciseInfo(name: nil, setIndex: 0, totalSets: 0, nextName: nil)
        default:
            showRestTimer = false
            restTimer.stop()
        }
    }
}

#Preview {
    TrainView()
        .modelContainer(for: [Routine.self, Exercise.self], inMemory: true)
}

