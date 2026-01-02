//
//  WatchWorkoutLauncher.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
@preconcurrency import HealthKit
import Combine

#if os(iOS)
import UIKit

@MainActor
class WatchWorkoutLauncher: ObservableObject {
    static let shared = WatchWorkoutLauncher()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    /// 启动 Apple Watch workout session
    /// - Parameters:
    ///   - activityType: HKWorkoutActivityType，默认使用 Traditional Strength Training
    ///   - completion: 完成回调，返回是否成功
    func startWatchWorkout(
        activityType: HKWorkoutActivityType = .traditionalStrengthTraining,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        // 检查 HealthKit 授权
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "WatchWorkoutLauncher", code: -1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available"]))
            return
        }
        
        // 创建 workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .indoor
        
        // 请求必要的权限
        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        // 创建配置的副本以避免 Sendable 问题
        let workoutConfig = HKWorkoutConfiguration()
        workoutConfig.activityType = configuration.activityType
        workoutConfig.locationType = configuration.locationType
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            guard success, error == nil else {
                DispatchQueue.main.async {
                    completion(false, error)
                }
                return
            }
            
            // 启动 watch app
            self?.healthStore.startWatchApp(with: workoutConfig) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("Successfully started watch workout")
                    } else {
                        print("Failed to start watch workout: \(error?.localizedDescription ?? "Unknown error")")
                    }
                    completion(success, error)
                }
            }
        }
    }
    
    /// 停止 watch workout（通过 WatchConnectivity 发送消息）
    func stopWatchWorkout() {
        // 实际停止操作由 watch 端处理
        // 这里只是通知，真正的停止在 watch 端完成
        print("Requesting watch to stop workout")
    }
}
#endif

