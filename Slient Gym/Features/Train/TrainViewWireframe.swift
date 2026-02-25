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
    @State private var quickReps: String = ""
    @State private var quickRIR: Int = 1
    @Binding var currentTab: AppTab
    @State private var showTabSwitcher = false
    @State private var highlightedTab: AppTab?

    init(currentTab: Binding<AppTab>) {
        let tempContainer = PersistenceController.shared.container
        let tempContext = ModelContext(tempContainer)
        _sessionCoordinator = StateObject(wrappedValue: SessionCoordinator(modelContext: tempContext))
        _currentTab = currentTab
    }

    private var isIdle: Bool {
        if case .idle = sessionCoordinator.state { return true }
        return false
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("今天")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Button(action: { capsuleHidden.toggle() }) {
                Text(capsuleHidden ? "显示状态" : "隐藏状态")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .underline()
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var routinesList: some View {
        VStack(spacing: 12) {
            ForEach(Array(routines.prefix(3))) { routine in
                RoutineDayCard(
                    routine: routine,
                    isOpen: openDayIds.contains(routine.id),
                    sessionCoordinator: sessionCoordinator,
                    restTimer: restTimer,
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
        .padding(.bottom, 100)
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            if isIdle, !capsuleHidden {
                StatusCapsuleView()
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            #endif

            ScrollView {
                VStack(spacing: 0) {
                    headerView
                    routinesList
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    @ViewBuilder
    private var floatingBallOverlay: some View {
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
                showTabSwitcher = true
            },
            onDragEnd: { point, frame in
                snapToEdges(point: point, in: frame)
            }
        )
    }

    @ViewBuilder
    private var tabSwitcherOverlay: some View {
        if showTabSwitcher {
            GeometryReader { geo in
                let center = ballState.position ?? CGPoint(x: geo.size.width - 40, y: geo.size.height - 140)
                FloatingRadialTabMenu(
                    currentTab: currentTab,
                    center: center,
                    highlightedTab: $highlightedTab,
                    onSelect: { tab in
                        currentTab = tab
                        showTabSwitcher = false
                        highlightedTab = nil
                    },
                    onCancel: {
                        showTabSwitcher = false
                        highlightedTab = nil
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var ballPanelSheet: some View {
        FloatingBallPanel(
            state: ballState,
            quickReps: $quickReps,
            quickRIR: $quickRIR,
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
                if let reps = Int(quickReps) {
                    sessionCoordinator.completeSet(reps: reps, rir: quickRIR)
                    quickReps = ""
                    quickRIR = 1
                }
            },
            onEnd: {
                sessionCoordinator.endSession()
                ballState.showPanel = false
            }
        )
        .presentationDetents([.height(280)])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                mainContent
                floatingBallOverlay
            }
            .overlay { tabSwitcherOverlay }
            .sheet(isPresented: $ballState.showPanel) { ballPanelSheet }
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
                if remaining == 0 {
                    #if os(iOS)
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    #endif
                }
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
    }

    private func startTraining(routine: Routine) {
        guard let session = sessionCoordinator.startSession(routineId: routine.id) else {
            return
        }
        
        openDayIds.insert(routine.id)
        
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
            ballState.updateSubtitle(getCurrentExerciseSubtitle())
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
            break
        }
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
    
    private func getRoutineExercise(for sessionExercise: SessionExercise) -> RoutineExercise? {
        guard let session = sessionExercise.session,
              let routine = session.routine,
              let exercise = sessionExercise.exercise else {
            return nil
        }
        return routine.exercises?.first { $0.exercise?.id == exercise.id }
    }
}

/// 训练计划卡片（可展开）
struct RoutineDayCard: View {
    let routine: Routine
    let isOpen: Bool
    let sessionCoordinator: SessionCoordinator
    /// Injected from parent — single source of truth for rest timing
    let restTimer: RestTimerManager
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
                            .foregroundColor(AppTheme.textPrimary)
                        
                        if let exercises = routine.exercises, !exercises.isEmpty {
                            let firstExercise = exercises.sorted(by: { $0.order < $1.order }).first
                            let exerciseName = firstExercise?.exercise?.name ?? "无"
                            let estimatedMinutes = estimateMinutes(for: routine)
                            Text("\(exerciseName) 等 · 约 \(estimatedMinutes) 分钟")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                    
                    let isActive = sessionCoordinator.currentSession?.routine?.id == routine.id
                    Button(action: {
                        if isActive {
                            sessionCoordinator.endSession()
                        } else {
                            onStart()
                        }
                    }) {
                        Text(isActive ? "结束" : "开始")
                            .font(.subheadline.bold())
                            .foregroundColor(isActive ? .white : AppTheme.accentForeground)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isActive ? AppTheme.destructive : AppTheme.accent)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isOpen {
                VStack(spacing: 0) {
                    if let exercises = routine.exercises?.sorted(by: { $0.order < $1.order }) {
                        ForEach(exercises) { routineExercise in
                            if let session = sessionCoordinator.currentSession,
                               let sessionExercise = session.exercises?.first(where: { $0.exercise?.id == routineExercise.exercise?.id }) {
                                ExerciseDetailsView(
                                    sessionExercise: sessionExercise,
                                    routineExercise: routineExercise,
                                    defaultExpanded: true,
                                    restTimer: restTimer,
                                    onSetCompleted: { restSec in
                                        // Single source of truth: start rest here, not inside the view
                                        restTimer.start(seconds: restSec)
                                        sessionCoordinator.startRest(seconds: restSec)
                                    }
                                )
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            } else {
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
        .background(AppTheme.surface)
        .cornerRadius(AppTheme.cardRadius)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isOpen)
    }
    
    private func estimateMinutes(for routine: Routine) -> Int {
        guard let exercises = routine.exercises else { return 0 }
        let totalSeconds = exercises.reduce(0) { acc, re in
            let exerciseTime: Int
            if re.isHoldType, let holdSec = re.holdSecDefault {
                exerciseTime = re.targetSets * (holdSec + re.restSecondsDefault)
            } else {
                let repTime = 6
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(routineExercise.exercise?.name ?? "未知动作")
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)

                let planText: String = {
                    if routineExercise.isHoldType, let holdSec = routineExercise.holdSecDefault {
                        return "\(routineExercise.targetSets)组 × \(holdSec)s"
                    } else if let repTarget = routineExercise.repTarget {
                        return "\(routineExercise.targetSets)组 × \(repTarget)次"
                    } else {
                        return "\(routineExercise.targetSets)组"
                    }
                }()
                Text("计划 \(planText) · 休息 \(routineExercise.restSecondsDefault)s")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundColor(AppTheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.background)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.border.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

