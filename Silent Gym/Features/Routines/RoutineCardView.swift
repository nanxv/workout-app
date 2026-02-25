//
//  RoutineCardView.swift
//  Silent Gym
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
                        
                        if let exercises = routine.exercises, !exercises.isEmpty {
                            Text("\(exercises.count) 个动作")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // 展开内容
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
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
            
            Text(planSummary)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var planSummary: String {
        if routineExercise.isHoldType, let holdSec = routineExercise.holdSecDefault {
            return "\(routineExercise.targetSets)组 × \(holdSec)秒 · 休息 \(routineExercise.restSecondsDefault)秒"
        }
        if let repTarget = routineExercise.repTarget, repTarget > 0 {
            return "\(routineExercise.targetSets)组 × \(repTarget)次 · 休息 \(routineExercise.restSecondsDefault)秒"
        }
        return "\(routineExercise.targetSets)组 · 休息 \(routineExercise.restSecondsDefault)秒"
    }
}

