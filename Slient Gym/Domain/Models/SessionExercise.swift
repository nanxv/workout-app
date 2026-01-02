//
//  SessionExercise.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import SwiftData

@Model
final class SessionExercise {
    @Attribute(.unique) var id: UUID
    var session: Session?
    var exercise: Exercise?
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
    var sets: [SetEntry]?
    
    init(
        id: UUID = UUID(),
        session: Session? = nil,
        exercise: Exercise? = nil,
        order: Int,
        sets: [SetEntry] = []
    ) {
        self.id = id
        self.session = session
        self.exercise = exercise
        self.order = order
        self.sets = sets
    }
}

