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
                    StatusIndicatorView()
                }
                #endif
                
                Group {
                    switch sessionCoordinator.state {
                    case .idle:
                        routineSelectionView
                case .starting:
                    VStack {
                        ProgressView()
                        Text("Starting...")
                    }
                case .running(let sessionId, let exerciseIndex, let setIndex):
                    trainingView(sessionId: sessionId, exerciseIndex: exerciseIndex, setIndex: setIndex)
                case .resting(let sessionId, let remaining):
                    // During rest, we should show the current exercise (will be updated after rest)
                    // For now, use the sessionCoordinator's tracked indices
                    trainingView(sessionId: sessionId, exerciseIndex: sessionCoordinator.currentExerciseIndex, setIndex: sessionCoordinator.currentSetIndex)
                        .overlay(restTimerOverlay(remaining: remaining))
                case .paused:
                    Text("Paused")
                case .ending:
                    VStack {
                        ProgressView()
                        Text("Ending session...")
                    }
                case .finished:
                    routineSelectionView
                case .error(let message):
                    VStack {
                        Text("Error: \(message)")
                        Button("Back") {
                            sessionCoordinator.state = .idle
                        }
                    }
                    }
                }
            }
            .navigationTitle("Train")
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
            Text("Select Routine")
                .font(.title2)
                .padding()
            
            if routines.isEmpty {
                VStack(spacing: 12) {
                    Text("No routines available")
                        .foregroundColor(.secondary)
                    Text("Please check if sample data was generated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                List(routines) { routine in
                    Button(action: {
                        print("Starting routine: \(routine.name)")
                        selectedRoutineId = routine.id
                        if let session = sessionCoordinator.startSession(routineId: routine.id) {
                            print("Session started: \(session.id)")
                        } else {
                            print("Failed to start session")
                        }
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
               let exercises = session.exercises?.sorted(by: { $0.order < $1.order }),
               exerciseIndex < exercises.count {
                let sessionExercise = exercises[exerciseIndex]
                let exercise = sessionExercise.exercise
                let routineExercise = getRoutineExercise(for: sessionExercise)
                let targetSets = routineExercise?.targetSets ?? 3
                
                VStack(spacing: 20) {
                    // Exercise name
                    Text(exercise?.name ?? "Unknown")
                        .font(.largeTitle)
                        .bold()
                        .padding()
                    
                    // Set progress
                    Text("Set \(setIndex + 1) of \(targetSets)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    // Reps input
                    VStack(alignment: .leading) {
                        Text("Reps")
                            .font(.headline)
                        TextField("Enter reps", text: $currentReps)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2)
                    }
                    .padding()
                    
                    // RIR input
                    VStack(alignment: .leading) {
                        Text("RIR (Reps in Reserve)")
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
                        Text("Complete Set")
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
                        Text("End Session")
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
                Text("No active exercise")
            }
        }
    }
    
    private func restTimerOverlay(remaining: Int) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Rest")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Text("\(restTimer.remainingSeconds)s")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 20) {
                    Button(action: {
                        sessionCoordinator.extendRest(by: 15)
                        restTimer.extend(by: 15)
                    }) {
                        Text("+15s")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue.opacity(0.7))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        sessionCoordinator.extendRest(by: 30)
                        restTimer.extend(by: 30)
                    }) {
                        Text("+30s")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue.opacity(0.7))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        sessionCoordinator.skipRest()
                        restTimer.skip()
                    }) {
                        Text("Skip")
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

