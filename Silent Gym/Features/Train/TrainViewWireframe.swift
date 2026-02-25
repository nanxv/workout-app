//
//  TrainViewWireframe.swift
//  Silent Gym
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

    @StateObject private var vm: TrainViewModel
    #if os(iOS)
    @StateObject private var poseTracker = VisionPoseTracker()
    #endif

    @Binding var currentTab: AppTab
    @State private var showTabSwitcher = false
    @State private var highlightedTab: AppTab?
    @State private var cameraAssistEnabled = false

    init(coordinator: SessionCoordinator, currentTab: Binding<AppTab>) {
        _vm = StateObject(wrappedValue: TrainViewModel(coordinator: coordinator))
        _currentTab = currentTab
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera background when Camera Assist is active
                #if os(iOS)
                if cameraAssistEnabled {
                    cameraBackground
                }
                #endif

                mainContent
                floatingBallOverlay

                // Skeleton + HUD overlay (above UI, but passthrough for touches)
                #if os(iOS)
                if cameraAssistEnabled && poseTracker.poseDetected {
                    PoseOverlayView(
                        joints: poseTracker.jointPositions,
                        phase: poseTracker.squatPhase,
                        repCount: poseTracker.repCount,
                        kneeAngle: poseTracker.kneeAngle,
                        feedback: poseTracker.feedback
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
                #endif
            }
            .overlay { tabSwitcherOverlay }
            .sheet(isPresented: Binding(
                get: { vm.ballState.showPanel },
                set: { vm.ballState.showPanel = $0 }
            )) { ballPanelSheet }
            .alert("结束训练", isPresented: $vm.showEndSessionConfirmation) {
                Button("取消", role: .cancel) {}
                Button("确认", role: .destructive) { vm.endSession() }
            } message: {
                Text("确定要结束当前训练吗？")
            }
            .alert("摄像头权限被拒绝", isPresented: Binding(
                get: { poseTracker.authorizationDenied },
                set: { if !$0 { cameraAssistEnabled = false } }
            )) {
                Button("去设置") {
                    #if os(iOS)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    #endif
                }
                Button("取消", role: .cancel) { cameraAssistEnabled = false }
            } message: {
                Text("请在【设置 → 隐私 → 摄像头】中允许 Silent Gym 访问摄像头。")
            }
            .navigationTitle("训练")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    cameraAssistToggle
                }
            }
        }
        .onAppear {
            vm.updateModelContext(modelContext)
        }
        .onChange(of: cameraAssistEnabled) { _, enabled in
            if enabled { poseTracker.start() } else { poseTracker.stop() }
        }
    }

    // MARK: - Camera Assist subviews

    #if os(iOS)
    /// Full-screen camera preview with a semi-transparent overlay to keep UI legible.
    private var cameraBackground: some View {
        ZStack {
            CameraPreviewView(session: poseTracker.captureSession)
                .ignoresSafeArea()

            // Dimming layer to preserve UI readability
            Color.black.opacity(0.45)
                .ignoresSafeArea()
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.35), value: cameraAssistEnabled)
    }
    #endif

    /// Toolbar button that toggles Camera Assist on/off.
    private var cameraAssistToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraAssistEnabled.toggle()
            }
        } label: {
            Label(
                cameraAssistEnabled ? "关闭辅助" : "摄像头辅助",
                systemImage: cameraAssistEnabled ? "video.slash.fill" : "video.fill"
            )
            .font(.caption.bold())
            .foregroundStyle(cameraAssistEnabled ? .red : .accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                (cameraAssistEnabled ? Color.red : Color.accentColor).opacity(0.12),
                in: Capsule()
            )
        }
        .accessibilityLabel(cameraAssistEnabled ? "关闭摄像头辅助" : "开启摄像头辅助")
    }

    // MARK: - Subviews

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            if case .idle = vm.coordinator.state, !vm.capsuleHidden {
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
    private var headerView: some View {
        HStack {
            Text("今天")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Button(action: { vm.capsuleHidden.toggle() }) {
                Text(vm.capsuleHidden ? "显示状态" : "隐藏状态")
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
                    isOpen: vm.openDayIds.contains(routine.id),
                    sessionCoordinator: vm.coordinator,
                    restTimer: vm.restTimer,
                    modelContext: modelContext,
                    onToggle: {
                        withAnimation {
                            if vm.openDayIds.contains(routine.id) {
                                vm.openDayIds.remove(routine.id)
                            } else {
                                vm.openDayIds.insert(routine.id)
                            }
                        }
                    },
                    onStart: { vm.startTraining(routine: routine) }
                )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 130)
    }

    @ViewBuilder
    private var floatingBallOverlay: some View {
        FloatingWorkoutBall(
            state: vm.ballState,
            onSingleTap: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    vm.ballState.showPanel.toggle()
                }
            },
            onDoubleTap: { vm.handleBallDoubleTap() },
            onLongPress: { showTabSwitcher = true },
            onDragEnd: { point, frame in
                snapToEdges(point: point, in: frame)
            }
        )
    }

    @ViewBuilder
    private var tabSwitcherOverlay: some View {
        if showTabSwitcher {
            GeometryReader { geo in
                let center = vm.ballState.position ?? CGPoint(x: geo.size.width - 40, y: geo.size.height - 140)
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
            state: vm.ballState,
            quickReps: $vm.quickReps,
            quickRIR: $vm.quickRIR,
            onPlus15: { vm.handlePlusRest() },
            onTogglePause: { vm.handleTogglePause() },
            onSkip: { vm.handleSkipRest() },
            onStartRest: { vm.handleStartRest() },
            onCompleteSet: { vm.handleCompleteSet() },
            onEnd: { vm.endSession() }
        )
        .presentationDetents([.height(280)])
    }
}

// MARK: - RoutineDayCard

struct RoutineDayCard: View {
    let routine: Routine
    let isOpen: Bool
    let sessionCoordinator: SessionCoordinator
    let restTimer: RestTimerManager
    let modelContext: ModelContext
    let onToggle: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.name)
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)

                        if let exercises = routine.exercises, !exercises.isEmpty {
                            let firstExercise = exercises.sorted(by: { $0.order < $1.order }).first
                            Text("\(firstExercise?.exercise?.name ?? "无") 等 · 约 \(estimateMinutes(for: routine)) 分钟")
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
                        if isActive { sessionCoordinator.endSession() } else { onStart() }
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

// MARK: - ExercisePlanPreview

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

// MARK: - Safe subscript (shared across Train feature)

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
