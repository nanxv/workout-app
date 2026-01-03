//
//  MainTabViewWireframe.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Based on Wireframe v1.8.3 - Bottom nav with raised center button
//

import SwiftUI

struct MainTabViewWireframe: View {
    @State private var selectedTab: TabItem = .train
    
    enum TabItem: String, CaseIterable {
        case routines = "计划"
        case records = "记录"
        case train = "训练"
        case coach = "教练"
        case settings = "设置"
        
        var icon: String {
            switch self {
            case .routines: return "list.bullet"
            case .records: return "clock.fill"
            case .train: return "dumbbell.fill"
            case .coach: return "message.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 内容区
            Group {
                switch selectedTab {
                case .train:
                    TrainViewWireframe()
                case .routines:
                    RoutinesViewWireframe()
                case .records:
                    HistoryViewWireframe()
                case .coach:
                    CoachViewWireframe()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 底部导航（中间训练按钮凸起）
            BottomNavWireframe(selectedTab: $selectedTab)
        }
    }
}

struct BottomNavWireframe: View {
    @Binding var selectedTab: MainTabViewWireframe.TabItem
    
    var body: some View {
        VStack(spacing: 0) {
            // 主导航栏
            HStack(spacing: 0) {
                ForEach([MainTabViewWireframe.TabItem.routines, .records, .coach, .settings], id: \.self) { tab in
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

#Preview {
    MainTabViewWireframe()
}

