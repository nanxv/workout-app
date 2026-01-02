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
                    Label("Train", systemImage: "dumbbell.fill")
                }
            
            RoutinesView()
                .tabItem {
                    Label("Routines", systemImage: "list.bullet")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            
            ProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            CoachView()
                .tabItem {
                    Label("Coach", systemImage: "message.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
}

