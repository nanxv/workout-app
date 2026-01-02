//
//  WatchWorkoutManager.swift
//  Slient Gym Watch App
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import HealthKit
import WatchKit

// Note: WatchMessage and WatchConnectivityManager need to be accessible
// They should be added to the watchOS target in Xcode

#if os(watchOS)
@MainActor
class WatchWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutManager()
    
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    @Published var isRunning = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var currentExerciseName: String?
    @Published var currentSetIndex: Int = 0
    @Published var totalSets: Int = 0
    
    private var startDate: Date?
    private var timer: Timer?
    
    var onWorkoutSaved: ((UUID) -> Void)?
    
    override init() {
        super.init()
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    func startWorkout(activityType: HKWorkoutActivityType = .traditionalStrengthTraining) {
        guard !isRunning else { return }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            
            session?.delegate = self
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            let startDate = Date()
            self.startDate = startDate
            session?.startActivity(with: startDate)
            builder?.beginCollection(withStart: startDate) { success, error in
                if let error = error {
                    print("Error beginning collection: \(error.localizedDescription)")
                }
            }
            
            isRunning = true
            startTimer()
            
            // 更新 UI
            WKInterfaceDevice.current().play(.start)
        } catch {
            print("Error starting workout: \(error.localizedDescription)")
        }
    }
    
    func stopWorkout() {
        guard isRunning else { return }
        
        session?.end()
        builder?.endCollection(withEnd: Date()) { success, error in
            if let error = error {
                print("Error ending collection: \(error.localizedDescription)")
            }
        }
        
        builder?.finishWorkout { [weak self] workout, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error finishing workout: \(error.localizedDescription)")
                return
            }
            
            guard let workout = workout else { return }
            
            // 保存到 Health
            self.healthStore.save(workout) { success, error in
                if let error = error {
                    print("Error saving workout: \(error.localizedDescription)")
                    return
                }
                
                // 通知 iOS 端
                let message = WatchMessage(
                    type: .workoutSaved,
                    sessionId: nil,
                    healthWorkoutUUID: workout.uuid
                )
                WatchConnectivityManager.shared.sendMessage(message)
                
                self.onWorkoutSaved?(workout.uuid)
            }
        }
        
        stopTimer()
        isRunning = false
        
        // 更新 UI
        WKInterfaceDevice.current().play(.stop)
    }
    
    func updateExerciseInfo(name: String, setIndex: Int, totalSets: Int) {
        currentExerciseName = name
        self.currentSetIndex = setIndex
        self.totalSets = totalSets
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startDate = self.startDate else { return }
            self.elapsedTime = Date().timeIntervalSince(startDate)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMetrics() {
        guard let builder = builder else { return }
        
        // 获取心率
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        if let statistics = builder.statistics(for: heartRateType),
           let mostRecentSample = statistics.mostRecentQuantity() {
            heartRate = mostRecentSample.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
        }
        
        // 获取活动能量
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        if let statistics = builder.statistics(for: energyType),
           let sum = statistics.sumQuantity() {
            activeEnergy = sum.doubleValue(for: HKUnit.kilocalorie())
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("Workout session state changed: \(fromState) -> \(toState)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
        stopWorkout()
    }
}
#endif

