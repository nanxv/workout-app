//
//  RoutineExercise.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import SwiftData

@Model
final class RoutineExercise {
    @Attribute(.unique) var id: UUID
    var routine: Routine?
    var exercise: Exercise?
    var order: Int
    var targetSets: Int
    var restSecondsDefault: Int
    var tempoDefault: String?
    var repTargetLow: Int?
    var repTargetHigh: Int?
    
    /// 计算属性：返回目标次数（如果有范围则返回平均值）
    var repTarget: Int? {
        if let low = repTargetLow, let high = repTargetHigh {
            return (low + high) / 2
        } else if let low = repTargetLow {
            return low
        } else if let high = repTargetHigh {
            return high
        }
        return nil
    }
    
    init(
        id: UUID = UUID(),
        routine: Routine? = nil,
        exercise: Exercise? = nil,
        order: Int,
        targetSets: Int,
        restSecondsDefault: Int,
        tempoDefault: String? = nil,
        repTargetLow: Int? = nil,
        repTargetHigh: Int? = nil
    ) {
        self.id = id
        self.routine = routine
        self.exercise = exercise
        self.order = order
        self.targetSets = targetSets
        self.restSecondsDefault = restSecondsDefault
        self.tempoDefault = tempoDefault
        self.repTargetLow = repTargetLow
        self.repTargetHigh = repTargetHigh
    }
}

