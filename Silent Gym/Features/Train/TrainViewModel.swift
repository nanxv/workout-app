//
//  TrainViewModel.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/02/25.
//

import Foundation
import SwiftData
import Combine
#if os(iOS)
import UIKit
#endif

/// ViewModel for `TrainViewWireframe`.
/// Owns the rest-timer and floating-ball state managers, and holds a
/// reference to the shared `SessionCoordinator` from the DI container.
/// All business-logic helpers that were previously embedded in the View
/// live here, keeping the View purely declarative.
@MainActor
final class TrainViewModel: ObservableObject {

    // MARK: - Owned state managers
    let restTimer = RestTimerManager()
    let ballState = FloatingBallState()

    // MARK: - Shared coordinator (injected at init)
    let coordinator: SessionCoordinator

    // MARK: - Published view-state
    @Published var openDayIds: Set<UUID> = []
    @Published var showEndSessionConfirmation = false
    @Published var capsuleHidden = false
    @Published var quickReps: String = ""
    @Published var quickRIR: Int = 1
    @Published var showRestTimer = false

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(coordinator: SessionCoordinator) {
        self.coordinator = coordinator
        setupBindings()
        // Forward nested ObservableObject changes so the owning View re-renders
        // whenever ballState or restTimer properties change.
        ballState.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        restTimer.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Public interface

    func updateModelContext(_ context: ModelContext) {
        coordinator.modelContext = context
    }

    func startTraining(routine: Routine) {
        guard let session = coordinator.startSession(routineId: routine.id) else { return }
        openDayIds.insert(routine.id)
        #if os(iOS)
        Task.detached(priority: .userInitiated) {
            await MainActor.run {
                WatchWorkoutLauncher.shared.startWatchWorkout(sessionId: session.id) { _, _ in }
            }
        }
        #endif
    }

    func handleBallDoubleTap() {
        if ballState.isResting {
            if case .running = restTimer.state {
                restTimer.pause()
                ballState.updatePauseState(isPaused: true)
            } else if case .paused = restTimer.state {
                restTimer.resume()
                ballState.updatePauseState(isPaused: false)
            }
        } else if let restSec = currentRestSeconds {
            restTimer.start(seconds: restSec)
            coordinator.startRest(seconds: restSec)
        }
    }

    func handlePlusRest() {
        restTimer.extend(by: 15)
        coordinator.extendRest(by: 15)
    }

    func handleTogglePause() {
        if case .running = restTimer.state {
            restTimer.pause()
            ballState.updatePauseState(isPaused: true)
        } else if case .paused = restTimer.state {
            restTimer.resume()
            ballState.updatePauseState(isPaused: false)
        }
    }

    func handleSkipRest() {
        restTimer.skip()
        coordinator.restFinished()
    }

    func handleStartRest() {
        guard let restSec = currentRestSeconds else { return }
        restTimer.start(seconds: restSec)
        coordinator.startRest(seconds: restSec)
    }

    func handleCompleteSet() {
        guard let reps = Int(quickReps) else { return }
        coordinator.completeSet(reps: reps, rir: quickRIR)
        quickReps = ""
        quickRIR = 1
    }

    func endSession() {
        coordinator.endSession()
        ballState.showPanel = false
    }

    // MARK: - Computed helpers (used by View and internally)

    var currentRestSeconds: Int? {
        guard let session = coordinator.currentSession,
              let exercises = session.exercises?.sorted(by: { $0.order < $1.order }),
              let currentExercise = exercises[safe: coordinator.currentExerciseIndex],
              let routine = session.routine,
              let routineExercise = routine.exercises?.first(where: { $0.exercise?.id == currentExercise.exercise?.id })
        else { return 90 }
        return routineExercise.restSecondsDefault
    }

    var currentExerciseSubtitle: String? {
        guard let session = coordinator.currentSession,
              let exercises = session.exercises?.sorted(by: { $0.order < $1.order }),
              let first = exercises.first,
              let routine = session.routine,
              let re = routine.exercises?.first(where: { $0.exercise?.id == first.exercise?.id })
        else { return nil }

        let detail: String
        if re.isHoldType, let holdSec = re.holdSecDefault {
            detail = "×\(holdSec)秒"
        } else if let repTarget = re.repTarget {
            detail = "×\(repTarget)次"
        } else {
            detail = ""
        }
        return "\(first.exercise?.name ?? "") · \(re.targetSets)组\(detail) · 休\(re.restSecondsDefault)秒"
    }

    // MARK: - Private bindings

    private func setupBindings() {
        coordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] newState in
                self?.handleStateChange(newState)
                self?.updateBallExerciseInfo()
            }
            .store(in: &cancellables)

