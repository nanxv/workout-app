//
//  Session.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var routine: Routine?
    var startAt: Date
    var endAt: Date?
    var healthWorkoutUUID: UUID?
    var calendarEventId: String?
    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise]?
    
    init(
        id: UUID = UUID(),
        routine: Routine? = nil,
        startAt: Date = Date(),
        endAt: Date? = nil,
        healthWorkoutUUID: UUID? = nil,
        calendarEventId: String? = nil
    ) {
        self.id = id
        self.routine = routine
        self.startAt = startAt
        self.endAt = endAt
        self.healthWorkoutUUID = healthWorkoutUUID
        self.calendarEventId = calendarEventId
        self.exercises = []
    }
    
    var duration: TimeInterval? {
        guard let endAt = endAt else { return nil }
        return endAt.timeIntervalSince(startAt)
    }
}

