//
//  RoutineExerciseRowView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Based on Wireframe v1.8.3 - Inline editable exercise row
//

import SwiftUI
import SwiftData

/// 动作行视图（行内编辑，支持排序和复制）
struct RoutineExerciseRowView: View {
    @Bindable var routineExercise: RoutineExercise
    let onRemove: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDuplicate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // 左侧：编辑区域
                VStack(alignment: .leading, spacing: 8) {
                    // 动作名称
                    InlineEditText(
                        value: routineExercise.exercise?.name ?? "",
                        onChange: { newName in
                            if routineExercise.exercise == nil {
                                // 创建新 Exercise
                                let exercise = Exercise(name: newName)
                                routineExercise.exercise = exercise
                            } else {
                                routineExercise.exercise?.name = newName
                            }
                        },
                        placeholder: "动作名称"
                    )
                    
                    // 编辑网格
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        // 组数
                        VStack(alignment: .leading, spacing: 4) {
                            Text("组")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            InlineEditNumber(
                                value: routineExercise.targetSets,
                                onChange: { newValue in
                                    routineExercise.targetSets = newValue ?? 1
                                },
                                placeholder: "1",
                                min: 1,
                                max: 20
                            )
                        }
                        
                        // 次数
                        VStack(alignment: .leading, spacing: 4) {
                            Text("次数")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            InlineEditNumber(
                                value: routineExercise.repTarget,
                                onChange: { newValue in
                                    if let newValue = newValue {
                                        routineExercise.repTargetLow = newValue
                                        routineExercise.repTargetHigh = newValue
                                    } else {
                                        routineExercise.repTargetLow = nil
                                        routineExercise.repTargetHigh = nil
                                    }
                                    // 如果设置了次数，清除时长
                                    if newValue != nil {
                                        routineExercise.holdSecDefault = nil
                                    }
                                },
                                placeholder: "—",
                                min: 0,
                                max: 300
                            )
                        }
                        
                        // 时长（秒）
                        VStack(alignment: .leading, spacing: 4) {
                            Text("时长(s)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            InlineEditNumber(
                                value: routineExercise.holdSecDefault,
                                onChange: { newValue in
                                    routineExercise.holdSecDefault = newValue
                                    // 如果设置了时长，清除次数
                                    if newValue != nil {
                                        routineExercise.repTargetLow = nil
                                        routineExercise.repTargetHigh = nil
                                    }
                                },
                                placeholder: "—",
                                min: 0,
                                max: 900
                            )
                        }
                        
                        // 休息（秒）
                        VStack(alignment: .leading, spacing: 4) {
                            Text("休息(s)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            InlineEditNumber(
                                value: routineExercise.restSecondsDefault,
                                onChange: { newValue in
                                    routineExercise.restSecondsDefault = newValue ?? 0
                                },
                                placeholder: "0",
                                min: 0,
                                max: 600
                            )
                        }
                        
                        // 重量（kg）
                        VStack(alignment: .leading, spacing: 4) {
                            Text("重量(kg)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            InlineEditDouble(
                                value: routineExercise.weightKgDefault,
                                onChange: { newValue in
                                    routineExercise.weightKgDefault = newValue
                                },
                                placeholder: "—",
                                min: 0,
                                max: 500
                            )
                        }
                    }
                }
                
                // 右侧：操作按钮
                VStack(spacing: 8) {
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
        }
        .padding(.vertical, 8)
    }
}

/// 图标按钮
struct IconButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

