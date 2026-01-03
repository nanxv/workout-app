//
//  FloatingWorkoutBall.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Based on Wireframe v1.8.3
//

import SwiftUI

/// 悬浮训练球组件（可拖拽，显示当前训练状态）
struct FloatingWorkoutBall: View {
    let title: String
    let subtitle: String?
    let restSeconds: Int
    let onToggle: () -> Void
    let onStartRest: () -> Void
    let onAddRest: () -> Void
    let onEnd: () -> Void
    
    @State private var isExpanded = false
    @State private var position: CGPoint
    @State private var isDragging = false
    
    @AppStorage("floatingBallPositionX") private var savedX: Double = 0
    @AppStorage("floatingBallPositionY") private var savedY: Double = 0
    
    private let ballSize: CGFloat = 64
    private let ballRadius: CGFloat = 32
    
    init(
        title: String,
        subtitle: String? = nil,
        restSeconds: Int = 0,
        onToggle: @escaping () -> Void,
        onStartRest: @escaping () -> Void,
        onAddRest: @escaping () -> Void,
        onEnd: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.restSeconds = restSeconds
        self.onToggle = onToggle
        self.onStartRest = onStartRest
        self.onAddRest = onAddRest
        self.onEnd = onEnd
        
        // 从 UserDefaults 恢复位置，默认右下角
        let defaultX: CGFloat = 350
        let defaultY: CGFloat = 600
        let x = savedX > 0 ? savedX : Double(defaultX)
        let y = savedY > 0 ? savedY : Double(defaultY)
        _position = State(initialValue: CGPoint(x: x, y: y))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 悬浮球
                Button(action: {
                    isExpanded.toggle()
                    onToggle()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: ballSize, height: ballSize)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        // 白色边框
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: ballSize, height: ballSize)
                        
                        // 内容：显示倒计时或"训"
                        Text(restSeconds > 0 ? "\(restSeconds)s" : "训")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .position(position)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                            }
                            
                            // 计算新位置
                            let newX = position.x + value.translation.width
                            let newY = position.y + value.translation.height
                            
                            // 限制在可视范围内
                            let clampedX = max(ballRadius + 8, min(geometry.size.width - ballRadius - 8, newX))
                            let clampedY = max(ballRadius + 59 + 8, min(geometry.size.height - 120 - ballRadius - 8, newY))
                            
                            position = CGPoint(x: clampedX, y: clampedY)
                        }
                        .onEnded { _ in
                            isDragging = false
                            
                            // 贴边吸附
                            let centerX = geometry.size.width / 2
                            let snapX = position.x < centerX ? (ballRadius + 8) : (geometry.size.width - ballRadius - 8)
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                position = CGPoint(x: snapX, y: position.y)
                            }
                            
                            // 保存位置
                            savedX = position.x
                            savedY = position.y
                        }
                )
                
                // 展开的操作面板（气泡）
                if isExpanded {
                    let panelToLeft = position.x > (geometry.size.width / 2)
                    
                    VStack(alignment: panelToLeft ? .trailing : .leading, spacing: 8) {
                        VStack(alignment: panelToLeft ? .trailing : .leading, spacing: 4) {
                            Text(title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            if let subtitle = subtitle {
                                Text(subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                onStartRest()
                                isExpanded = false
                            }) {
                                Text("开始休息")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                onAddRest()
                            }) {
                                Text("+30 秒")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                onEnd()
                                isExpanded = false
                            }) {
                                Text("结束")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .frame(minWidth: 220)
                    .position(
                        x: panelToLeft ? (position.x - 40 - 110) : (position.x + 40 + 110),
                        y: position.y - 80
                    )
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()
        
        FloatingWorkoutBall(
            title: "当前训练 · Day A",
            subtitle: "俯卧撑 · 4组 × 12 · 休 90s",
            restSeconds: 45,
            onToggle: {},
            onStartRest: {},
            onAddRest: {},
            onEnd: {}
        )
    }
}

