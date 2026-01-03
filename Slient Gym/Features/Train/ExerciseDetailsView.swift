//
//  ExerciseDetailsView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Based on Wireframe v1.8.3
//

import SwiftUI
import SwiftData

/// 动作详情展开视图（显示所有组，支持勾选完成）
struct ExerciseDetailsView: View {
    let sessionExercise: SessionExercise
    let routineExercise: RoutineExercise?
    @Environment(\.modelContext) private var modelContext
    @State private var isExpanded: Bool
    @State private var setLogs: [SetLogEntry] = []
    
    init(sessionExercise: SessionExercise, routineExercise: RoutineExercise?, defaultExpanded: Bool = false) {
        self.sessionExercise = sessionExercise
        self.routineExercise = routineExercise
        _isExpanded = State(initialValue: defaultExpanded)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部：动作名称和计划信息
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sessionExercise.exercise?.name ?? "未知动作")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let routineExercise {
                            Text(planDescription(for: routineExercise))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // 展开内容：所有组的记录
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text("每组详情（勾选完成后会自动按计划填入，可修改）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    let targetSets = routineExercise?.targetSets ?? 3
                    ForEach(0..<targetSets, id: \.self) { index in
                        SetRowView(
                            index: index + 1,
                            setLog: setLogs[safe: index] ?? SetLogEntry(
                                setIndex: index,
                                isCompleted: false,
                                reps: routineExercise?.repTarget,
                                holdSec: routineExercise?.holdSecDefault,
                                weightKg: routineExercise?.weightKgDefault
                            ),
                            isHoldType: routineExercise?.isHoldType ?? false,
                            hasWeight: routineExercise?.weightKgDefault != nil,
                            planReps: routineExercise?.repTarget,
                            planHold: routineExercise?.holdSecDefault,
                            restSec: routineExercise?.restSecondsDefault ?? 90,
                            onUpdate: { newLog in
                                updateSetLog(at: index, newLog: newLog)
                            }
                        )
                    }
                    
                    // 统计信息
                    let totalDone = setLogs.filter { $0.isCompleted }.count
                    let totalReps = setLogs.filter { $0.isCompleted && !isHoldType }.reduce(0) { $0 + ($1.reps ?? 0) }
                    
                    if routineExercise?.isHoldType == true {
                        Text("已完成：\(totalDone)/\(targetSets) 组 · 组间休息：\(routineExercise?.restSecondsDefault ?? 90)秒（建议）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("已完成总次数：\(totalReps) · 已完成：\(totalDone)/\(targetSets) 组 · 组间休息：\(routineExercise?.restSecondsDefault ?? 90)秒（建议）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            loadSetLogs()
        }
    }
    
    private func loadSetLogs() {
        guard let sets = sessionExercise.sets?.sorted(by: { $0.setIndex < $1.setIndex }) else {
            // 初始化空记录
            let targetSets = routineExercise?.targetSets ?? 3
            setLogs = (0..<targetSets).map { index in
                SetLogEntry(
                    setIndex: index,
                    isCompleted: false,
                    reps: routineExercise?.repTarget,
                    holdSec: routineExercise?.holdSecDefault,
                    weightKg: routineExercise?.weightKgDefault
                )
            }
            return
        }
        
        let targetSets = routineExercise?.targetSets ?? 3
        var logs: [SetLogEntry] = []
        
        for index in 0..<targetSets {
            if let set = sets.first(where: { $0.setIndex == index }) {
                logs.append(SetLogEntry(
                    setIndex: index,
                    isCompleted: set.isCompleted,
                    reps: set.reps > 0 ? set.reps : nil,
                    holdSec: set.holdSec,
                    weightKg: set.weightKg
                ))
            } else {
                logs.append(SetLogEntry(
                    setIndex: index,
                    isCompleted: false,
                    reps: routineExercise?.repTarget,
                    holdSec: routineExercise?.holdSecDefault,
                    weightKg: routineExercise?.weightKgDefault
                ))
            }
        }
        
        setLogs = logs
    }
    
    private func updateSetLog(at index: Int, newLog: SetLogEntry) {
        guard index < setLogs.count else { return }
        
        setLogs[index] = newLog
        
        // 保存到数据库
        if newLog.isCompleted {
            // 查找或创建 SetEntry
            let existingSet = sessionExercise.sets?.first { $0.setIndex == index }
            
            if let existingSet = existingSet {
                existingSet.isCompleted = true
                existingSet.reps = newLog.reps ?? 0
                existingSet.holdSec = newLog.holdSec
                existingSet.weightKg = newLog.weightKg
                existingSet.rir = 1 // 默认 RIR
            } else {
                let setEntry = SetEntry(
                    sessionExercise: sessionExercise,
                    setIndex: index,
                    reps: newLog.reps ?? 0,
                    rir: 1,
                    restSecondsUsed: 0,
                    holdSec: newLog.holdSec,
                    weightKg: newLog.weightKg,
                    isCompleted: true
                )
                modelContext.insert(setEntry)
            }
            
            do {
                try modelContext.save()
            } catch {
                print("Error saving set entry: \(error)")
            }
            
            // 如果从未完成变为完成，触发休息计时
            if let restSec = routineExercise?.restSecondsDefault, restSec > 0 {
                // 通过 NotificationCenter 通知父组件启动休息
                NotificationCenter.default.post(
                    name: NSNotification.Name("StartRestTimer"),
                    object: nil,
                    userInfo: ["restSeconds": restSec]
                )
            }
        }
    }
    
    private var isHoldType: Bool {
        routineExercise?.isHoldType ?? false
    }
    
    private func planDescription(for routineExercise: RoutineExercise) -> String {
        let planText = "\(routineExercise.targetSets)组"
        let detailText: String
        if routineExercise.isHoldType, let holdSec = routineExercise.holdSecDefault {
            detailText = "×\(holdSec)秒"
        } else if let repTarget = routineExercise.repTarget {
            detailText = "×\(repTarget)次"
        } else {
            detailText = ""
        }
        return "计划：\(planText)\(detailText) · 休息：\(routineExercise.restSecondsDefault)秒"
    }
}

/// 单组记录视图
struct SetRowView: View {
    let index: Int
    @State var setLog: SetLogEntry
    let isHoldType: Bool
    let hasWeight: Bool
    let planReps: Int?
    let planHold: Int?
    let restSec: Int
    let onUpdate: (SetLogEntry) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 完成按钮
            Button(action: {
                var newLog = setLog
                newLog.isCompleted.toggle()
                
                // 如果勾选完成且次数为空，自动填入计划次数
                if newLog.isCompleted && !isHoldType && newLog.reps == nil {
                    newLog.reps = planReps ?? 0
                }
                
                setLog = newLog
                onUpdate(newLog)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: setLog.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(setLog.isCompleted ? .green : .gray)
                    Text("第\(index)组")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(setLog.isCompleted ? Color.green.opacity(0.1) : Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // 重量输入（如果有）
            if hasWeight {
                HStack(spacing: 4) {
                    Text("重量(kg)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    InlineDoubleField(
                        value: Binding(
                            get: { setLog.weightKg },
                            set: { newValue in
                                var newLog = setLog
                                newLog.weightKg = newValue
                                setLog = newLog
                                onUpdate(newLog)
                            }
                        ),
                        placeholder: "0"
                    )
                    .frame(width: 60)
                }
            }
            
            // 次数或时长输入
            if isHoldType {
                HStack(spacing: 4) {
                    Text("秒")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    InlineNumberField(
                        value: Binding(
                            get: { setLog.holdSec },
                            set: { newValue in
                                var newLog = setLog
                                newLog.holdSec = newValue
                                setLog = newLog
                                onUpdate(newLog)
                            }
                        ),
                        placeholder: "\(planHold ?? 0)"
                    )
                    .frame(width: 60)
                }
            } else {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("次数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        InlineNumberField(
                            value: Binding(
                                get: { setLog.reps },
                                set: { newValue in
                                    var newLog = setLog
                                    newLog.reps = newValue
                                    setLog = newLog
                                    onUpdate(newLog)
                                }
                            ),
                            placeholder: "\(planReps ?? 0)"
                        )
                        .frame(width: 60)
                    }
                    
                    // 快捷计数按钮
                    HStack(spacing: 4) {
                        Button(action: {
                            var newLog = setLog
                            let current = newLog.reps ?? planReps ?? 0
                            newLog.reps = max(0, current - 1)
                            setLog = newLog
                            onUpdate(newLog)
                        }) {
                            Text("-1")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            var newLog = setLog
                            let current = newLog.reps ?? planReps ?? 0
                            newLog.reps = current + 1
                            setLog = newLog
                            onUpdate(newLog)
                        }) {
                            Text("+1")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            var newLog = setLog
                            let current = newLog.reps ?? planReps ?? 0
                            newLog.reps = current + 5
                            setLog = newLog
                            onUpdate(newLog)
                        }) {
                            Text("+5")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

/// 行内数字输入框（Int）
struct InlineNumberField: View {
    @Binding var value: Int?
    @State private var isEditing = false
    @State private var draftText: String = ""
    let placeholder: String
    
    var body: some View {
        if isEditing {
            TextField(placeholder, text: $draftText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit {
                    commit()
                }
                .onAppear {
                    draftText = value?.description ?? ""
                }
        } else {
            Button(action: {
                isEditing = true
            }) {
                Text(value?.description ?? placeholder)
                    .font(.caption)
                    .foregroundColor(value != nil ? .primary : .secondary)
                    .frame(minWidth: 40)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func commit() {
        if let intValue = Int(draftText) {
            value = intValue
        } else if draftText.isEmpty {
            value = nil
        }
        isEditing = false
    }
}

/// 行内浮点数输入框（Double，用于重量）
struct InlineDoubleField: View {
    @Binding var value: Double?
    @State private var isEditing = false
    @State private var draftText: String = ""
    let placeholder: String
    
    var body: some View {
        if isEditing {
            TextField(placeholder, text: $draftText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit {
                    commit()
                }
                .onAppear {
                    draftText = value != nil ? String(format: "%.1f", value!) : ""
                }
        } else {
            Button(action: {
                isEditing = true
            }) {
                Text(value != nil ? String(format: "%.1f", value!) : placeholder)
                    .font(.caption)
                    .foregroundColor(value != nil ? .primary : .secondary)
                    .frame(minWidth: 40)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func commit() {
        if let doubleValue = Double(draftText) {
            value = doubleValue
        } else if draftText.isEmpty {
            value = nil
        }
        isEditing = false
    }
}

/// 组记录数据模型（临时，用于 UI）
struct SetLogEntry {
    var setIndex: Int
    var isCompleted: Bool
    var reps: Int?
    var holdSec: Int?
    var weightKg: Double?
}

// subscript(safe:) 已在 TrainViewWireframe.swift 中定义，这里不再重复定义

