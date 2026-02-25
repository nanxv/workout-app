//
//  Exercise.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var tags: [String]
    /// Equipment names required to perform this exercise.
    /// Empty list means the exercise is bodyweight / always available.
    var equipmentRequirements: [String]

    init(
        id: UUID = UUID(),
        name: String,
        tags: [String] = [],
        equipmentRequirements: [String] = []
    ) {
        self.id = id
        self.name = name
        self.tags = tags
        self.equipmentRequirements = equipmentRequirements
    }
}

