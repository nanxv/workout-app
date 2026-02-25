//
//  FloatingWorkoutBall.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Refactored based on ChatGPT design recommendations (2026/01/03)
//

import SwiftUI

/// 悬浮训练球组件（可拖拽，显示当前训练状态）
struct FloatingWorkoutBall: View {
    @ObservedObject var state: FloatingBallState
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    let onLongPress: () -> Void
    let onDragEnd: (CGPoint, CGRect) -> CGPoint
    
    @State private var isDragging = false
    @State private var dragStartPosition: CGPoint = .zero
    @State private var isPulsing = false
    @State private var isTemporarilyHidden = false
    
    private let ballSize: CGFloat = 56
    private let ballRadius: CGFloat = 28
    private let progressLineWidth: CGFloat = 6
    
    var body: some View {
        GeometryReader { geometry in
            if state.isVisible && !isTemporarilyHidden {
                ZStack {
                    // 悬浮球主体
                    ballBody
                        .frame(width: ballSize, height: ballSize)
                        .overlay(progressOverlay)
                        .contentShape(Circle())
                        .padding(8) // 扩大命中区域
                        .shadow(color: .black.opacity(state.isResting ? 0.3 : 0.2), radius: 10, y: 2)
                        .scaleEffect(isDragging ? 1.12 : 1.0)
                        .position(currentPosition(in: geometry.frame(in: .local)))
                        .gesture(dragGesture(in: geometry.frame(in: .local)))
                        .onTapGesture(count: 2, perform: onDoubleTap)
                        .onTapGesture(perform: onSingleTap)
                        .onLongPressGesture(minimumDuration: 0.7, perform: onLongPress)
                        .accessibilityLabel(state.isResting ? "休息中" : "训练控制")
                        .accessibilityHint("点按展开控制面板，双击暂停或开始休息")
                        .onAppear {
                            state.restorePosition(in: geometry.frame(in: .local))
                            if state.isResting {
                                startPulse()
                            }
                        }
                        .onChange(of: state.isResting) { _, newValue in
                            if newValue {
                                startPulse()
                            }
                        }
                        .contextMenu {
                            if state.isResting {
                                Button(state.isPaused ? "继续休息" : "暂停休息") {
                                    onDoubleTap()
                                }
                            } else {
                                Button("开始休息") {
                                    onDoubleTap()
                                }
                            }
                            Button("展开控制面板") {
                                onSingleTap()
                            }
                            Button("隐藏 10 秒") {
                                hideTemporarily()
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.isVisible)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    /// 悬浮球主体样式
    private var ballBody: some View {
        ZStack {
            if state.isResting {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .scaleEffect(isPulsing ? 1.25 : 0.9)
                    .opacity(isPulsing ? 0.1 : 0.35)
                    .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: isPulsing)
            }
            
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.45),
                                    Color.white.opacity(0.15),
                                    Color.black.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
            
            if state.isPaused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.8))
                    .offset(y: 12)
            }
        }
    }
    
    /// 环形进度条覆盖层
    private var progressOverlay: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(.secondary.opacity(0.25), lineWidth: progressLineWidth)
            
            // 休息进度环
            if state.isResting, state.restTotal > 0 {
                let progress = max(0, min(1, 1 - state.restRemaining / state.restTotal))
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.primary, .primary.opacity(0.6), .primary],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: progressLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        UIAccessibility.isReduceMotionEnabled ? nil : .linear(duration: 0.2),
                        value: progress
                    )
            }
            
            // 中心文字：18pt bold，确保 1 米外也清晰可读
            Text(centerText)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
        }
    }
    
    private var centerText: String {
        if state.isResting {
            return "\(Int(state.restRemaining))"
        }
        return "训"
    }
    
    /// 获取当前位置
    private func currentPosition(in frame: CGRect) -> CGPoint {
        state.position ?? CGPoint(x: frame.maxX - 40, y: frame.maxY - 140)
    }
    
    /// 拖动手势
    private func dragGesture(in frame: CGRect) -> some Gesture {
        // minimumDistance: 15 — prevents drag from stealing single/double-tap events
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartPosition = state.position ?? currentPosition(in: frame)
                    // 触觉反馈
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
                
                // 计算新位置（基于拖动开始位置 + 拖动偏移）
                let newX = dragStartPosition.x + value.translation.width
                let newY = dragStartPosition.y + value.translation.height
                
                // 限制在可视范围内（考虑安全区域）
                let safeAreaTop: CGFloat = 80
                let safeAreaBottom: CGFloat = 110
                let minX = ballRadius + 12
                let maxX = frame.width - ballRadius - 12
                let minY = ballRadius + safeAreaTop
                let maxY = frame.height - safeAreaBottom - ballRadius
                
                let clampedX = max(minX, min(maxX, newX))
                let clampedY = max(minY, min(maxY, newY))
                
                // 直接更新位置（拖动时无动画，确保即时响应）
                state.position = CGPoint(x: clampedX, y: clampedY)
            }
            .onEnded { value in
                // 计算最终位置
                let newX = dragStartPosition.x + value.translation.width
                let newY = dragStartPosition.y + value.translation.height
                
                let safeAreaTop: CGFloat = 80
                let safeAreaBottom: CGFloat = 110
                let minX = ballRadius + 12
                let maxX = frame.width - ballRadius - 12
                let minY = ballRadius + safeAreaTop
                let maxY = frame.height - safeAreaBottom - ballRadius
                
                let clampedX = max(minX, min(maxX, newX))
                let clampedY = max(minY, min(maxY, newY))
                
                // 使用吸附函数计算最终位置
                let finalPoint = onDragEnd(CGPoint(x: clampedX, y: clampedY), frame)
                
                // 重置拖动状态
                isDragging = false
                
                // 平滑动画到最终位置
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    state.position = finalPoint
                }
                
                // 保存位置
                state.persistPosition(finalPoint)
                
                // 结束触觉反馈
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
    }
    
    private func startPulse() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        isPulsing = false
        DispatchQueue.main.async {
            isPulsing = true
        }
    }

    private func hideTemporarily() {
        isTemporarilyHidden = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            isTemporarilyHidden = false
        }
    }
}

/// 吸附到边缘的辅助函数
func snapToEdges(point: CGPoint, in frame: CGRect, config: SnapConfig = .init()) -> CGPoint {
    let ballRadius: CGFloat = 28
    let leftX = config.horizontalPadding + ballRadius
    let rightX = frame.width - config.horizontalPadding - ballRadius
    let x = (point.x < frame.midX) ? leftX : rightX
    let y = min(max(point.y, frame.minY + config.topSafe + ballRadius),
                frame.maxY - config.bottomSafe - ballRadius)
    return CGPoint(x: x, y: y)
}

/// 吸附配置
struct SnapConfig {
    var horizontalPadding: CGFloat = 12
    var topSafe: CGFloat = 80
    var bottomSafe: CGFloat = 110
}

#Preview {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()
        
        FloatingWorkoutBall(
            state: {
                let state = FloatingBallState()
                state.isVisible = true
                state.isResting = true
                state.restRemaining = 45
                state.restTotal = 90
                return state
            }(),
            onSingleTap: {},
            onDoubleTap: {},
            onLongPress: {},
            onDragEnd: { point, frame in
                snapToEdges(point: point, in: frame)
            }
        )
    }
}
