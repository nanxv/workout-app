//
//  SessionCoordinator.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import SwiftData
import Combine
#if os(iOS)
import HealthKit
#endif

enum TrainingSessionState: Equatable {
    case idle
    case starting(routineId: UUID)
    case running(sessionId: UUID, currentExerciseIndex: Int, currentSetIndex: Int)
    case resting(sessionId: UUID, remainingSeconds: Int)
    case paused(sessionId: UUID)
    case ending(sessionId: UUID)
    case finished(sessionId: UUID)
    case error(message: String)
    
    static func == (lhs: TrainingSessionState, rhs: TrainingSessionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.starting(let lhsId), .starting(let rhsId)):
            return lhsId == rhsId
        case (.running(let lhsId, let lhsEx, let lhsSet), .running(let rhsId, let rhsEx, let rhsSet)):
            return lhsId == rhsId && lhsEx == rhsEx && lhsSet == rhsSet
        case (.resting(let lhsId, let lhsRem), .resting(let rhsId, let rhsRem)):
            return lhsId == rhsId && lhsRem == rhsRem
        case (.paused(let lhsId), .paused(let rhsId)):
            return lhsId == rhsId
        case (.ending(let lhsId), .ending(let rhsId)):
            return lhsId == rhsId
        case (.finished(let lhsId), .finished(let rhsId)):
            return lhsId == rhsId
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

@MainActor
class SessionCoordinator: ObservableObject {
    @Published var state: TrainingSessionState = .idle
    @Published var currentSession: Session?
    
    var modelContext: ModelContext
    
    // Track current position for state transitions
    var currentExerciseIndex: Int = 0
    var currentSetIndex: Int = 0
    
    // Watch integration
    private let watchConnectivity = WatchConnectivityManager.shared
    private let watchLauncher = WatchWorkoutLauncher.shared
    
    // Calendar integration
    #if os(iOS)
    private let calendarManager = CalendarManager.shared
    var onSessionEnded: ((Session) -> Void)?
    #endif
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        watchConnectivity.onMessageReceived = { [weak self] message in
            guard let self = self else { return }
            
            switch message.type {
            case .workoutSaved:
                if let healthWorkoutUUID = message.healthWorkoutUUID,
                   let session = self.currentSession {
                    session.healthWorkoutUUID = healthWorkoutUUID
                    try? self.modelContext.save()
                }
            case .error:
                print("Watch error: \(message.errorMessage ?? "Unknown")")
            default:
                break
            }
        }
    }
    
    func startSession(routineId: UUID) -> Session? {
        guard case .idle = state else {
            print("Cannot start session: current state is \(state)")
            return nil
        }
        
        print("Starting session for routine: \(routineId)")
        state = .starting(routineId: routineId)
        
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate { $0.id == routineId }
        )
        
        guard let routine = try? modelContext.fetch(descriptor).first else {
            state = .error(message: "Routine not found")
            return nil
        }
        
        // 空值保护：确保 routine 有 exercises
        guard let routineExercises = routine.exercises, !routineExercises.isEmpty else {
            state = .error(message: "Routine has no exercises")
            return nil
        }
        
        let session = Session(routine: routine, startAt: Date())
        modelContext.insert(session)
        
        // Create SessionExercise entries for each RoutineExercise
        let sortedExercises = routineExercises.sorted(by: { $0.order < $1.order })
        for (index, routineExercise) in sortedExercises.enumerated() {
            guard let exercise = routineExercise.exercise else {
                print("Warning: RoutineExercise at index \(index) has no exercise, skipping")
                continue
            }
            let sessionExercise = SessionExercise(
                session: session,
                exercise: exercise,
                order: index
            )
            modelContext.insert(sessionExercise)
        }
        
        // 确保至少创建了一个 SessionExercise
        guard session.exercises?.isEmpty == false else {
            state = .error(message: "Failed to create session exercises")
            return nil
        }
        
