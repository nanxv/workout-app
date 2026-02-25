//
//  Routine.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import SwiftData

@Model
final class Routine {
    @Attribute(.unique) var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var exercises: [RoutineExercise]?
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        self.exercises = []
    }
}

