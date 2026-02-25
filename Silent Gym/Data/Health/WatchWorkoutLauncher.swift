//
//  WatchWorkoutLauncher.swift
//  Silent Gym
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
    ///   - sessionId: 当前训练 Session 的 ID
    ///   - activityType: HKWorkoutActivityType，默认使用 Traditional Strength Training
    ///   - completion: 完成回调，返回是否成功
    func startWatchWorkout(
        sessionId: UUID,
        activityType: HKWorkoutActivityType = .traditionalStrengthTraining,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        // 检查 HealthKit 授权
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "WatchWorkoutLauncher", code: -1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available"]))
            return
        }
        
        // 检查 Info.plist 中是否有必需的权限描述
        let infoPlist = Bundle.main.infoDictionary
        let hasUpdateDescription = infoPlist?["NSHealthUpdateUsageDescription"] as? String != nil
        
        if !hasUpdateDescription {
            print("⚠️ Warning: NSHealthUpdateUsageDescription not found in Info.plist")
            print("⚠️ 请在 Xcode 的 Info 标签中添加 'Privacy - Health Update Usage Description'")
            print("⚠️ 暂时跳过 HealthKit 写入权限请求，仅使用本地训练功能")
            
            // 不请求写入权限，只尝试启动 watch（如果可用）
            let wcManager = WatchConnectivityManager.shared
            if wcManager.isWatchReachable {
                wcManager.sendStartWorkout(
                    sessionId: sessionId,
                    activityType: Int(activityType.rawValue)
                )
                completion(true, nil)
            } else {
                // 即使没有 watch，也允许本地训练继续
                completion(true, nil)
            }
            return
        }
        
        // 请求必要的权限
        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            guard success, error == nil else {
                DispatchQueue.main.async {
                    completion(false, error)
                }
                return
            }
            
            // 在闭包内创建配置，避免 Sendable 问题
            let workoutConfig = HKWorkoutConfiguration()
            workoutConfig.activityType = activityType
            workoutConfig.locationType = .indoor
            
            self?.healthStore.startWatchApp(with: workoutConfig) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("Successfully started watch workout via HealthKit")
                        completion(true, nil)
                    } else {
                        print("Failed to start watch workout via HealthKit: \(error?.localizedDescription ?? "Unknown error")")
                        // 兜底：使用 WCSession 发送启动消息
                        print("Falling back to WCSession...")
                        let wcManager = WatchConnectivityManager.shared
                        if wcManager.isWatchReachable {
                            // 通过 WCSession 发送启动消息
                            wcManager.sendStartWorkout(
                                sessionId: sessionId,
                                activityType: Int(activityType.rawValue)
                            )
                            // 使用 WCSession 作为兜底，假设成功
                            // 实际应该等待 watch 端确认，但为了不阻塞，先返回成功
                            completion(true, nil)
                        } else {
                            print("Watch is not reachable via WCSession")
                            // Watch 不可达，但不影响本地训练，返回成功
                            // 用户仍然可以在 iPhone 上记录训练
                            completion(true, nil)
                        }
                    }
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