        coordinator.$currentSession
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                guard let self else { return }
                ballState.isVisible = session != nil
                if session == nil {
                    ballState.showPanel = false
                    ballState.updateSubtitle(nil)
                    ballState.updateExerciseInfo(name: nil, setIndex: 0, totalSets: 0, nextName: nil)
                } else {
                    ballState.updateSubtitle(currentExerciseSubtitle)
                    updateBallExerciseInfo()
                }
            }
            .store(in: &cancellables)

        restTimer.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] timerState in
                guard let self else { return }
                switch timerState {
                case .running(let remaining):
                    let total = currentRestSeconds ?? 90
                    ballState.updateRestState(isActive: true, remaining: TimeInterval(remaining), total: TimeInterval(total))
                    ballState.updatePauseState(isPaused: false)
                    #if os(iOS)
                    if remaining == 0 {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    #endif
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
            .store(in: &cancellables)
    }

    private func handleStateChange(_ state: TrainingSessionState) {
        switch state {
        case .resting(_, let remaining):
            showRestTimer = true
            ballState.updateSubtitle(currentExerciseSubtitle)
            restTimer.stop()
            restTimer.start(seconds: remaining)
            restTimer.onFinish = { [weak self] in
                self?.coordinator.restFinished()
                self?.showRestTimer = false
            }
            ballState.updateRestState(isActive: true, remaining: TimeInterval(remaining), total: TimeInterval(remaining))
            ballState.updatePauseState(isPaused: false)
        case .running:
            ballState.updateSubtitle(currentExerciseSubtitle)
            ballState.updatePauseState(isPaused: false)
            updateBallExerciseInfo()
        case .paused:
            ballState.updateSubtitle(currentExerciseSubtitle)
            updateBallExerciseInfo()
        case .finished:
            ballState.isVisible = false
            ballState.showPanel = false
            ballState.updateSubtitle(nil)
            ballState.updatePauseState(isPaused: false)
            ballState.updateExerciseInfo(name: nil, setIndex: 0, totalSets: 0, nextName: nil)
            showRestTimer = false
            restTimer.stop()
        default:
            break
        }
    }

    private func updateBallExerciseInfo() {
        guard let session = coordinator.currentSession,
              let exercises = session.exercises?.sorted(by: { $0.order < $1.order }),
              !exercises.isEmpty
        else {
            ballState.updateExerciseInfo(name: nil, setIndex: 0, totalSets: 0, nextName: nil)
            return
        }

        let currentIndex = min(coordinator.currentExerciseIndex, exercises.count - 1)
        let currentExercise = exercises[safe: currentIndex]
        let routineExercise = currentExercise.flatMap { getRoutineExercise(for: $0) }
        let totalSets = max(1, routineExercise?.targetSets ?? 1)

        let completedSets: Int
        switch coordinator.state {
        case .resting:
            completedSets = min(coordinator.currentSetIndex + 1, totalSets)
        default:
            completedSets = min(coordinator.currentSetIndex, totalSets)
        }

        let nextName = currentIndex + 1 < exercises.count ? exercises[currentIndex + 1].exercise?.name : nil

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
              let exercise = sessionExercise.exercise
        else { return nil }
        return routine.exercises?.first { $0.exercise?.id == exercise.id }
    }
}
