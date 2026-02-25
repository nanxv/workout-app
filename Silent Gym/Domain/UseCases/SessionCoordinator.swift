//
//  SessionCoordinator.swift
//  Silent Gym
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

    /// Optional equipment filter — set by AppDependencies at startup.
    var equipmentManager: EquipmentManager?

    // Track current position for state transitions
    var currentExerciseIndex: Int = 0
    var currentSetIndex: Int = 0

    // Watch integration
    private let watchConnectivity = WatchConnectivityManager.shared
    #if os(iOS)
    private let watchLauncher = WatchWorkoutLauncher.shared
    #endif

    // Calendar integration
    #if os(iOS)
    private let calendarManager = CalendarManager.shared
    var onSessionEnded: ((Session) -> Void)?
    #endif

    init(modelContext: ModelContext, equipmentManager: EquipmentManager? = nil) {
        self.modelContext = modelContext
        self.equipmentManager = equipmentManager
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
        session.routineNameSnapshot = routine.name
        modelContext.insert(session)
        
        // Create SessionExercise entries for each RoutineExercise
        // If EquipmentManager is configured, skip exercises the user can't perform.
        let sortedExercises = routineExercises.sorted(by: { $0.order < $1.order })
        var sessionOrder = 0
        for routineExercise in sortedExercises {
            guard let exercise = routineExercise.exercise else {
                print("Warning: RoutineExercise has no exercise, skipping")
                continue
            }
            if let em = equipmentManager, !em.canPerform(exercise) {
                let hint = em.suggestSubstitute(for: exercise) ?? "无替代动作"
                print("⚠️ Skipping '\(exercise.name)' — missing equipment. Suggested: \(hint)")
                continue
            }
            let sessionExercise = SessionExercise(
                session: session,
                exercise: exercise,
                order: sessionOrder
            )
            modelContext.insert(sessionExercise)
            sessionOrder += 1
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
            
            state = .running(sessionId: session.id, currentExerciseIndex: 0, currentSetIndex: 0)
            
            // Watch workout 启动已移到 TrainView 中后台执行，这里不再阻塞
            // 但可以发送启动消息（如果 watch 可达）
            #if os(iOS)
            // Send to Watch regardless of reachability — manager handles routing + queuing
            watchConnectivity.sendStartWorkout(
                sessionId: session.id,
                activityType: Int(HKWorkoutActivityType.traditionalStrengthTraining.rawValue),
                routineName: routine.name
            )
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
            note: note,
            isCompleted: true
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

            #if os(iOS)
            // Notify for Calendar integration
            onSessionEnded?(session)

            // Write this strength session to HealthKit (no Watch required)
            let startAt = session.startAt
            let endAt   = session.endAt ?? Date()
            let routine = session.routine
            let totalCompletedSets = session.exercises?
                .flatMap { $0.sets ?? [] }
                .filter(\.isCompleted).count ?? 0

            Task {
                await HealthImportManager.shared.writeStrengthWorkout(
                    startDate: startAt,
                    endDate: endAt,
                    routineName: routine?.name ?? "训练",
                    totalSets: totalCompletedSets
                )
            }
            #endif

            currentSession = nil
        } catch {
            state = .error(message: "Failed to end session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Equipment helpers

    /// Returns exercises in the routine that cannot be performed with current equipment,
    /// along with suggested substitutions.
    func unavailableExercises(in routine: Routine) -> [(exercise: Exercise, substitute: String?)] {
        guard let em = equipmentManager,
              let routineExercises = routine.exercises else { return [] }
        return routineExercises.compactMap { re -> (Exercise, String?)? in
            guard let ex = re.exercise, !em.canPerform(ex) else { return nil }
            return (ex, em.suggestSubstitute(for: ex))
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

