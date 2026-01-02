//
//  SetEntry.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import SwiftData

@Model
final class SetEntry {
    @Attribute(.unique) var id: UUID
    var sessionExercise: SessionExercise?
    var setIndex: Int
    var reps: Int
    var rir: Int  // 0-4
    var restSecondsUsed: Int
    var tempo: String?
    var note: String?
    var timestamp: Date
    
    init(
        id: UUID = UUID(),
        sessionExercise: SessionExercise? = nil,
        setIndex: Int,
        reps: Int,
        rir: Int,
        restSecondsUsed: Int,
        tempo: String? = nil,
        note: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sessionExercise = sessionExercise
        self.setIndex = setIndex
        self.reps = reps
        self.rir = rir
        self.restSecondsUsed = restSecondsUsed
        self.tempo = tempo
        self.note = note
        self.timestamp = timestamp
    }
}

