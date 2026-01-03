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
    
    // Wireframe 扩展：支持时长和重量
    var holdSecDefault: Int?  // 计时动作的默认时长（秒）
    var weightKgDefault: Double?  // 默认重量（公斤）
    
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
    
    /// 判断是否为计时动作（holdSec 优先于 reps）
    var isHoldType: Bool {
        return holdSecDefault != nil && repTarget == nil
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
        repTargetHigh: Int? = nil,
        holdSecDefault: Int? = nil,
        weightKgDefault: Double? = nil
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
        self.holdSecDefault = holdSecDefault
        self.weightKgDefault = weightKgDefault
    }
}

