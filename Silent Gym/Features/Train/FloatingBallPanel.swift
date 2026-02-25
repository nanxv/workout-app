//
//  FloatingBallPanel.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/03.
//  Based on ChatGPT design recommendations
//

import SwiftUI

/// 悬浮球底部迷你面板
struct FloatingBallPanel: View {
    @ObservedObject var state: FloatingBallState
    @Binding var quickReps: String
    @Binding var quickRIR: Int
    let onPlus15: () -> Void
    let onTogglePause: () -> Void
    let onSkip: () -> Void
    let onStartRest: () -> Void
    let onCompleteSet: () -> Void
    let onEnd: () -> Void
    
    var body: some View {
        VStack(spacing: 14) {
            // 顶部拖拽指示器
            Capsule()
                .fill(.secondary.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(state.isResting ? "休息中" : "训练进行中")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let subtitle = state.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)

            exerciseInfoCard
            
            if !state.isResting {
                quickRecordCard
            }
            
            if state.isResting {
                SwiftUI.ProgressView(value: restProgress)
                    .tint(.primary)
                    .scaleEffect(x: 1, y: 1.2, anchor: .center)
                    .padding(.horizontal, 4)
                
                HStack(spacing: 10) {
                    ActionButton(
                        title: "+15s",
                        systemImage: "plus.circle.fill",
                        style: .emphasis,
                        action: onPlus15
                    )
                    
                    ActionButton(
                        title: state.isPaused ? "继续" : "暂停",
                        systemImage: state.isPaused ? "play.fill" : "pause.fill",
                        style: .neutral,
                        action: onTogglePause
                    )
                    
                    ActionButton(
                        title: "跳过",
                        systemImage: "forward.end.fill",
                        style: .secondary,
                        action: onSkip
                    )
                }
            } else {
                HStack(spacing: 10) {
                    ActionButton(
                        title: "开始休息",
                        systemImage: "timer",
                        style: .neutral,
                        action: onStartRest
                    )
                }
            }
            
            ActionButton(
                title: "结束训练",
                systemImage: "xmark.circle.fill",
                style: .danger,
                action: {
                    onEnd()
                    state.showPanel = false
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14 + safeBottom)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var safeBottom: CGFloat {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.bottom
        }
        #endif
        return 0
    }
    
    private var restProgress: Double {
        guard state.restTotal > 0 else { return 0 }
        return max(0, min(1, 1 - state.restRemaining / state.restTotal))
    }

    private var exerciseProgress: Double {
        guard state.totalSets > 0 else { return 0 }
        let completedSets = max(0, min(state.currentSetIndex, state.totalSets))
        return Double(completedSets) / Double(state.totalSets)
    }

    private var exerciseInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("当前动作")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if state.totalSets > 0 {
                    Text("第 \(min(state.currentSetIndex + 1, state.totalSets)) / \(state.totalSets) 组")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(state.currentExerciseName ?? "—")
                .font(.headline)
                .foregroundColor(.primary)
            
            SwiftUI.ProgressView(value: exerciseProgress)
                .tint(.primary)
                .scaleEffect(x: 1, y: 1.1, anchor: .center)
            
            if let next = state.nextExerciseName, !next.isEmpty {
                HStack(spacing: 6) {
                    Text("下一动作")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(next)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var quickRecordCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快速记录")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("次数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("输入次数", text: $quickReps)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("RIR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("RIR", selection: $quickRIR) {
                        ForEach(0...4, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            ActionButton(
                title: "完成一组",
                systemImage: "checkmark.circle.fill",
                style: .emphasis,
                action: onCompleteSet
            )
            .disabled(quickReps.isEmpty)
            .opacity(quickReps.isEmpty ? 0.6 : 1)
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ActionButton: View {
    enum Style {
        case emphasis
        case neutral
        case secondary
        case danger
        
        var background: Color {
            switch self {
            case .emphasis:
                return .black
            case .neutral:
                return Color(white: 0.95)

            case .secondary:
                return Color(.systemGray5)
            case .danger:
                return .red
            }
        }
        
        var foreground: Color {
            switch self {
            case .emphasis, .danger:
                return .white
            case .neutral, .secondary:
                return .primary
            }
        }
    }
    
    let title: String
    let systemImage: String
    let style: Style
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(style.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(style.background)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color(white: 0.95)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            FloatingBallPanel(
                state: {
                    let state = FloatingBallState()
                    state.isResting = true
                    state.restRemaining = 45
                    state.restTotal = 90
                    state.subtitle = "深蹲 · 4组×8次 · 休90秒"
                    state.currentExerciseName = "深蹲"
                    state.currentSetIndex = 1
                    state.totalSets = 4
                    state.nextExerciseName = "平板支撑"
                    return state
                }(),
                quickReps: .constant("8"),
                quickRIR: .constant(1),
                onPlus15: {},
                onTogglePause: {},
                onSkip: {},
                onStartRest: {},
                onCompleteSet: {},
                onEnd: {}
            )
        }
    }
}

