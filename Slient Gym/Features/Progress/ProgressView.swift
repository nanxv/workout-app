//
//  ProgressView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import SwiftData

struct ProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \ExternalWorkout.startAt, order: .reverse) private var externalWorkouts: [ExternalWorkout]
    
    var body: some View {
        NavigationStack {
            List {
                weeklySummarySection
                exerciseTrendsSection
            }
            .listStyle(.plain)
            .navigationTitle("进度")
        }
    }
    
    private var weeklySummarySection: some View {
        Section("本周") {
            let weekStats = calculateWeekStats()
            LabeledContent("力量", value: "\(weekStats.strengthMinutes) 分钟")
            LabeledContent("有氧", value: "\(weekStats.cardioMinutes) 分钟")
            LabeledContent("训练次数", value: "\(weekStats.totalSessions)")
            if weekStats.totalDistance > 0 {
                LabeledContent("总距离", value: "\(String(format: "%.2f", weekStats.totalDistance)) 公里")
            }
        }
    }
    
    private var exerciseTrendsSection: some View {
        Section("动作趋势") {
            let exerciseStats = calculateExerciseStats()
            ForEach(Array(exerciseStats.keys.sorted()), id: \.self) { exerciseName in
                if let stats = exerciseStats[exerciseName] {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exerciseName)
                            .font(.headline)
                        Text("最佳 \(stats.bestReps) · 总计 \(stats.totalReps) · 平均 RIR \(String(format: "%.1f", stats.avgRIR))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private func calculateWeekStats() -> (strengthMinutes: Int, cardioMinutes: Int, totalSessions: Int, totalDistance: Double) {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(byAdding: .day, value: -7, to: now) else {
            return (0, 0, 0, 0)
        }
        
        let weekSessions = sessions.filter { $0.startAt >= weekStart }
        let weekWorkouts = externalWorkouts.filter { $0.startAt >= weekStart }
        
        let strengthMinutes = weekSessions.compactMap { $0.duration }.reduce(0) { $0 + Int($1) / 60 }
        let cardioMinutes = Int(weekWorkouts.reduce(0) { $0 + $1.duration }) / 60
        let totalSessions = weekSessions.count + weekWorkouts.count
        let totalDistance = weekWorkouts.compactMap { $0.totalDistance }.reduce(0, +) / 1000.0 // Convert to km
        
        return (strengthMinutes, cardioMinutes, totalSessions, totalDistance)
    }
    
    private func calculateExerciseStats() -> [String: (bestReps: Int, totalReps: Int, avgRIR: Double)] {
        var stats: [String: (bestReps: Int, totalReps: Int, avgRIR: Double, count: Int, rirSum: Int)] = [:]
        
        for session in sessions {
            guard let exercises = session.exercises else { continue }
            for sessionExercise in exercises {
                guard let exerciseName = sessionExercise.exercise?.name,
                      let sets = sessionExercise.sets else { continue }
                
                let reps = sets.map { $0.reps }
                let bestReps = reps.max() ?? 0
                let totalReps = reps.reduce(0, +)
                let rirSum = sets.map { $0.rir }.reduce(0, +)
                
                if let existing = stats[exerciseName] {
                    stats[exerciseName] = (
                        bestReps: max(existing.bestReps, bestReps),
                        totalReps: existing.totalReps + totalReps,
                        avgRIR: 0,
                        count: existing.count + sets.count,
                        rirSum: existing.rirSum + rirSum
                    )
                } else {
                    stats[exerciseName] = (
                        bestReps: bestReps,
                        totalReps: totalReps,
                        avgRIR: 0,
                        count: sets.count,
                        rirSum: rirSum
                    )
                }
            }
        }
        
        return stats.mapValues { (bestReps: $0.bestReps, totalReps: $0.totalReps, avgRIR: Double($0.rirSum) / Double($0.count)) }
    }
}

#Preview {
    ProgressView()
        .modelContainer(for: [Session.self, ExternalWorkout.self], inMemory: true)
}

