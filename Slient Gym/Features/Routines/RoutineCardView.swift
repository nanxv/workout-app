//
//  RoutineCardView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import SwiftData

struct RoutineCardView: View {
    @Environment(\.modelContext) private var modelContext
    let routine: Routine
    let isExpanded: Bool
    let latestSession: Session?
    let onToggle: () -> Void
    let onNavigate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 折叠时的显示（可点击）
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.name)
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            if let exercises = routine.exercises, !exercises.isEmpty {
                                Text("\(exercises.count) 个动作")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let weeklyCount = weeklyCompletionCount, weeklyCount > 0 {
                                Text("本周 \(weeklyCount) 次")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let duration = latestSessionDuration {
                                Text(formatDuration(duration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // 展开内容
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    if let routineExercises = routine.exercises?.sorted(by: { $0.order < $1.order }),
                       !routineExercises.isEmpty {
                        ForEach(routineExercises) { routineExercise in
                            ExercisePlanRow(
                                routineExercise: routineExercise,
                                latestSession: latestSession,
                                context: modelContext
                            )
                        }
                    } else {
                        Text("该训练计划暂无动作")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                    
                    Divider()
                    
                    // 查看全部记录链接
                    NavigationLink(destination: HistoryView(selectedRoutineId: routine.id)) {
                        HStack {
                            Text("查看全部记录")
                                .font(.caption)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private var weeklyCompletionCount: Int? {
        RoutineHistoryHelper.weeklyCompletionCount(for: routine.id, context: modelContext)
    }
    
    private var latestSessionDuration: TimeInterval? {
        RoutineHistoryHelper.latestSessionDuration(for: routine.id, context: modelContext)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

struct ExercisePlanRow: View {
    @Environment(\.modelContext) private var modelContext
    let routineExercise: RoutineExercise
    let latestSession: Session?
    let context: ModelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 动作名称
            Text(routineExercise.exercise?.name ?? "未知")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack(alignment: .top, spacing: 16) {
                // 计划栏
                VStack(alignment: .leading, spacing: 4) {
                    Text("计划")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(routineExercise.targetSets)组")
                        .font(.caption)
                    if let repTarget = routineExercise.repTarget, repTarget > 0 {
                        Text("每组 \(repTarget) 次")
                            .font(.caption)
                    }
                    Text("休息 \(routineExercise.restSecondsDefault)秒")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 40)
                
                // 最近一次结果栏
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近一次")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let session = latestSession,
                       let exerciseId = routineExercise.exercise?.id {
                        let setEntries = RoutineHistoryHelper.latestSetEntries(
                            sessionId: session.id,
                            exerciseId: exerciseId,
                            context: context
                        )
                        
                        if !setEntries.isEmpty {
                            // 显示逐组结果
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(setEntries.prefix(5), id: \.id) { entry in
                                    Text("#\(entry.setIndex + 1): \(entry.reps)次/RIR\(entry.rir)")
                                        .font(.caption)
                                }
                                if setEntries.count > 5 {
                                    Text("...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            Text("— 未有记录 —")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("— 未有记录 —")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }
}

