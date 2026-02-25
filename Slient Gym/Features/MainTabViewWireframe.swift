//
//  MainTabViewWireframe.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Based on Wireframe v1.8.3 - Bottom nav with raised center button
//

import SwiftUI

struct MainTabViewWireframe: View {
    @State private var selectedTab: AppTab = .train
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 内容区
            Group {
                switch selectedTab {
                case .train:
                    TrainViewWireframe(currentTab: $selectedTab)
                case .routines:
                    RoutinesViewWireframe()
                case .records:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 底部导航（中间训练按钮凸起）
            BottomNavWireframe(selectedTab: $selectedTab)
        }
        .overlay(alignment: .bottomTrailing) {
            if selectedTab != .train {
                FloatingTabSwitcherBall(currentTab: $selectedTab)
                    .padding(.trailing, 16)
                    .padding(.bottom, 96)
            }
        }
    }
}

struct BottomNavWireframe: View {
    @Binding var selectedTab: AppTab
    
    var body: some View {
        VStack(spacing: 0) {
            // 主导航栏
            HStack(spacing: 0) {
                ForEach([AppTab.routines, .records, .settings], id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                            Text(tab.rawValue)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 8)
            .background(Color(.systemBackground).opacity(0.95))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator)),
                alignment: .top
            )
            
            // Safe Area 留白
            Color(.systemBackground)
                .opacity(0.95)
                .frame(height: 0) // Safe area handled by system
        }
        .overlay(
            // 中央凸起的训练按钮
            Button(action: {
                selectedTab = .train
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -32)
            .buttonStyle(.plain),
            alignment: .bottom
        )
    }
}

private struct FloatingTabSwitcherBall: View {
    @Binding var currentTab: AppTab
    @State private var isMenuPresented = false
    @State private var highlightedTab: AppTab?
    
    private let size: CGFloat = 52
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(
                x: geo.size.width - size / 2,
                y: geo.size.height - size / 2
            )
            
            ZStack {
                if isMenuPresented {
                    FloatingRadialTabMenu(
                        currentTab: currentTab,
                        center: center,
                        highlightedTab: $highlightedTab,
                        onSelect: { tab in
                            currentTab = tab
                            isMenuPresented = false
                            highlightedTab = nil
                        },
                        onCancel: {
                            isMenuPresented = false
                            highlightedTab = nil
                        }
                    )
                }
                
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: currentTab.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                    .position(center)
                    .gesture(tabSwitchGesture(center: center))
            }
        }
        .frame(width: size + 180, height: size + 180)
        .allowsHitTesting(true)
    }
    
    private func tabSwitchGesture(center: CGPoint) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    isMenuPresented = true
                case .second(true, let drag?):
                    highlightedTab = FloatingRadialTabMenu.closestTab(
                        location: drag.location,
                        center: center,
                        currentTab: currentTab
                    )
                default:
                    break
                }
            }
            .onEnded { value in
                if case .second(true, let drag?) = value,
                   let selected = FloatingRadialTabMenu.closestTab(
                    location: drag.location,
                    center: center,
                    currentTab: currentTab
                   ) {
                    currentTab = selected
                }
                isMenuPresented = false
                highlightedTab = nil
            }
    }
}


#Preview {
    MainTabViewWireframe()
}

