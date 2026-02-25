//
//  Silent_GymWatchApp.swift
//  Silent Gym Watch App
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI

@main
struct Silent_GymWatchApp: App {
    @StateObject private var workoutManager = WatchWorkoutManager.shared
    
    var body: some Scene {
        WindowGroup {
            WorkoutView()
                .environmentObject(workoutManager)
        }
    }
}

