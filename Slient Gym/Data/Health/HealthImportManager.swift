//
//  HealthImportManager.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
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
        let predicate = HKQuery.predicateForWorkouts(
            with: .running,
            startDate: Calendar.current.date(byAdding: .day, value: -days, to: Date()),
            endDate: Date()
        )
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
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
                
                var importedCount = 0
                
                for workout in workouts {
                    // 检查是否已导入
                    if existingUUIDs.contains(workout.uuid) {
                        continue
                    }
                    
                    // 识别来源
                    let sourceName = workout.sourceRevision.source.name
                    let sourceBundleId = workout.sourceRevision.source.bundleIdentifier
                    
                    // 只导入 NRC 或标记为跑步的 workout
                    let isNRC = sourceName.contains("Nike Run Club") || 
                                sourceBundleId.contains("nike") ||
                                sourceName.contains("NRC")
                    
                    // 创建 ExternalWorkout
                    let externalWorkout = ExternalWorkout(
                        uuid: workout.uuid,
                        activityType: workout.workoutActivityType.rawValue,
                        startAt: workout.startDate,
                        endAt: workout.endDate,
                        duration: workout.duration,
                        totalDistance: workout.totalDistance?.doubleValue(for: HKUnit.meter()),
                        totalEnergy: workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()),
                        sourceName: sourceName,
                        sourceBundleId: sourceBundleId,
                        importedAt: Date()
                    )
                    
                    context.insert(externalWorkout)
                    importedCount += 1
                }
                
                // 保存
                do {
                    try context.save()
                    self.lastImportDate = Date()
                    print("Imported \(importedCount) running workouts")
                    continuation.resume(returning: importedCount)
                } catch {
                    print("Error saving imported workouts: \(error.localizedDescription)")
                    continuation.resume(returning: importedCount)
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

