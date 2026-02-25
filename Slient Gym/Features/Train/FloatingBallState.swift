//
//  FloatingBallState.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/03.
//  Based on ChatGPT design recommendations
//

import Foundation
import CoreGraphics
import Combine

/// 悬浮球状态管理
@MainActor
final class FloatingBallState: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var showPanel: Bool = false
    @Published var isResting: Bool = false
    @Published var isPaused: Bool = false
    @Published var restRemaining: TimeInterval = 0
    @Published var restTotal: TimeInterval = 0
    @Published var subtitle: String? = nil
    @Published var currentExerciseName: String? = nil
    @Published var currentSetIndex: Int = 0
    @Published var totalSets: Int = 0
    @Published var nextExerciseName: String? = nil
    
    // 记忆位置（使用 UserDefaults）
    private let storage: UserDefaults
    private static let keyX = "floatingBall.pos.x"
    private static let keyY = "floatingBall.pos.y"
    @Published var position: CGPoint? = nil
    
    init(storage: UserDefaults = .standard) {
        self.storage = storage
    }
    
    /// 恢复保存的位置，如果没有则使用默认位置
    func restorePosition(in frame: CGRect) {
        position = Self.restorePosition(in: frame, storage: storage)
    }
    
    /// 保存位置
    func persistPosition(_ p: CGPoint) {
        Self.persistPosition(p, storage: storage)
    }
    
    /// 更新休息状态
    func updateRestState(isActive: Bool, remaining: TimeInterval, total: TimeInterval) {
        let result = Self.restStateUpdate(
            isActive: isActive,
            remaining: remaining,
            total: total,
            wasPaused: isPaused
        )
        isResting = result.isResting
        restRemaining = result.restRemaining
        restTotal = result.restTotal
        isPaused = result.isPaused
    }

    /// 更新暂停状态
    func updatePauseState(isPaused: Bool) {
        self.isPaused = isPaused
    }

    /// 更新当前动作摘要
    func updateSubtitle(_ text: String?) {
        subtitle = text
    }

    /// 更新当前动作信息
    func updateExerciseInfo(name: String?, setIndex: Int, totalSets: Int, nextName: String?) {
        currentExerciseName = name
        let normalized = Self.normalizedExerciseInfo(setIndex: setIndex, totalSets: totalSets)
        currentSetIndex = normalized.setIndex
        self.totalSets = normalized.totalSets
        nextExerciseName = nextName
    }

    // MARK: - Pure helpers for tests
    
    nonisolated static func restStateUpdate(
        isActive: Bool,
        remaining: TimeInterval,
        total: TimeInterval,
        wasPaused: Bool
    ) -> (isResting: Bool, restRemaining: TimeInterval, restTotal: TimeInterval, isPaused: Bool) {
        let paused = isActive ? wasPaused : false
        return (isActive, remaining, total, paused)
    }
    
    nonisolated static func normalizedExerciseInfo(setIndex: Int, totalSets: Int) -> (setIndex: Int, totalSets: Int) {
        return (max(0, setIndex), max(0, totalSets))
    }

    nonisolated static func persistPosition(_ p: CGPoint, storage: UserDefaults) {
        storage.set(p.x, forKey: keyX)
        storage.set(p.y, forKey: keyY)
    }

    nonisolated static func restorePosition(in frame: CGRect, storage: UserDefaults) -> CGPoint {
        guard let savedX = storage.object(forKey: keyX) as? Double,
              let savedY = storage.object(forKey: keyY) as? Double else {
            return CGPoint(x: frame.maxX - 40, y: frame.maxY - 140)
        }
        return CGPoint(x: savedX, y: savedY)
    }
}

