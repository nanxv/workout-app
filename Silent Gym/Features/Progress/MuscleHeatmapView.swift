//
//  MuscleHeatmapView.swift
//  Silent Gym
//
//  Phase 2 refactor — driven by MuscleHeatmapViewModel.
//  Colors animate smoothly from rested (gray) → recovering (amber) → trained (deep red)
//  as the current session's volume increases.
//

import SwiftUI

// MARK: - MuscleHeatmapView

struct MuscleHeatmapView: View {

    @ObservedObject var vm: MuscleHeatmapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerLabel

            let columns = [
                GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible()), GridItem(.flexible())
            ]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.groups) { group in
                    MuscleCard(group: group)
                }
            }

            legendRow
        }
        .padding(16)
        .sgCard()
    }

    // MARK: - Header

    private var headerLabel: some View {
        HStack {
            Label("肌肉状态", systemImage: "figure.strengthtraining.traditional")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            // Show live indicator if any muscle has live volume
            if vm.groups.contains(where: { $0.liveVolume > 0 }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(0.4), lineWidth: 4)
                                .scaleEffect(1.8)
                        )
                    Text("训练中")
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                }
            }
        }
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 20) {
            legendDot(color: heatColor(0.9), label: "刚训练")
            legendDot(color: heatColor(0.4), label: "恢复中")
            legendDot(color: AppTheme.border,  label: "已恢复")
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
}

// MARK: - MuscleCard

/// Animated card for a single muscle group.
private struct MuscleCard: View {
    let group: MuscleGroupData

    var body: some View {
        let color = heatColor(group.intensity)

        VStack(spacing: 5) {
            ZStack {
                // Animated fill circle
                Circle()
                    .fill(color.opacity(0.16))
                    .frame(width: 46, height: 46)
                    .animation(.easeInOut(duration: 0.5), value: group.intensity)

                // Animated stroke
                Circle()
                    .stroke(color, lineWidth: group.intensity > 0.01 ? 2.2 : 1)
                    .frame(width: 46, height: 46)
                    .animation(.easeInOut(duration: 0.5), value: group.intensity)

                Text(group.emoji)
                    .font(.title3)
            }

            Text(group.name)
                .font(.caption.bold())
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            // Sub-label: live volume or days-since label
            Group {
                if group.liveVolume > 0 {
                    Text("+\(Int(group.liveVolume)) kg·次")
                        .foregroundColor(.green)
                        .transition(.opacity)
                } else if group.daysSinceLast < 0 {
                    Text("未训练")
                } else if group.daysSinceLast < 1 {
                    Text("今天")
                } else {
                    Text("\(Int(group.daysSinceLast))天前")
                }
            }
            .font(.system(size: 9))
            .foregroundColor(group.liveVolume > 0 ? .green : AppTheme.textTertiary)
            .animation(.easeInOut(duration: 0.3), value: group.liveVolume)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.06))
        .animation(.easeInOut(duration: 0.5), value: group.intensity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Color function (shared by view + legend)

/// Smooth gradient: gray → amber → orange → deep red as intensity grows from 0 → 1.
func heatColor(_ intensity: Double) -> Color {
    guard intensity > 0.01 else { return AppTheme.border }
    // Hue: 0.08 (amber-yellow) down to 0.0 (red)
    let hue        = max(0, 0.09 - intensity * 0.09)
    let saturation = min(1, 0.65 + intensity * 0.35)
    let brightness = max(0.6, 1.0 - intensity * 0.15)
    return Color(hue: hue, saturation: saturation, brightness: brightness)
}
