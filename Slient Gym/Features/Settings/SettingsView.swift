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
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer = true
    @AppStorage("minimalMode") private var minimalMode = true
    @AppStorage("homeGymMode") private var homeGymMode = false
    @State private var showResetAlert = false
    @State private var showClearHistoryAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("显示") {
                    Toggle("训练页显示状态胶囊", isOn: $statusCapsuleVisible)
                    Toggle("极简模式", isOn: $minimalMode)
                }
                
                Section("训练") {
                    Toggle("自动开始休息", isOn: $autoStartRestTimer)
                }

                // MARK: Home Gym Mode
                Section {
                    Toggle(isOn: $homeGymMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("家庭健身房模式")
                            Text("按你的器械过滤可用动作")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if homeGymMode {
                        NavigationLink("器械清单") {
                            HomeGymEquipmentView()
                        }
                    }
                } header: {
                    Text("家庭健身房")
                } footer: {
                    if homeGymMode {
                        Text("开启后，创建计划时系统会根据你选择的器械过滤动作建议。")
                            .font(.caption)
                    }
                }

                Section("数据") {
                    Text("计划数据存储于本机（SwiftData）。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("恢复默认训练计划") {
                        showResetAlert = true
                    }
                    
                    Button("清空训练记录") {
                        showClearHistoryAlert = true
                    }
                }
            }
            .navigationTitle("设置")
        }
        .animation(.easeInOut(duration: 0.2), value: statusCapsuleVisible)
        .alert("恢复默认", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("确定", role: .destructive) {
                resetToDefault()
            }
        } message: {
            Text("这将清除所有现有训练计划并恢复默认计划。此操作不可撤销。")
        }
        .alert("清空记录", isPresented: $showClearHistoryAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                clearHistory()
            }
        } message: {
            Text("将删除所有训练记录与导入的有氧数据。此操作不可撤销。")
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

    private func clearHistory() {
        let sessionDescriptor = FetchDescriptor<Session>()
        let externalDescriptor = FetchDescriptor<ExternalWorkout>()
        if let sessions = try? modelContext.fetch(sessionDescriptor) {
            for session in sessions {
                modelContext.delete(session)
            }
        }
        if let workouts = try? modelContext.fetch(externalDescriptor) {
            for workout in workouts {
                modelContext.delete(workout)
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Home Gym Equipment Selector

struct HomeGymEquipmentView: View {
    @AppStorage("homeGymEquipment") private var equipmentJSON = "[]"

    private let allEquipment: [(name: String, icon: String)] = [
        ("哑铃",     "dumbbell.fill"),
        ("杠铃",     "dumbbell"),
        ("深蹲架",   "figure.strengthtraining.traditional"),
        ("引体向上架", "figure.pull.ups"),
        ("弹力带",   "arrow.left.and.right"),
        ("壶铃",     "circles.hexagongrid.fill"),
        ("绳索 / 龙门架", "cable.connector"),
        ("固定器械", "building.2"),
        ("跳绳",     "figure.jumprope"),
        ("瑜伽垫",   "rectangle.fill"),
        ("泡沫轴",   "cylinder"),
        ("TRX 悬挂带", "link"),
    ]

    private var selected: Set<String> {
        guard let data = equipmentJSON.data(using: .utf8),
              let arr  = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(arr)
    }

    private func toggle(_ name: String) {
        var current = selected
        if current.contains(name) { current.remove(name) } else { current.insert(name) }
        if let data = try? JSONEncoder().encode(Array(current).sorted()),
           let str  = String(data: data, encoding: .utf8) {
            equipmentJSON = str
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(allEquipment, id: \.name) { item in
                    Button { toggle(item.name) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .foregroundColor(selected.contains(item.name) ? AppTheme.accent : .secondary)
                                .frame(width: 24)
                            Text(item.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selected.contains(item.name) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.accent)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("勾选你家里拥有的器械")
            } footer: {
                Text("已选：\(selected.count) 件")
            }
        }
        .navigationTitle("家庭器械")
        .navigationBarTitleDisplayMode(.inline)
    }
}

