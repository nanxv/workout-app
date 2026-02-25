//
//  ProgressView.swift
//  Silent Gym
//
//  Phase 2: drives the live MuscleHeatmapView via AppDependencies.heatmapViewModel.
//

import SwiftUI
import SwiftData

struct ProgressView: View {
    @EnvironmentObject private var deps: AppDependencies

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \ExternalWorkout.startAt, order: .reverse) private var externalWorkouts: [ExternalWorkout]

    var body: some View {
        NavigationStack {
            List {
                // Heatmap — live updates reflect today's sets in real-time
                Section {
                    MuscleHeatmapView(vm: deps.heatmapViewModel)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                weeklySummarySection
                exerciseTrendsSection
            }
            .listStyle(.plain)
            .navigationTitle("进度")
        }
        .onAppear {
            deps.heatmapViewModel.refresh(sessions: Array(sessions.prefix(30)))
        }
        .onChange(of: sessions) { _, newSessions in
            deps.heatmapViewModel.refresh(sessions: Array(newSessions.prefix(30)))
        }
    }

    // MARK: - Weekly summary

    private var weeklySummarySection: some View {
        Section("本周") {
            let stats = weekStats()
            LabeledContent("力量", value: "\(stats.strengthMinutes) 分钟")
            LabeledContent("有氧", value: "\(stats.cardioMinutes) 分钟")
            LabeledContent("训练次数", value: "\(stats.totalSessions)")
            if stats.totalDistance > 0 {
                LabeledContent("总距离", value: "\(String(format: "%.2f", stats.totalDistance)) 公里")
            }
        }
    }

    // MARK: - Exercise trends

    private var exerciseTrendsSection: some View {
        Section("动作趋势") {
            let exerciseStats = buildExerciseStats()
            ForEach(exerciseStats.keys.sorted(), id: \.self) { name in
                if let stat = exerciseStats[name] {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name).font(.headline)
                        Text("最佳 \(stat.bestReps) 次 · 总计 \(stat.totalReps) 次 · 平均 RIR \(String(format: "%.1f", stat.avgRIR))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Calculations

    private func weekStats() -> (strengthMinutes: Int, cardioMinutes: Int, totalSessions: Int, totalDistance: Double) {
        guard let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else {
            return (0, 0, 0, 0)
        }
        let ws = sessions.filter { $0.startAt >= weekStart }
        let we = externalWorkouts.filter { $0.startAt >= weekStart }
        return (
            ws.compactMap(\.duration).reduce(0) { $0 + Int($1) / 60 },
            Int(we.reduce(0) { $0 + $1.duration }) / 60,
            ws.count + we.count,
            we.compactMap(\.totalDistance).reduce(0, +) / 1_000
        )
    }

    private func buildExerciseStats() -> [String: (bestReps: Int, totalReps: Int, avgRIR: Double)] {
        var raw: [String: (best: Int, total: Int, count: Int, rirSum: Int)] = [:]
        for session in sessions {
            for se in session.exercises ?? [] {
                guard let name = se.exercise?.name, let sets = se.sets else { continue }
                let reps = sets.map(\.reps)
                let r: (best: Int, total: Int, count: Int, rirSum: Int) = (
                    reps.max() ?? 0,
                    reps.reduce(0, +),
                    sets.count,
                    sets.map(\.rir).reduce(0, +)
                )
                if let e = raw[name] {
                    raw[name] = (max(e.best, r.best), e.total + r.total, e.count + r.count, e.rirSum + r.rirSum)
                } else {
                    raw[name] = r
                }
            }
        }
        return raw.mapValues { v in
            (v.best, v.total, v.count > 0 ? Double(v.rirSum) / Double(v.count) : 0)
        }
    }
}

#Preview {
    ProgressView()
        .modelContainer(for: [Session.self, ExternalWorkout.self], inMemory: true)
        .environmentObject(AppDependencies())
}
