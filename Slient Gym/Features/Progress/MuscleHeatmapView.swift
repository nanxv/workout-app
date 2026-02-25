//
//  MuscleHeatmapView.swift
//  Silent Gym
//
//  Visual muscle-group heatmap based on recent training sessions.
//  • Red  = just trained (high load, needs recovery)
//  • Yellow = recovering
//  • Dim  = fully rested
//  • Colors are calculated from a rolling 7-day training-load score.
//

import SwiftUI

// MARK: - Muscle Group Definition

private struct MuscleGroup: Identifiable {
    let id = UUID()
    let name: String
    let icon: String          // SF Symbol
    let emoji: String
    let keywords: [String]    // Matched against exercise names (case-insensitive)

    var intensity: Double = 0      // 0 (rested) … 1 (peak load)
    var daysSinceLast: Double = -1 // -1 = never trained
}

// MARK: - MuscleHeatmapView

struct MuscleHeatmapView: View {
    let sessions: [Session]

    private var groups: [MuscleGroup] {
        computeIntensities()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("肌肉恢复状态", systemImage: "figure.strengthtraining.traditional")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            let columns = [GridItem(.flexible()), GridItem(.flexible()),
                           GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(groups) { group in
                    muscleCard(group)
                }
            }

            legendRow
        }
        .padding(16)
        .sgCard()
    }

    // MARK: - Card

    private func muscleCard(_ group: MuscleGroup) -> some View {
        let color = heatColor(intensity: group.intensity)
        return VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 46, height: 46)
                Circle()
                    .stroke(color, lineWidth: group.intensity > 0.01 ? 2 : 1)
                    .frame(width: 46, height: 46)
                Text(group.emoji)
                    .font(.title3)
            }
            Text(group.name)
                .font(.caption.bold())
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
            Group {
                if group.daysSinceLast < 0 {
                    Text("未训练")
                } else if group.daysSinceLast < 1 {
                    Text("今天")
                } else {
                    Text("\(Int(group.daysSinceLast))天前")
                }
            }
            .font(.system(size: 9))
            .foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 20) {
            legendDot(color: Color(red: 1, green: 0.27, blue: 0.27), label: "刚训练")
            legendDot(color: Color(red: 1, green: 0.76, blue: 0.10), label: "恢复中")
            legendDot(color: AppTheme.border, label: "已恢复")
        }
        .font(.caption2)
        .foregroundColor(AppTheme.textTertiary)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    // MARK: - Intensity Calculation

    private func computeIntensities() -> [MuscleGroup] {
        var definitions: [MuscleGroup] = [
            MuscleGroup(name: "胸", icon: "heart.fill", emoji: "💪",
                        keywords: ["俯卧撑", "push", "chest", "bench", "卧推", "夹胸", "chest press"]),
            MuscleGroup(name: "背", icon: "arrow.up.backward", emoji: "🏋️",
                        keywords: ["引体", "划船", "硬拉", "pull", "row", "lat", "back", "反向"]),
            MuscleGroup(name: "肩", icon: "figure.arms.open", emoji: "🤸",
                        keywords: ["肩", "overhead", "press", "推举", "侧平举", "military"]),
            MuscleGroup(name: "手臂", icon: "bolt.fill", emoji: "💪",
                        keywords: ["弯举", "curl", "tricep", "二头", "三头", "arm", "dip"]),
            MuscleGroup(name: "核心", icon: "scope", emoji: "🔥",
                        keywords: ["平板", "plank", "hollow", "dead bug", "腹", "core", "crunch"]),
            MuscleGroup(name: "腿", icon: "figure.run", emoji: "🦵",
                        keywords: ["深蹲", "squat", "弓步", "lunge", "腿", "leg press", "extension"]),
            MuscleGroup(name: "臀", icon: "figure.walk", emoji: "🍑",
                        keywords: ["臀", "glute", "hip", "bridge", "deadlift", "硬拉"]),
            MuscleGroup(name: "有氧", icon: "heart.circle", emoji: "🏃",
                        keywords: ["run", "跑", "rowing", "bike", "cardio", "burpee", "jump"]),
        ]

        let calendar = Calendar.current
        let now = Date()

        // Score each muscle group across the last 14 sessions
        for i in definitions.indices {
            var totalLoad = 0.0
            var earliest = Double.infinity

            for session in sessions.prefix(30) {
                let hoursAgo = calendar.dateComponents([.hour], from: session.startAt, to: now)
                    .hour.map(Double.init) ?? 999
                let daysAgo = hoursAgo / 24.0
                guard daysAgo < 7 else { continue }  // Only last 7 days matter

                for se in session.exercises ?? [] {
                    let name = se.exercise?.name ?? ""
                    let matched = definitions[i].keywords.contains {
                        name.localizedCaseInsensitiveContains($0)
                    }
                    if matched {
                        let completedSets = se.sets?.filter(\.isCompleted).count ?? 0
                        // Decay: full weight today, half weight at day 3.5, zero at day 7
                        let decayFactor = max(0, 1.0 - daysAgo / 7.0)
                        totalLoad += Double(completedSets) * decayFactor
                        earliest = min(earliest, daysAgo)
                    }
                }
            }

            definitions[i].intensity      = min(1.0, totalLoad / 12.0)
            definitions[i].daysSinceLast  = earliest < .infinity ? earliest : -1
        }

        return definitions
    }

    private func heatColor(intensity: Double) -> Color {
        switch intensity {
        case ..<0.01: return AppTheme.border
        case ..<0.35: return Color(red: 1.0, green: 0.76, blue: 0.10)  // yellow — recovering
        default:      return Color(red: 1.0, green: 0.27, blue: 0.27)  // red — fresh load
        }
    }
}
