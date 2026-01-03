//
//  RoutinesViewWireframe.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Based on Wireframe v1.8.3 - Inline editable routines with import/export
//

import SwiftUI
import SwiftData

struct RoutinesViewWireframe: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.name) private var routines: [Routine]
    @State private var showingAddRoutine = false
    @State private var importExportOpen = false
    @State private var importText = ""
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Sticky 工具栏
                    HStack {
                        Text("计划")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            addRoutine()
                        }) {
                            Text("+ 训练模版")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        
                        Menu {
                            Button(action: {
                                importExportOpen.toggle()
                            }) {
                                Label(importExportOpen ? "收起导入" : "导入/导出", systemImage: "square.and.arrow.down")
                            }
                            
                            Button(action: {
                                exportJSON()
                            }) {
                                Label("导出 JSON", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(action: {
                                resetToDefault()
                            }) {
                                Label("恢复默认", systemImage: "arrow.counterclockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // 导入/导出面板
                    if importExportOpen {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("粘贴 JSON 后点击\"载入\"覆盖当前计划。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $importText)
                                .frame(height: 120)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    importJSON()
                                }) {
                                    Text("载入")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.black)
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    importExportOpen = false
                                    importText = ""
                                }) {
                                    Text("完成")
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
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                    
                    // 训练计划列表
                    VStack(spacing: 12) {
                        ForEach(routines) { routine in
                            RoutineDayCardWireframe(
                                routine: routine,
                                modelContext: modelContext,
                                onUpdate: { updatedRoutine in
                                    // Routine 是 @Bindable，自动更新
                                },
                                onRemove: {
                                    modelContext.delete(routine)
                                    try? modelContext.save()
                                },
                                onMoveUp: {
                                    moveRoutine(routine, direction: -1)
                                },
                                onMoveDown: {
                                    moveRoutine(routine, direction: 1)
                                },
                                onDuplicate: {
                                    duplicateRoutine(routine)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("计划")
        }
        .alert("导入结果", isPresented: $showImportAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(importAlertMessage)
        }
    }
    
    private func addRoutine() {
        let routine = Routine(name: "Day \(String(Character(UnicodeScalar(65 + routines.count)!)))")
        modelContext.insert(routine)
        try? modelContext.save()
    }
    
    private func moveRoutine(_ routine: Routine, direction: Int) {
        guard let index = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < routines.count else { return }
        
        // 更新 order（如果有的话）
        // 这里简化处理，实际可能需要更复杂的排序逻辑
    }
    
    private func duplicateRoutine(_ routine: Routine) {
        let newRoutine = Routine(name: "\(routine.name) Copy")
        modelContext.insert(newRoutine)
        
        if let exercises = routine.exercises {
            for (index, re) in exercises.sorted(by: { $0.order < $1.order }).enumerated() {
                let newExercise = Exercise(name: re.exercise?.name ?? "新动作")
                modelContext.insert(newExercise)
                
                let newRE = RoutineExercise(
                    routine: newRoutine,
                    exercise: newExercise,
                    order: index,
                    targetSets: re.targetSets,
                    restSecondsDefault: re.restSecondsDefault,
                    tempoDefault: re.tempoDefault,
                    repTargetLow: re.repTargetLow,
                    repTargetHigh: re.repTargetHigh,
                    holdSecDefault: re.holdSecDefault,
                    weightKgDefault: re.weightKgDefault
                )
                modelContext.insert(newRE)
            }
        }
        
        try? modelContext.save()
    }
    
    private func exportJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let routinesData = routines.map { routine -> [String: Any] in
            var dict: [String: Any] = [
                "id": routine.id.uuidString,
                "name": routine.name
            ]
            
            if let exercises = routine.exercises?.sorted(by: { $0.order < $1.order }) {
                dict["exercises"] = exercises.map { re -> [String: Any] in
                    var exDict: [String: Any] = [
                        "id": re.id.uuidString,
                        "order": re.order,
                        "targetSets": re.targetSets,
                        "restSecondsDefault": re.restSecondsDefault
                    ]
                    
                    if let exercise = re.exercise {
                        exDict["exerciseName"] = exercise.name
                    }
                    
                    if let repTarget = re.repTarget {
                        exDict["repTarget"] = repTarget
                    }
                    
                    if let holdSec = re.holdSecDefault {
                        exDict["holdSecDefault"] = holdSec
                    }
                    
                    if let weight = re.weightKgDefault {
                        exDict["weightKgDefault"] = weight
                    }
                    
                    return exDict
                }
            }
            
            return dict
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: routinesData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            #if os(iOS)
            UIPasteboard.general.string = jsonString
            importAlertMessage = "已复制到剪贴板"
            showImportAlert = true
            #endif
        }
    }
    
    private func importJSON() {
        guard !importText.isEmpty else { return }
        
        guard let jsonData = importText.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            importAlertMessage = "JSON 格式错误"
            showImportAlert = true
            return
        }
        
        // 清除现有数据（可选）
        // for routine in routines {
        //     modelContext.delete(routine)
        // }
        
        for routineDict in jsonArray {
            guard let name = routineDict["name"] as? String else { continue }
            
            let routine = Routine(name: name)
            modelContext.insert(routine)
            
            if let exercisesArray = routineDict["exercises"] as? [[String: Any]] {
                for (index, exDict) in exercisesArray.enumerated() {
                    let exerciseName = exDict["exerciseName"] as? String ?? "新动作"
                    let exercise = Exercise(name: exerciseName)
                    modelContext.insert(exercise)
                    
                    let targetSets = exDict["targetSets"] as? Int ?? 3
                    let restSec = exDict["restSecondsDefault"] as? Int ?? 90
                    let repTarget = exDict["repTarget"] as? Int
                    let holdSec = exDict["holdSecDefault"] as? Int
                    let weightKg = exDict["weightKgDefault"] as? Double
                    
                    let re = RoutineExercise(
                        routine: routine,
                        exercise: exercise,
                        order: index,
                        targetSets: targetSets,
                        restSecondsDefault: restSec,
                        repTargetLow: repTarget,
                        repTargetHigh: repTarget,
                        holdSecDefault: holdSec,
                        weightKgDefault: weightKg
                    )
                    modelContext.insert(re)
                }
            }
        }
        
        do {
            try modelContext.save()
            importAlertMessage = "已载入，已自动保存"
            importExportOpen = false
            importText = ""
        } catch {
            importAlertMessage = "保存失败：\(error.localizedDescription)"
        }
        
        showImportAlert = true
    }
    
    private func resetToDefault() {
        // 生成默认数据
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

/// 训练计划卡片（可展开，行内编辑）
struct RoutineDayCardWireframe: View {
    @Bindable var routine: Routine
    let modelContext: ModelContext
    let onUpdate: (Routine) -> Void
    let onRemove: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDuplicate: () -> Void
    
    @State private var isExpanded = true
    @State private var showCalendarSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    InlineEditText(
                        value: routine.name,
                        onChange: { newName in
                            routine.name = newName
                            try? modelContext.save()
                        },
                        placeholder: "训练计划名称"
                    )
                    .font(.headline)
                    
                    if let exercises = routine.exercises, !exercises.isEmpty {
                        let count = exercises.count
                        let minutes = estimateMinutes(for: routine)
                        Text("\(count) 个动作 · 约 \(minutes) 分钟")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(isExpanded ? "▴ 收起" : "▾ 展开")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    IconButton(title: "添加到日历", icon: "calendar.badge.plus") {
                        showCalendarSheet = true
                    }
                    IconButton(title: "上移", icon: "arrow.up") {
                        onMoveUp()
                    }
                    IconButton(title: "下移", icon: "arrow.down") {
                        onMoveDown()
                    }
                    IconButton(title: "复制", icon: "doc.on.doc") {
                        onDuplicate()
                    }
                    IconButton(title: "删除", icon: "trash") {
                        onRemove()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }
            
            // 展开内容
            if isExpanded {
                VStack(spacing: 0) {
                    if let exercises = routine.exercises?.sorted(by: { $0.order < $1.order }) {
                        ForEach(exercises) { re in
                            RoutineExerciseRowView(
                                routineExercise: re,
                                onRemove: {
                                    modelContext.delete(re)
                                    try? modelContext.save()
                                },
                                onMoveUp: {
                                    moveExercise(re, direction: -1, in: exercises)
                                },
                                onMoveDown: {
                                    moveExercise(re, direction: 1, in: exercises)
                                },
                                onDuplicate: {
                                    duplicateExercise(re, in: routine)
                                }
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            
                            if re.id != exercises.last?.id {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    
                    // 添加动作按钮
                    Button(action: {
                        addExercise(to: routine)
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("添加动作")
                        }
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showCalendarSheet) {
            RoutineCalendarSheet(routine: routine)
        }
    }
    
    private func estimateMinutes(for routine: Routine) -> Int {
        guard let exercises = routine.exercises else { return 0 }
        let totalSeconds = exercises.reduce(0) { acc, re in
            let exerciseTime: Int
            if re.isHoldType, let holdSec = re.holdSecDefault {
                exerciseTime = re.targetSets * (holdSec + re.restSecondsDefault)
            } else {
                let repTime = 6
                exerciseTime = re.targetSets * (re.restSecondsDefault + (re.repTarget ?? 10) * repTime)
            }
            return acc + exerciseTime
        }
        return max(20, min(120, totalSeconds / 60))
    }
    
    private func moveExercise(_ exercise: RoutineExercise, direction: Int, in exercises: [RoutineExercise]) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < exercises.count else { return }
        
        let sorted = exercises.sorted(by: { $0.order < $1.order })
        let temp = sorted[index].order
        sorted[index].order = sorted[newIndex].order
        sorted[newIndex].order = temp
        
        try? modelContext.save()
    }
    
    private func duplicateExercise(_ exercise: RoutineExercise, in routine: Routine) {
        let newExercise = Exercise(name: "\(exercise.exercise?.name ?? "新动作") Copy")
        modelContext.insert(newExercise)
        
        let newRE = RoutineExercise(
            routine: routine,
            exercise: newExercise,
            order: (routine.exercises?.count ?? 0),
            targetSets: exercise.targetSets,
            restSecondsDefault: exercise.restSecondsDefault,
            tempoDefault: exercise.tempoDefault,
            repTargetLow: exercise.repTargetLow,
            repTargetHigh: exercise.repTargetHigh,
            holdSecDefault: exercise.holdSecDefault,
            weightKgDefault: exercise.weightKgDefault
        )
        modelContext.insert(newRE)
        try? modelContext.save()
    }
    
    private func addExercise(to routine: Routine) {
        let newExercise = Exercise(name: "新动作")
        modelContext.insert(newExercise)
        
        let order = routine.exercises?.count ?? 0
        let newRE = RoutineExercise(
            routine: routine,
            exercise: newExercise,
            order: order,
            targetSets: 3,
            restSecondsDefault: 90
        )
        modelContext.insert(newRE)
        try? modelContext.save()
    }
}

