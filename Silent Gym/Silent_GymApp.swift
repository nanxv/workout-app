//
//  Silent_GymApp.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import SwiftData

@main
struct Silent_GymApp: App {

    // MARK: - DI Container

    /// Single source of truth for all core services.
    /// Propagated to the view hierarchy via `.environmentObject(dependencies)`.
    @StateObject private var dependencies = AppDependencies()

    // MARK: - Persistence

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
        let config = ModelConfiguration("SilentGym", schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let fallback = ModelConfiguration("SilentGymInMemory", schema: schema, isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [fallback]))!
        }
    }()

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            contentView
                .preferredColorScheme(.dark)
                .task {
                    let container = sharedModelContainer
                    Task.detached(priority: .userInitiated) {
                        await MainActor.run {
                            let context = ModelContext(container)
                            SampleDataGenerator.generateSampleData(context: context)
                            let descriptor = FetchDescriptor<Routine>()
                            if let routines = try? context.fetch(descriptor) {
                                print("Bootstrap: \(routines.count) routines ready")
                            }
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Private

    @ViewBuilder
    private var contentView: some View {
        #if os(iOS)
        MainTabViewWireframe()
            .environmentObject(dependencies)
            .environmentObject(dependencies.sessionCoordinator)
            .environmentObject(dependencies.watchConnectivity)
            .environmentObject(dependencies.healthImport)
        #else
        MainTabViewWireframe()
            .environmentObject(dependencies)
            .environmentObject(dependencies.sessionCoordinator)
            .environmentObject(dependencies.watchConnectivity)
        #endif
    }
}
