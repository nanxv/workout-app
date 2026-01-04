//
//  FloatingBallPanel.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/03.
//  Based on ChatGPT design recommendations
//

import SwiftUI

/// 悬浮球底部迷你面板
struct FloatingBallPanel: View {
    @ObservedObject var state: FloatingBallState
    let onPlus15: () -> Void
    let onSkip: () -> Void
    let onEnd: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // 顶部拖拽指示器
            Capsule()
                .fill(.secondary.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
            
            if state.isResting {
                Text("休息中 • \(Int(state.restRemaining))s")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Button(action: onPlus15) {
                        Text("+15s")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    
                    Button(action: onSkip) {
                        Text("跳过")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
            } else {
                Text("训练进行中")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Button(role: .destructive, action: {
                onEnd()
                state.showPanel = false
            }) {
                Text("结束训练")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12 + safeBottom)
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
}

#Preview {
    ZStack {
        Color(.systemGray6)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            FloatingBallPanel(
                state: {
                    let state = FloatingBallState()
                    state.isResting = true
                    state.restRemaining = 45
                    state.restTotal = 90
                    return state
                }(),
                onPlus15: {},
                onSkip: {},
                onEnd: {}
            )
        }
    }
}

