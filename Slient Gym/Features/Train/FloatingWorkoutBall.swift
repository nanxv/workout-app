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
    @State private var position: CGPoint = CGPoint(x: 350, y: 600) // 默认位置
    @State private var isDragging = false
    @State private var dragStartPosition: CGPoint = .zero
    
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
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 悬浮球
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: ballSize, height: ballSize)
                        .shadow(
                            color: .black.opacity(isDragging ? 0.5 : 0.3),
                            radius: isDragging ? 12 : 8,
                            x: 0,
                            y: isDragging ? 6 : 4
                        )
                    
                    // 白色边框
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: ballSize, height: ballSize)
                    
                    // 内容：显示倒计时或"训"
                    Text(restSeconds > 0 ? "\(restSeconds)s" : "训")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .scaleEffect(isDragging ? 1.15 : 1.0)
                .position(position)
                .animation(isDragging ? nil : .spring(response: 0.4, dampingFraction: 0.75), value: position)
                .onAppear {
                    // 恢复保存的位置
                    if savedX > 0 && savedY > 0 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            position = CGPoint(x: savedX, y: savedY)
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStartPosition = position
                                // 触觉反馈
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                            
                            // 计算新位置（基于拖动开始位置 + 拖动偏移）
                            let newX = dragStartPosition.x + value.translation.width
                            let newY = dragStartPosition.y + value.translation.height
                            
                            // 限制在可视范围内（考虑安全区域）
                            let safeAreaTop: CGFloat = 59
                            let safeAreaBottom: CGFloat = 120
                            let minX = ballRadius + 8
                            let maxX = geometry.size.width - ballRadius - 8
                            let minY = ballRadius + safeAreaTop + 8
                            let maxY = geometry.size.height - safeAreaBottom - ballRadius - 8
                            
                            let clampedX = max(minX, min(maxX, newX))
                            let clampedY = max(minY, min(maxY, newY))
                            
                            // 直接更新位置（拖动时无动画，确保即时响应）
                            position = CGPoint(x: clampedX, y: clampedY)
                        }
                        .onEnded { value in
                            // 计算最终位置
                            let newX = dragStartPosition.x + value.translation.width
                            let newY = dragStartPosition.y + value.translation.height
                            
                            let safeAreaTop: CGFloat = 59
                            let safeAreaBottom: CGFloat = 120
                            let minX = ballRadius + 8
                            let maxX = geometry.size.width - ballRadius - 8
                            let minY = ballRadius + safeAreaTop + 8
                            let maxY = geometry.size.height - safeAreaBottom - ballRadius - 8
                            
                            let clampedX = max(minX, min(maxX, newX))
                            let clampedY = max(minY, min(maxY, newY))
                            
                            // 四个角的位置
                            let topLeft = CGPoint(x: minX, y: minY)
                            let topRight = CGPoint(x: maxX, y: minY)
                            let bottomLeft = CGPoint(x: minX, y: maxY)
                            let bottomRight = CGPoint(x: maxX, y: maxY)
                            
                            // 计算到四个角的距离
                            let distanceToTopLeft = sqrt(pow(clampedX - topLeft.x, 2) + pow(clampedY - topLeft.y, 2))
                            let distanceToTopRight = sqrt(pow(clampedX - topRight.x, 2) + pow(clampedY - topRight.y, 2))
                            let distanceToBottomLeft = sqrt(pow(clampedX - bottomLeft.x, 2) + pow(clampedY - bottomLeft.y, 2))
                            let distanceToBottomRight = sqrt(pow(clampedX - bottomRight.x, 2) + pow(clampedY - bottomRight.y, 2))
                            
                            // 计算到四个边缘的距离
                            let distanceToLeft = clampedX - minX
                            let distanceToRight = maxX - clampedX
                            let distanceToTop = clampedY - minY
                            let distanceToBottom = maxY - clampedY
                            
                            // 找到最近的角和边缘
                            let cornerDistances = [
                                ("topLeft", distanceToTopLeft),
                                ("topRight", distanceToTopRight),
                                ("bottomLeft", distanceToBottomLeft),
                                ("bottomRight", distanceToBottomRight)
                            ]
                            
                            let edgeDistances = [
                                ("left", distanceToLeft),
                                ("right", distanceToRight),
                                ("top", distanceToTop),
                                ("bottom", distanceToBottom)
                            ]
                            
                            let minCornerDistance = cornerDistances.min(by: { $0.1 < $1.1 })?.1 ?? .infinity
                            let minEdgeDistance = edgeDistances.min(by: { $0.1 < $1.1 })?.1 ?? .infinity
                            
                            var finalX = clampedX
                            var finalY = clampedY
                            
                            // 优先吸附到角（如果距离角很近，小于 60 点）
                            if minCornerDistance < 60 {
                                let nearestCorner = cornerDistances.min(by: { $0.1 < $1.1 })?.0 ?? ""
                                switch nearestCorner {
                                case "topLeft":
                                    finalX = topLeft.x
                                    finalY = topLeft.y
                                case "topRight":
                                    finalX = topRight.x
                                    finalY = topRight.y
                                case "bottomLeft":
                                    finalX = bottomLeft.x
                                    finalY = bottomLeft.y
                                case "bottomRight":
                                    finalX = bottomRight.x
                                    finalY = bottomRight.y
                                default:
                                    break
                                }
                            } else if minEdgeDistance < 50 {
                                // 如果距离边缘很近（小于 50 点），则吸附到该边缘
                                let nearestEdge = edgeDistances.min(by: { $0.1 < $1.1 })?.0 ?? ""
                                switch nearestEdge {
                                case "left":
                                    finalX = minX
                                case "right":
                                    finalX = maxX
                                case "top":
                                    finalY = minY
                                case "bottom":
                                    finalY = maxY
                                default:
                                    break
                                }
                            } else {
                                // 否则，水平方向贴到左右边缘
                                let centerX = geometry.size.width / 2
                                finalX = clampedX < centerX ? minX : maxX
                            }
                            
                            // 重置拖动状态
                            isDragging = false
                            
                            // 平滑动画到最终位置
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                position = CGPoint(x: finalX, y: finalY)
                            }
                            
                            // 保存位置
                            savedX = finalX
                            savedY = finalY
                            
                            // 结束触觉反馈
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                )
                .onTapGesture {
                    // 只有未拖动时才响应点击
                    if !isDragging {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                        onToggle()
                    }
                }
                
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
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isExpanded = false
                                }
                                onStartRest()
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
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isExpanded = false
                                }
                                onEnd()
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
                            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    )
                    .frame(minWidth: 220)
                    .position(
                        x: panelToLeft ? (position.x - 40 - 110) : (position.x + 40 + 110),
                        y: position.y - 80
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isExpanded)
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

