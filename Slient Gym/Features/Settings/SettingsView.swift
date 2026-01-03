//
//  SettingsView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Based on Wireframe v1.8.3
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.name) private var routines: [Routine]
    @AppStorage("statusCapsuleVisible") private var statusCapsuleVisible = true
    @AppStorage("compactListStyle") private var compactListStyle = false
    @State private var showResetAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 显示设置
                    SettingsSection(title: "显示") {
                        Toggle("训练页显示状态胶囊", isOn: $statusCapsuleVisible)
                        Toggle("紧凑列表样式", isOn: $compactListStyle)
                    }
                    
                    // 数据设置
                    SettingsSection(title: "数据") {
                        Text("计划数据存储于本机（SwiftData）。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showResetAlert = true
                        }) {
                            Text("恢复默认训练计划")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("设置")
        }
        .alert("恢复默认", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("确定", role: .destructive) {
                resetToDefault()
            }
        } message: {
            Text("这将清除所有现有训练计划并恢复默认计划。此操作不可撤销。")
        }
    }
    
    private func resetToDefault() {
        // 清除现有计划
        for routine in routines {
            modelContext.delete(routine)
        }
        
        // 创建默认计划
        let defaultRoutines: [(String, [(String, Int, Int?, Int?, Int, Double?)])] = [
            ("Day A", [
                ("俯卧撑", 4, 12, nil, 90, nil),
                ("徒手深蹲", 5, 15, nil, 120, nil),
                ("平板支撑", 3, nil, 45, 45, nil)
            ]),
            ("Day B", [
                ("反向划船", 4, 10, nil, 90, nil),
                ("Dead Bug", 3, 12, nil, 45, nil)
            ]),
            ("Day C", [
                ("弓步蹲", 4, 12, nil, 90, nil),
                ("Hollow Hold", 3, nil, 30, 45, nil),
                ("哑铃弯举", 3, 10, nil, 90, 10.0)
            ])
        ]
        
        for (dayName, exercises) in defaultRoutines {
            let routine = Routine(name: dayName)
            modelContext.insert(routine)
            
            for (index, (exName, sets, reps, holdSec, restSec, weight)) in exercises.enumerated() {
                let exercise = Exercise(name: exName)
                modelContext.insert(exercise)
                
                let re = RoutineExercise(
                    routine: routine,
                    exercise: exercise,
                    order: index,
                    targetSets: sets,
                    restSecondsDefault: restSec,
                    repTargetLow: reps,
                    repTargetHigh: reps,
                    holdSecDefault: holdSec,
                    weightKgDefault: weight
                )
                modelContext.insert(re)
            }
        }
        
        try? modelContext.save()
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

