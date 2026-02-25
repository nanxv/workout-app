//
//  Slient_GymApp.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import SwiftData

@main
struct Slient_GymApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self,
            Routine.self,
            RoutineExercise.self,
            Session.self,
            SessionExercise.self,
            SetEntry.self,
            ExternalWorkout.self
        ])
        let modelConfiguration = ModelConfiguration("SlientGym", schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Final fallback: in-memory store to avoid launch crash.
            let fallback = ModelConfiguration("SlientGymInMemory", schema: schema, isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [fallback]))!
        }
    }()

    var body: some Scene {
        WindowGroup {
            // 使用新的 Wireframe 版本（基于设计稿）
            MainTabViewWireframe()
                .preferredColorScheme(.dark)
                .task {
                    // Generate sample data on first launch (async, non-blocking)
                    Task.detached(priority: .userInitiated) {
                        await MainActor.run {
                            let context = ModelContext(sharedModelContainer)
                            SampleDataGenerator.generateSampleData(context: context)
                            
                            // Verify data was created
                            let descriptor = FetchDescriptor<Routine>()
                            if let routines = try? context.fetch(descriptor) {
                                print("Sample data check: \(routines.count) routines created")
                                for routine in routines {
                                    print("  - \(routine.name)")
                                }
                            }
                        }
                    }
                    
                    // Initialize WatchConnectivity (non-blocking, already async)
                    _ = WatchConnectivityManager.shared
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