        do {
            try modelContext.save()
            currentSession = session
            currentExerciseIndex = 0
            currentSetIndex = 0
            
            // 确保 targetSets 至少为 1（防止越界）
            let firstExercise = sortedExercises.first
            let targetSets = max(1, firstExercise?.targetSets ?? 3)
            
            state = .running(sessionId: session.id, currentExerciseIndex: 0, currentSetIndex: 0)
            
            // Watch workout 启动已移到 TrainView 中后台执行，这里不再阻塞
            // 但可以发送启动消息（如果 watch 可达）
            #if os(iOS)
            if watchConnectivity.isWatchReachable {
                watchConnectivity.sendStartWorkout(
                    sessionId: session.id,
                    activityType: Int(HKWorkoutActivityType.traditionalStrengthTraining.rawValue)
                )
            }
            #endif
            
            return session
        } catch {
            state = .error(message: "Failed to save session: \(error.localizedDescription)")
            return nil
        }
    }
    
    func completeSet(reps: Int, rir: Int, note: String? = nil) {
        guard case .running(let sessionId, let exerciseIndex, let setIndex) = state,
              let session = currentSession,
              session.id == sessionId else {
            print("Cannot complete set: invalid state or session")
            return
        }
        
        guard let exercises = session.exercises?.sorted(by: { $0.order < $1.order }),
              exerciseIndex < exercises.count else {
            print("Cannot complete set: exercise index out of bounds")
            state = .error(message: "Exercise index out of bounds")
            return
        }
        
        let sessionExercise = exercises[exerciseIndex]
        
        // 空值保护
        guard sessionExercise.exercise != nil else {
            print("Cannot complete set: sessionExercise has no exercise")
            state = .error(message: "Session exercise has no exercise")
            return
        }
        
        let restSeconds = getRestSecondsForExercise(sessionExercise)
        
        let setEntry = SetEntry(
            sessionExercise: sessionExercise,
            setIndex: setIndex,
            reps: reps,
            rir: rir,
            restSecondsUsed: 0, // Will be updated when rest ends
            note: note
        )
        
        modelContext.insert(setEntry)
        
        // Update tracking
        currentExerciseIndex = exerciseIndex
        currentSetIndex = setIndex
        
        // Check if more sets needed
        let routineExercise = getRoutineExercise(for: sessionExercise)
        let targetSets = max(1, routineExercise?.targetSets ?? 3) // 确保至少为 1
        
        // Update watch with current exercise info
        #if os(iOS)
        if let exerciseName = sessionExercise.exercise?.name {
            watchConnectivity.sendUpdateNow(
                sessionId: sessionId,
                exerciseName: exerciseName,
                setIndex: setIndex,
                totalSets: targetSets
            )
        }
        #endif
        
        if setIndex + 1 < targetSets {
            // More sets for this exercise
            state = .resting(sessionId: sessionId, remainingSeconds: restSeconds)
        } else {
            // Move to next exercise or finish
            if exerciseIndex + 1 < exercises.count {
                currentExerciseIndex = exerciseIndex + 1
                currentSetIndex = 0
                state = .running(sessionId: sessionId, currentExerciseIndex: currentExerciseIndex, currentSetIndex: 0)
            } else {
                // All exercises done
                endSession()
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            state = .error(message: "Failed to save set: \(error.localizedDescription)")
        }
    }
    
    func startRest(seconds: Int) {
        guard case .running(let sessionId, _, _) = state else { return }
        state = .resting(sessionId: sessionId, remainingSeconds: seconds)
    }
    
    func extendRest(by seconds: Int) {
        guard case .resting(let sessionId, let remaining) = state else { return }
        state = .resting(sessionId: sessionId, remainingSeconds: remaining + seconds)
    }
    
    func skipRest() {
        guard case .resting(_, let restSeconds) = state,
              currentSession != nil else { return }
        
        // Update the last set's restSecondsUsed
        updateLastSetRestTime(restSeconds: restSeconds)
        
        // Continue to next set or exercise
        continueAfterRest()
    }
    
    func restFinished() {
        guard case .resting(_, let restSeconds) = state,
              currentSession != nil else { return }
        
        // Update the last set's restSecondsUsed
        updateLastSetRestTime(restSeconds: restSeconds)
        
        // Continue to next set or exercise
        continueAfterRest()
    }
    
    private func continueAfterRest() {
        guard let session = currentSession,
              let exercises = session.exercises?.sorted(by: { $0.order < $1.order }) else {
            return
        }
        
        // Check if more sets for current exercise
        if currentExerciseIndex < exercises.count {
            let sessionExercise = exercises[currentExerciseIndex]
            let routineExercise = getRoutineExercise(for: sessionExercise)
            let targetSets = routineExercise?.targetSets ?? 3
            let completedSets = sessionExercise.sets?.count ?? 0
            
            if completedSets < targetSets {
                // Continue with next set of current exercise
                currentSetIndex = completedSets
                state = .running(sessionId: session.id, currentExerciseIndex: currentExerciseIndex, currentSetIndex: currentSetIndex)
                return
            }
        }
        
        // Move to next exercise
        if currentExerciseIndex + 1 < exercises.count {
            currentExerciseIndex += 1
            currentSetIndex = 0
            state = .running(sessionId: session.id, currentExerciseIndex: currentExerciseIndex, currentSetIndex: 0)
        } else {
            // All done
            endSession()
        }
    }
    
    func endSession() {
        guard let session = currentSession else { return }
        
        state = .ending(sessionId: session.id)
        session.endAt = Date()
        
        // Stop watch workout
        #if os(iOS)
        watchConnectivity.sendStopWorkout(sessionId: session.id)
        #endif
        
        do {
            try modelContext.save()
            state = .finished(sessionId: session.id)
            
            // Notify that session ended (for Calendar integration)
            #if os(iOS)
            onSessionEnded?(session)
            #endif
            
            currentSession = nil
        } catch {
            state = .error(message: "Failed to end session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func getRestSecondsForExercise(_ sessionExercise: SessionExercise) -> Int {
        let routineExercise = getRoutineExercise(for: sessionExercise)
        return routineExercise?.restSecondsDefault ?? 90
    }
    
    private func getRoutineExercise(for sessionExercise: SessionExercise) -> RoutineExercise? {
        guard let session = sessionExercise.session,
              let routine = session.routine,
              let exercise = sessionExercise.exercise else {
            return nil
        }
        
        return routine.exercises?.first { $0.exercise?.id == exercise.id }
    }
    
    private func updateLastSetRestTime(restSeconds: Int) {
        guard let session = currentSession,
              let exercises = session.exercises?.sorted(by: { $0.order < $1.order }),
              currentExerciseIndex < exercises.count else {
            return
        }
        
        let sessionExercise = exercises[currentExerciseIndex]
        
        // Find the last completed set
        if let sets = sessionExercise.sets?.sorted(by: { $0.setIndex < $1.setIndex }),
           let lastSet = sets.last {
            lastSet.restSecondsUsed = restSeconds
            try? modelContext.save()
        }
    }
}

