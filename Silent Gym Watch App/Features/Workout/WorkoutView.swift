//
//  WorkoutView.swift
//  Silent Gym Watch App
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI

// Note: WatchWorkoutManager and WatchConnectivityManager need to be accessible
// They should be added to the watchOS target in Xcode

#if os(watchOS)
struct WorkoutView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            if workoutManager.isRunning {
                // 训练中界面
                runningView
            } else {
                // 待机界面
                idleView
            }
        }
        .onAppear {
            setupWatchConnectivity()
        }
    }
    
    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("等待训练开始")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var runningView: some View {
        VStack(spacing: 8) {
            // 时间
            Text(formatTime(workoutManager.elapsedTime))
                .font(.system(size: 32, weight: .bold))
            
            // 当前动作
            if let exerciseName = workoutManager.currentExerciseName {
                VStack(spacing: 4) {
                    Text(exerciseName)
                        .font(.headline)
                    if workoutManager.totalSets > 0 {
                        Text("Set \(workoutManager.currentSetIndex + 1)/\(workoutManager.totalSets)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 心率
            if workoutManager.heartRate > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("\(Int(workoutManager.heartRate))")
                        .font(.caption)
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func setupWatchConnectivity() {
        connectivityManager.onMessageReceived = { [weak workoutManager] message in
            guard let workoutManager = workoutManager else { return }
            
            switch message.type {
            case .startWorkout:
                if let activityType = message.activityType,
                   let hkActivityType = HKWorkoutActivityType(rawValue: activityType) {
                    workoutManager.startWorkout(activityType: hkActivityType)
                } else {
                    workoutManager.startWorkout()
                }
                
            case .stopWorkout:
                workoutManager.stopWorkout()
                
            case .updateNow:
                if let exerciseName = message.exerciseName,
                   let setIndex = message.setIndex,
                   let totalSets = message.totalSets {
                    workoutManager.updateExerciseInfo(name: exerciseName, setIndex: setIndex, totalSets: totalSets)
                }
                
            default:
                break
            }
        }
    }
}
#endif

