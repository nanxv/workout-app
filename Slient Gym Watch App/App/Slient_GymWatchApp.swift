//
//  Slient_GymWatchApp.swift
//  Slient Gym Watch App
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI

@main
struct Slient_GymWatchApp: App {
    @StateObject private var workoutManager = WatchWorkoutManager.shared
    
    var body: some Scene {
        WindowGroup {
            WorkoutView()
                .environmentObject(workoutManager)
        }
    }
}

