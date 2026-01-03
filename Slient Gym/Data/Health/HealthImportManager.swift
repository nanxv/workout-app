//
//  HealthImportManager.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
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
    
    private init() {
        checkAuthorizationStatus()
    }
    
    /// 检查授权状态
    private func checkAuthorizationStatus() {
        let workoutType = HKObjectType.workoutType()
        authorizationStatus = healthStore.authorizationStatus(for: workoutType)
    }
    
    /// 请求 HealthKit 读取权限
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            checkAuthorizationStatus()
            // For read-only access, we check if we can read
            return authorizationStatus != .notDetermined
        } catch {
            print("HealthKit authorization error: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 从 HealthKit 导入 Running workouts
    /// - Parameters:
    ///   - days: 导入最近多少天的数据（默认 90 天）
    ///   - context: SwiftData ModelContext
    /// - Returns: 导入的 ExternalWorkout 数量
    func importRunningWorkouts(days: Int = 90, context: ModelContext) async -> Int {
        guard await requestAuthorization() else {
            print("HealthKit authorization denied")
            return 0
        }
        
        // 获取已导入的 UUIDs（用于去重）
        let existingUUIDs = getExistingWorkoutUUIDs(context: context)
        
        // 查询 Running workouts
        let workoutType = HKObjectType.workoutType()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForWorkouts(
            with: .running
        )
        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: Date(),
            options: .strictStartDate
        )
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, datePredicate])
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: combinedPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] query, samples, error in
                guard let self = self else {
                    continuation.resume(returning: 0)
                    return
                }
                
                if let error = error {
                    print("Error fetching workouts: \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }
                
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: 0)
                    return
                }
                
                // 收集要导入的 workouts（在主线程上处理）
                let workoutsData = workouts.compactMap { workout -> (UUID, Int, Date, Date, Double, Double?, Double?, String, String)? in
                    // 检查是否已导入
                    if existingUUIDs.contains(workout.uuid) {
                        return nil
                    }
                    
                    // 识别来源
                    let sourceName = workout.sourceRevision.source.name
                    let sourceBundleId = workout.sourceRevision.source.bundleIdentifier
                    
                    // 获取活动能量（处理 iOS 18+ 弃用警告）
                    var totalEnergy: Double? = nil
                    if #available(iOS 18.0, *) {
                        // iOS 18+ 需要使用新的 API，暂时跳过能量数据
                        // TODO: 使用 statisticsForType 获取能量数据
                    } else {
                        totalEnergy = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie())
                    }
                    
                    return (
                        workout.uuid,
                        Int(workout.workoutActivityType.rawValue),
                        workout.startDate,
                        workout.endDate,
                        workout.duration,
                        workout.totalDistance?.doubleValue(for: HKUnit.meter()),
                        totalEnergy,
                        sourceName,
                        sourceBundleId
                    )
                }
                
                let finalCount = workoutsData.count
                
                // 在主线程上插入和保存（使用 Task 而不是 await，因为回调是同步的）
                // 创建局部变量避免 Sendable 警告
                let contextToUse = context
                Task { @MainActor in
                    // 在 MainActor 上操作，确保线程安全
                    // 注意：ModelContext 不是 Sendable，但我们在 MainActor 上操作是安全的
                    for workoutData in workoutsData {
                        let externalWorkout = ExternalWorkout(
                            uuid: workoutData.0,
                            activityType: workoutData.1,
                            startAt: workoutData.2,
                            endAt: workoutData.3,
                            duration: workoutData.4,
                            totalDistance: workoutData.5,
                            totalEnergy: workoutData.6,
                            sourceName: workoutData.7,
                            sourceBundleId: workoutData.8,
                            importedAt: Date()
                        )
                        contextToUse.insert(externalWorkout)
                    }
                    
                    do {
                        try contextToUse.save()
                        self.lastImportDate = Date()
                        print("Imported \(finalCount) running workouts")
                        continuation.resume(returning: finalCount)
                    } catch {
                        print("Error saving imported workouts: \(error.localizedDescription)")
                        continuation.resume(returning: finalCount)
                    }
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    /// 获取已导入的 workout UUIDs
    private func getExistingWorkoutUUIDs(context: ModelContext) -> Set<UUID> {
        let descriptor = FetchDescriptor<ExternalWorkout>()
        guard let workouts = try? context.fetch(descriptor) else {
            return []
        }
        return Set(workouts.map { $0.uuid })
    }
    
    /// 检查 NRC 是否已同步到 Health
    func checkNRCConnection() async -> Bool {
        guard await requestAuthorization() else {
            return false
        }
        
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 10,
                sortDescriptors: [sortDescriptor]
            ) { query, samples, error in
                if let workouts = samples as? [HKWorkout] {
                    let hasNRC = workouts.contains { workout in
                        let sourceName = workout.sourceRevision.source.name
                        let sourceBundleId = workout.sourceRevision.source.bundleIdentifier
                        return sourceName.contains("Nike Run Club") ||
                               sourceBundleId.contains("nike") ||
                               sourceName.contains("NRC")
                    }
                    continuation.resume(returning: hasNRC)
                } else {
                    continuation.resume(returning: false)
                }
            }
            
            healthStore.execute(query)
        }
    }
}
#endif

