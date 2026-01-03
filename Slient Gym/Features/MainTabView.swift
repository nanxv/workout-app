//
//  MainTabView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TrainView()
                .tabItem {
                    Label("训练", systemImage: "dumbbell.fill")
                }
            
            RoutinesView()
                .tabItem {
                    Label("计划", systemImage: "list.bullet")
                }
            
            HistoryView()
                .tabItem {
                    Label("历史", systemImage: "clock.fill")
                }
            
            ProgressView()
                .tabItem {
                    Label("进度", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            CoachView()
                .tabItem {
                    Label("教练", systemImage: "message.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
}

