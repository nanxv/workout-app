//
//  SetEntry.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import SwiftData
import Combine

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
    
    // Wireframe 扩展：支持时长和重量
    var holdSec: Int?  // 计时动作的时长（秒）
    var weightKg: Double?  // 重量（公斤）
    var isCompleted: Bool  // 是否完成（用于勾选）
    
    init(
        id: UUID = UUID(),
        sessionExercise: SessionExercise? = nil,
        setIndex: Int,
        reps: Int = 0,
        rir: Int = 0,
        restSecondsUsed: Int = 0,
        tempo: String? = nil,
        note: String? = nil,
        timestamp: Date = Date(),
        holdSec: Int? = nil,
        weightKg: Double? = nil,
        isCompleted: Bool = false
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
        self.holdSec = holdSec
        self.weightKg = weightKg
        self.isCompleted = isCompleted
    }
}

