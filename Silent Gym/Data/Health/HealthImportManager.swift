//
//  HealthImportManager.swift
//  Silent Gym
//
//  Phase 4:
//  • Fixed iOS 18+ active-energy reading (HKWorkout.statistics(for:))
//  • Added writeStrengthWorkout() — saves a strength-training HKWorkout
//    with Routine metadata when no Apple Watch was present
//  • Imports both Running AND strength workouts from HealthKit
//

import Foundation
import Combine
import HealthKit
import SwiftData

#if os(iOS)

@MainActor
class HealthImportManager: ObservableObject {

    static let shared = HealthImportManager()

    private let healthStore = HKHealthStore()

    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var lastImportDate: Date?
    @Published var isWritingWorkout = false

    // MARK: - Init

    private init() { checkAuthStatus() }

    private func checkAuthStatus() {
        authorizationStatus = healthStore.authorizationStatus(for: .workoutType())
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        let read: Set<HKObjectType> = [
            .workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling)
        ]
        let share: Set<HKSampleType> = [
            .workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: share, read: read)
            checkAuthStatus()
            return authorizationStatus != .notDetermined
        } catch {
            print("HealthKit auth error: \(error)")
            return false
        }
    }

    // MARK: - Import from HealthKit

    /// Import both running and strength-training workouts from the last `days` days.
    func importWorkouts(days: Int = 90, context: ModelContext) async -> Int {
        guard await requestAuthorization() else { return 0 }

        let existingUUIDs = existingWorkoutUUIDs(context: context)
        let since = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let datePred = HKQuery.predicateForSamples(
            withStart: since, end: Date(), options: .strictStartDate
        )

        // Fetch all activity types we care about
        let activityPreds = [
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForWorkouts(with: .traditionalStrengthTraining),
            HKQuery.predicateForWorkouts(with: .functionalStrengthTraining),
            HKQuery.predicateForWorkouts(with: .cycling)
        ]
        let activityPred = NSCompoundPredicate(orPredicateWithSubpredicates: activityPreds)
        let combined = NSCompoundPredicate(
            andPredicateWithSubpredicates: [activityPred, datePred]
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: combined,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { [weak self] _, samples, error in
                guard let self else { continuation.resume(returning: 0); return }
                if let e = error { print("HKSampleQuery error: \(e)"); continuation.resume(returning: 0); return }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: 0); return
                }

                let newWorkouts = workouts.filter { !existingUUIDs.contains($0.uuid) }
                let records = newWorkouts.map { self.buildRecord(from: $0) }

                Task { @MainActor in
                    for r in records {
                        context.insert(r)
                    }
                    try? context.save()
                    self.lastImportDate = Date()
                    continuation.resume(returning: records.count)
                }
            }
            healthStore.execute(query)
        }
    }

    // Legacy alias used by existing call sites
    func importRunningWorkouts(days: Int = 90, context: ModelContext) async -> Int {
        await importWorkouts(days: days, context: context)
    }

    // MARK: - Write a strength workout to HealthKit (when no Watch paired)

    /// Saves a `HKWorkout` representing a Silent Gym strength session.
    /// This gives the session a presence in the system Health app with Routine metadata.
    func writeStrengthWorkout(
        startDate: Date,
        endDate: Date,
        routineName: String,
        totalSets: Int = 0,
        estimatedCalories: Double? = nil
    ) async {
        guard await requestAuthorization() else { return }

        isWritingWorkout = true
        defer { Task { @MainActor in self.isWritingWorkout = false } }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: config,
            device: .local()
        )

        // Begin collection
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            builder.beginCollection(withStart: startDate) { _, _ in c.resume() }
        }

        // Attach metadata — routine name visible in the system Fitness app
        let meta: [String: Any] = [
            HKMetadataKeyWorkoutBrandName: "Silent Gym",
            "RoutineName": routineName,
            "TotalSets": totalSets
        ]
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            builder.addMetadata(meta) { _, _ in c.resume() }
        }

        // Add estimated calorie sample if provided
        if let kcal = estimatedCalories, kcal > 0 {
            let energyType = HKQuantityType(.activeEnergyBurned)
            let sample = HKQuantitySample(
                type: energyType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                start: startDate,
                end: endDate
            )
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                builder.add([sample]) { _, _ in c.resume() }
            }
        }

        // End collection and finalise
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            builder.endCollection(withEnd: endDate) { _, _ in c.resume() }
        }

        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            builder.finishWorkout { workout, error in
                if let e = error {
                    print("writeStrengthWorkout finishWorkout error: \(e)")
                } else if let w = workout {
                    print("✅ Wrote strength workout to Health: \(w.uuid) [\(routineName)]")
                }
                c.resume()
            }
        }
    }

    // MARK: - Check Nike Run Club

    func checkNRCConnection() async -> Bool {
        guard await requestAuthorization() else { return false }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: HKQuery.predicateForWorkouts(with: .running),
                limit: 20,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                ]
            ) { _, samples, _ in
                let found = (samples as? [HKWorkout])?.contains {
                    let src = $0.sourceRevision.source
                    return src.name.contains("Nike") || src.bundleIdentifier.contains("nike")
                } ?? false
                continuation.resume(returning: found)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Helpers

    private func buildRecord(from workout: HKWorkout) -> ExternalWorkout {
        let energy = activeEnergy(from: workout)
        return ExternalWorkout(
            uuid: workout.uuid,
            activityType: Int(workout.workoutActivityType.rawValue),
            startAt: workout.startDate,
            endAt: workout.endDate,
            duration: workout.duration,
            totalDistance: workout.totalDistance?.doubleValue(for: .meter()),
            totalEnergy: energy,
            sourceName: workout.sourceRevision.source.name,
            sourceBundleId: workout.sourceRevision.source.bundleIdentifier,
            importedAt: Date()
        )
    }

    /// Energy reading that works on iOS 16 through iOS 18+.
    private func activeEnergy(from workout: HKWorkout) -> Double? {
        if #available(iOS 16.0, *) {
            // Preferred API: statistics(for:) — available from iOS 16 on HKWorkout
            return workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?
                .doubleValue(for: .kilocalorie())
        } else {
            return workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        }
    }

    private func existingWorkoutUUIDs(context: ModelContext) -> Set<UUID> {
        let desc = FetchDescriptor<ExternalWorkout>()
        return Set((try? context.fetch(desc))?.map(\.uuid) ?? [])
    }
}
#endif
