//
//  TrainView.swift
//  Slient Gym
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
    @State private var selectedRoutineId: UUID?
    @State private var currentReps: String = ""
    @State private var currentRIR: Int = 1
    @State private var showRestTimer = false
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
            VStack(spacing: 0) {
                #if os(iOS)
                if case .idle = sessionCoordinator.state {
                    StatusCapsuleView()
                }
                #endif
                
                Group {
                    switch sessionCoordinator.state {
                    case .idle:
                        routineSelectionView
                case .starting:
                    VStack {
                        ProgressView()
                        Text("正在启动...")
                    }
                case .running(let sessionId, let exerciseIndex, let setIndex):
                    trainingView(sessionId: sessionId, exerciseIndex: exerciseIndex, setIndex: setIndex)
                case .resting(let sessionId, let remaining):
                    // During rest, we should show the current exercise (will be updated after rest)
                    // For now, use the sessionCoordinator's tracked indices
                    trainingView(sessionId: sessionId, exerciseIndex: sessionCoordinator.currentExerciseIndex, setIndex: sessionCoordinator.currentSetIndex)
                        .overlay(restTimerOverlay(remaining: remaining))
                case .paused:
                    Text("已暂停")
                case .ending:
                    VStack {
                        ProgressView()
                        Text("正在结束训练...")
                    }
                case .finished:
                    routineSelectionView
                case .error(let message):
                    VStack {
                        Text("错误: \(message)")
                        Button("返回") {
                            sessionCoordinator.state = .idle
                        }
                    }
                    }
                }
            }
            .navigationTitle("训练")
        }
        .onAppear {
            // Update sessionCoordinator with actual modelContext
            sessionCoordinator.modelContext = modelContext
            print("TrainView appeared, routines count: \(routines.count)")
            print("SessionCoordinator state: \(sessionCoordinator.state)")
            
            // Setup calendar integration
            #if os(iOS)
            sessionCoordinator.onSessionEnded = { [self] session in
                endedSession = session
                showCalendarSheet = true
            }
            #endif
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
    
    private var routineSelectionView: some View {
        VStack(spacing: 20) {
            Text("选择训练计划")
                .font(.title2)
                .padding()
            
            if routines.isEmpty {
                VStack(spacing: 12) {
                    Text("暂无训练计划")
                        .foregroundColor(.secondary)
                    Text("请检查示例数据是否已生成")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
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
                        HStack {
                            Text(routine.name)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func trainingView(sessionId: UUID, exerciseIndex: Int, setIndex: Int) -> some View {
        VStack {
            if let session = sessionCoordinator.currentSession,
               session.id == sessionId,
               let exercises = session.exercises?.sorted(by: { $0.order < $1.order }),
               exerciseIndex < exercises.count {
                let sessionExercise = exercises[exerciseIndex]
                let exercise = sessionExercise.exercise
                let routineExercise = getRoutineExercise(for: sessionExercise)
                let targetSets = max(1, routineExercise?.targetSets ?? 3) // 确保至少为 1
                
                VStack(spacing: 20) {
                    // Exercise name
                    Text(exercise?.name ?? "未知动作")
                        .font(.largeTitle)
                        .bold()
                        .padding()
                    
                    // Set progress
                    Text("第 \(setIndex + 1) 组 / 共 \(targetSets) 组")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    // Reps input
                    VStack(alignment: .leading) {
                        Text("次数")
                            .font(.headline)
                        TextField("输入次数", text: $currentReps)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2)
                    }
                    .padding()
                    
                    // RIR input
                    VStack(alignment: .leading) {
                        Text("RIR (保留次数)")
                            .font(.headline)
                        Picker("RIR", selection: $currentRIR) {
                            ForEach(0...4, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    
                    // Complete set button
                    Button(action: {
                        if let reps = Int(currentReps) {
                            sessionCoordinator.completeSet(reps: reps, rir: currentRIR)
                            currentReps = ""
                            currentRIR = 1
                        }
                    }) {
                        Text("完成一组")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(currentReps.isEmpty)
                    .padding()
                    
                    Spacer()
                    
                    // End session button
                    Button(action: {
                        sessionCoordinator.endSession()
                    }) {
                        Text("结束训练")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            } else {
                Text("无活动动作")
            }
        }
    }
    
    private func restTimerOverlay(remaining: Int) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("休息")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Text("\(restTimer.remainingSeconds)秒")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 20) {
                    Button(action: {
                        sessionCoordinator.extendRest(by: 15)
                        restTimer.extend(by: 15)
                    }) {
                        Text("+15秒")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue.opacity(0.7))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        sessionCoordinator.extendRest(by: 30)
                        restTimer.extend(by: 30)
                    }) {
                        Text("+30秒")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue.opacity(0.7))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        sessionCoordinator.skipRest()
                        restTimer.skip()
                    }) {
                        Text("跳过")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.7))
                            .cornerRadius(8)
                    }
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
    
    private func handleStateChange(_ newState: TrainingSessionState) {
        switch newState {
        case .resting(_, let remaining):
            showRestTimer = true
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

