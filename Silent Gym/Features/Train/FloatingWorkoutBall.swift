//
//  FloatingWorkoutBall.swift
//  Silent Gym
//
//  Refactored Phase 2: spring physics, richer haptics, rest-end pulse.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - FloatingWorkoutBall

/// Draggable floating ball that shows live training / rest state.
struct FloatingWorkoutBall: View {
    @ObservedObject var state: FloatingBallState
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    let onLongPress: () -> Void
    let onDragEnd: (CGPoint, CGRect) -> CGPoint

    @State private var isDragging = false
    @State private var dragAnchor: CGPoint = .zero
    @State private var isPulsing = false
    @State private var isTemporarilyHidden = false
    @State private var restEndFlash = false   // brief flash when rest ends

    private let ballSize: CGFloat = 56
    private let ballRadius: CGFloat = 28
    private let ringWidth: CGFloat = 5.5

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            if state.isVisible && !isTemporarilyHidden {
                ballBody(in: geometry.frame(in: .local))
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.4).combined(with: .opacity),
                            removal: .scale(scale: 0.4).combined(with: .opacity)
                        )
                    )
                    .animation(
                        .spring(response: 0.38, dampingFraction: 0.72),
                        value: state.isVisible
                    )
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Ball construction

    @ViewBuilder
    private func ballBody(in frame: CGRect) -> some View {
        ZStack {
            // Pulse ring behind ball (rest mode only)
            if state.isResting {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentColor.opacity(0.35), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: ballRadius * 2
                        )
                    )
                    .frame(width: ballSize * 2, height: ballSize * 2)
                    .scaleEffect(isPulsing ? 1.3 : 0.85)
                    .opacity(isPulsing ? 0 : 0.6)
                    .animation(
                        UIAccessibility.isReduceMotionEnabled
                            ? nil
                            : .easeOut(duration: 1.3).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
                    .position(currentPosition(in: frame))
                    .allowsHitTesting(false)
            }

            // Rest-end flash ring
            if restEndFlash {
                Circle()
                    .stroke(Color.green.opacity(0.8), lineWidth: 4)
                    .frame(width: ballSize + 18, height: ballSize + 18)
                    .scaleEffect(restEndFlash ? 1.6 : 1.0)
                    .opacity(restEndFlash ? 0 : 1)
                    .animation(.easeOut(duration: 0.55), value: restEndFlash)
                    .position(currentPosition(in: frame))
                    .allowsHitTesting(false)
            }

            // Main ball
            shellView
                .frame(width: ballSize, height: ballSize)
                .overlay(progressRing)
                .contentShape(Circle())
                .padding(8)
                .shadow(
                    color: .black.opacity(state.isResting ? 0.32 : 0.2),
                    radius: isDragging ? 18 : 10,
                    y: isDragging ? 6 : 2
                )
                .scaleEffect(isDragging ? 1.14 : (restEndFlash ? 1.08 : 1.0))
                .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isDragging)
                .animation(.easeInOut(duration: 0.2), value: restEndFlash)
                .position(currentPosition(in: frame))
                .gesture(dragGesture(in: frame))
                .onTapGesture(count: 2, perform: onDoubleTap)
                .onTapGesture(perform: onSingleTap)
                .onLongPressGesture(minimumDuration: 0.7, perform: onLongPress)
                .accessibilityLabel(state.isResting ? "休息中" : "训练控制")
                .accessibilityHint("点按展开控制面板，双击暂停或开始休息")
                .contextMenu {
                    if state.isResting {
                        Button(state.isPaused ? "继续休息" : "暂停休息") { onDoubleTap() }
                    } else {
                        Button("开始休息") { onDoubleTap() }
                    }
                    Button("展开控制面板") { onSingleTap() }
                    Button("隐藏 10 秒") { hideTemporarily() }
                }
                .onAppear {
                    state.restorePosition(in: frame)
                    if state.isResting { triggerPulse() }
                }
                .onChange(of: state.isResting) { _, isResting in
                    if isResting { triggerPulse() } else { isPulsing = false }
                }
                .onChange(of: Int(state.restRemaining)) { oldVal, newVal in
                    guard oldVal > 0 && newVal <= 0 && state.isResting else { return }
                    triggerRestEndFeedback()
                }
        }
    }

    // MARK: - Shell (glass ball)

    private var shellView: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.50),
                                    .white.opacity(0.18),
                                    .black.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )

            // Pause indicator
            if state.isPaused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.75))
                    .offset(y: 11)
            }
        }
    }

    // MARK: - Progress ring + center text

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.22), lineWidth: ringWidth)

            if state.isResting, state.restTotal > 0 {
                let progress = max(0, min(1, 1.0 - state.restRemaining / state.restTotal))
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.primary, .primary.opacity(0.55), .primary],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        UIAccessibility.isReduceMotionEnabled ? nil : .linear(duration: 0.18),
                        value: progress
                    )
            }

            Text(centerLabel)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: centerLabel)
        }
    }

    private var centerLabel: String {
        if state.isResting {
            return "\(max(0, Int(state.restRemaining)))"
        }
        if state.totalSets > 0 {
            return "\(state.currentSetIndex)/\(state.totalSets)"
        }
        return "训"
    }

    // MARK: - Position

    private func currentPosition(in frame: CGRect) -> CGPoint {
        state.position ?? CGPoint(x: frame.maxX - 40, y: frame.maxY - 140)
    }

    // MARK: - Drag gesture

    private func dragGesture(in frame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragAnchor = state.position ?? currentPosition(in: frame)
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    #endif
                }
                let raw = CGPoint(
                    x: dragAnchor.x + value.translation.width,
                    y: dragAnchor.y + value.translation.height
                )
                state.position = clamped(raw, in: frame)
            }
            .onEnded { value in
                let raw = CGPoint(
                    x: dragAnchor.x + value.translation.width,
                    y: dragAnchor.y + value.translation.height
                )
                let snapped = onDragEnd(clamped(raw, in: frame), frame)
                isDragging = false
                withAnimation(.spring(response: 0.32, dampingFraction: 0.60)) {
                    state.position = snapped
                }
                state.persistPosition(snapped)
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                #endif
            }
    }

    private func clamped(_ point: CGPoint, in frame: CGRect) -> CGPoint {
        let topSafe: CGFloat = 80, bottomSafe: CGFloat = 110, hPad: CGFloat = 12
        return CGPoint(
            x: max(ballRadius + hPad, min(frame.width - ballRadius - hPad, point.x)),
            y: max(ballRadius + topSafe, min(frame.height - bottomSafe - ballRadius, point.y))
        )
    }

    // MARK: - Effects

    private func triggerPulse() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        isPulsing = false
        DispatchQueue.main.async { isPulsing = true }
    }

    private func triggerRestEndFeedback() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        withAnimation { restEndFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation { restEndFlash = false }
        }
    }

    private func hideTemporarily() {
        isTemporarilyHidden = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            withAnimation { isTemporarilyHidden = false }
        }
    }
}

// MARK: - snapToEdges (global helper, used by tests too)

/// Snaps a point to the nearest left/right screen edge with safe-area insets.
func snapToEdges(point: CGPoint, in frame: CGRect, config: SnapConfig = .init()) -> CGPoint {
    let r: CGFloat = 28
    let x = point.x < frame.midX
        ? config.horizontalPadding + r
        : frame.width - config.horizontalPadding - r
    let y = min(
        max(point.y, frame.minY + config.topSafe + r),
        frame.maxY - config.bottomSafe - r
    )
    return CGPoint(x: x, y: y)
}

struct SnapConfig {
    var horizontalPadding: CGFloat = 12
    var topSafe: CGFloat = 80
    var bottomSafe: CGFloat = 110
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.95)
            .ignoresSafeArea()
        FloatingWorkoutBall(
            state: {
                let s = FloatingBallState()
                s.isVisible = true
                s.isResting = true
                s.restRemaining = 43
                s.restTotal = 90
                s.currentSetIndex = 2
                s.totalSets = 4
                return s
            }(),
            onSingleTap: {},
            onDoubleTap: {},
            onLongPress: {},
            onDragEnd: { pt, fr in snapToEdges(point: pt, in: fr) }
        )
    }
}
