//
//  WatchWorkoutManager.swift
//  Silent Gym Watch App
//
//  Phase 4 — complete HKWorkoutSession + HKLiveWorkoutBuilder integration.
//  Key improvements:
//  • HKLiveWorkoutBuilderDelegate for live metrics (heartRate, activeEnergy)
//  • Routine name stored as HealthKit metadata
//  • Average heart rate computed from statistics before finishing
//  • Removed duplicate healthStore.save() call (builder.finishWorkout saves automatically)
//  • Sends completed sets to iPhone via WatchConnectivityManager (offline-capable)
//

import Foundation
import HealthKit
import WatchKit

#if os(watchOS)
@MainActor
class WatchWorkoutManager: NSObject, ObservableObject {

    static let shared = WatchWorkoutManager()

    // MARK: - HealthKit

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    // MARK: - Published state

    @Published var isRunning         = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var avgHeartRate: Double = 0
    @Published var currentExerciseName: String?
    @Published var currentSetIndex: Int = 0
    @Published var totalSets: Int = 0

    // MARK: - Session metadata

    var currentSessionId: UUID?
    var currentRoutineName: String?

    // MARK: - Timer & callbacks

    private var elapsedTimer: Timer?
    private var startDate: Date?
    var onWorkoutSaved: ((UUID) -> Void)?

    // MARK: - Init

    override init() {
        super.init()
        requestAuthorization()
    }

    // MARK: - Authorization

    private func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned)
        ]
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]

        healthStore.requestAuthorization(toShare: share, read: read) { _, error in
            if let e = error { print("HealthKit auth error: \(e)") }
        }
    }

    // MARK: - Start

    func startWorkout(
        activityType: HKWorkoutActivityType = .traditionalStrengthTraining,
        sessionId: UUID? = nil,
        routineName: String? = nil
    ) {
        guard !isRunning else { return }

        currentSessionId   = sessionId ?? UUID()
        currentRoutineName = routineName

        let config = HKWorkoutConfiguration()
        config.activityType  = activityType
        config.locationType  = .indoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()

            session?.delegate  = self
            builder?.delegate  = self
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )

            let now = Date()
            startDate = now
            session?.startActivity(with: now)
            builder?.beginCollection(withStart: now) { [weak self] _, error in
                if let e = error { print("Builder beginCollection error: \(e)") }
                // Attach metadata immediately after collection begins
                self?.addMetadata(routineName: routineName)
            }

            isRunning = true
            startElapsedTimer()
            WKInterfaceDevice.current().play(.start)

        } catch {
            print("HKWorkoutSession start error: \(error)")
        }
    }

    // MARK: - Stop

    func stopWorkout() {
        guard isRunning, let session else { return }

        stopElapsedTimer()
        isRunning = false

        session.end()
        WKInterfaceDevice.current().play(.stop)

        // Capture final average HR before finishing
        let finalAvgHR = readAverageHeartRate()

        builder?.endCollection(withEnd: Date()) { [weak self] _, error in
            if let e = error { print("Builder endCollection error: \(e)") }
            self?.finishAndSave(avgHeartRate: finalAvgHR)
        }
    }

    // MARK: - Exercise info update

    func updateExerciseInfo(name: String, setIndex: Int, totalSets: Int) {
        currentExerciseName = name
        self.currentSetIndex = setIndex
        self.totalSets       = totalSets
    }

    // MARK: - Log a set (sends to iPhone, queued if offline)

    func logCompletedSet(reps: Int, weightKg: Double? = nil, rir: Int = 0) {
        guard let sid = currentSessionId,
              let exerciseName = currentExerciseName else { return }

        let payload = SetEntryPayload(
            sessionId: exerciseName.isEmpty ? sid : sid,
            exerciseName: exerciseName,
            setIndex: currentSetIndex,
            reps: reps,
            weightKg: weightKg,
            rir: rir
        )
        WatchConnectivityManager.shared.sendSetEntry(payload)
        WKInterfaceDevice.current().play(.success)
    }

    // MARK: - Metadata

    private func addMetadata(routineName: String?) {
        var meta: [String: Any] = [
            HKMetadataKeyWorkoutBrandName: "Silent Gym"
        ]
        if let name = routineName { meta["RoutineName"] = name }
        if let sid  = currentSessionId { meta["SilentGymSessionId"] = sid.uuidString }

        builder?.addMetadata(meta) { _, error in
            if let e = error { print("Metadata error: \(e)") }
        }
    }

    // MARK: - Metrics helpers

    private func readAverageHeartRate() -> Double {
        guard let builder else { return 0 }
        let hrType = HKQuantityType(.heartRate)
        if let stats = builder.statistics(for: hrType),
           let avg   = stats.averageQuantity() {
            return avg.doubleValue(for: .init(from: "count/min"))
        }
        return heartRate  // fallback to last known value
    }

    private func updateLiveMetrics() {
        guard let builder else { return }

        if let stats = builder.statistics(for: HKQuantityType(.heartRate)),
           let latest = stats.mostRecentQuantity() {
            heartRate = latest.doubleValue(for: .init(from: "count/min"))
        }
        if let stats = builder.statistics(for: HKQuantityType(.activeEnergyBurned)),
           let sum   = stats.sumQuantity() {
            activeEnergy = sum.doubleValue(for: .kilocalorie())
        }
        // Live heart rate to iPhone (realtime)
        if let sid = currentSessionId, heartRate > 0 {
            WatchConnectivityManager.shared.sendHeartRate(heartRate, sessionId: sid)
        }
    }

    // MARK: - Finish & save

    private func finishAndSave(avgHeartRate: Double) {
        builder?.finishWorkout { [weak self] workout, error in
            guard let self else { return }
            if let e = error { print("finishWorkout error: \(e)"); return }
            guard let workout else { return }

            // NOTE: HKLiveWorkoutBuilder.finishWorkout() already saves the workout.
            // We do NOT call healthStore.save() again (that would duplicate the record).

            DispatchQueue.main.async {
                self.avgHeartRate = avgHeartRate
            }

            let msg = WatchMessage(
                type: .workoutSaved,
                sessionId: self.currentSessionId,
                heartRate: avgHeartRate,
                activeCalories: self.activeEnergy,
                healthWorkoutUUID: workout.uuid
            )
            WatchConnectivityManager.shared.send(msg)
            self.onWorkoutSaved?(workout.uuid)

            // Write complication data for today
            ComplicationDataWriter.shared.didFinishWorkout(
                routineName: self.currentRoutineName ?? "训练完成",
                duration: self.elapsedTime
            )
        }
    }

    // MARK: - Elapsed timer

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        // State transitions are handled through the builder delegate and direct calls.
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("HKWorkoutSession error: \(error)")
        DispatchQueue.main.async { self.stopWorkout() }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    /// Called by HealthKit on a background thread whenever new statistics arrive.
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        DispatchQueue.main.async { self.updateLiveMetrics() }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
#endif
