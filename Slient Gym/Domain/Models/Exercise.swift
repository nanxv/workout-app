//
//  Exercise.swift
//  Slient Gym
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
    
    init(id: UUID = UUID(), name: String, tags: [String] = []) {
        self.id = id
        self.name = name
        self.tags = tags
    }
}

