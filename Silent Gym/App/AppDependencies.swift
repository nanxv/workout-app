//
//  AppDependencies.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/02/25.
//

import Foundation
import Combine
import SwiftData

/// Central dependency injection container.
/// Created once in `Silent_GymApp` and propagated via `@EnvironmentObject`.
/// Views should access services through this container rather than through singletons.
@MainActor
final class AppDependencies: ObservableObject {

    /// Single shared coordinator — Train, Coach and Heatmap all observe the same session.
    let sessionCoordinator: SessionCoordinator

    let watchConnectivity: WatchConnectivityManager

    /// Home Gym equipment inventory and substitution engine.
    let equipmentManager: EquipmentManager

    /// Live muscle heatmap state — driven by the shared coordinator.
    let heatmapViewModel: MuscleHeatmapViewModel

    #if os(iOS)
    let healthImport: HealthImportManager
    #endif

    init() {
        let context = ModelContext(PersistenceController.shared.container)
        let em = EquipmentManager.shared
        let coord = SessionCoordinator(modelContext: context, equipmentManager: em)

        self.sessionCoordinator = coord
        self.equipmentManager   = em
        self.watchConnectivity  = WatchConnectivityManager.shared
        self.heatmapViewModel   = MuscleHeatmapViewModel(coordinator: coord)

        #if os(iOS)
        self.healthImport = HealthImportManager.shared
        #endif
    }
}
