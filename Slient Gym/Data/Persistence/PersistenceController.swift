//
//  PersistenceController.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import SwiftData

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: ModelContainer
    
    init() {
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
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            let fallback = ModelConfiguration("SlientGymInMemory", schema: schema, isStoredInMemoryOnly: true)
            container = (try? ModelContainer(for: schema, configurations: [fallback]))!
        }
    }
}

