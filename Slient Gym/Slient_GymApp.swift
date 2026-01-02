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
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    // Generate sample data on first launch
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
                    
                    // Initialize WatchConnectivity
                    _ = WatchConnectivityManager.shared
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
