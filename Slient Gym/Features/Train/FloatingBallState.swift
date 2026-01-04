//
//  FloatingBallState.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/03.
//  Based on ChatGPT design recommendations
//

import SwiftUI
import Combine

/// 悬浮球状态管理
final class FloatingBallState: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var showPanel: Bool = false
    @Published var isResting: Bool = false
    @Published var restRemaining: TimeInterval = 0
    @Published var restTotal: TimeInterval = 0
    
    // 记忆位置（使用 AppStorage）
    @AppStorage("floatingBall.pos.x") private var savedX: Double = .nan
    @AppStorage("floatingBall.pos.y") private var savedY: Double = .nan
    @Published var position: CGPoint? = nil
    
    /// 恢复保存的位置，如果没有则使用默认位置
    func restorePosition(in frame: CGRect) {
        guard !savedX.isNaN, !savedY.isNaN else {
            // 默认：右下角上方一点，不遮挡 TabBar
            position = CGPoint(x: frame.maxX - 40, y: frame.maxY - 140)
            return
        }
        position = CGPoint(x: savedX, y: savedY)
    }
    
    /// 保存位置
    func persistPosition(_ p: CGPoint) {
        savedX = p.x
        savedY = p.y
    }
    
    /// 更新休息状态
    func updateRestState(isActive: Bool, remaining: TimeInterval, total: TimeInterval) {
        isResting = isActive
        restRemaining = remaining
        restTotal = total
    }
}

