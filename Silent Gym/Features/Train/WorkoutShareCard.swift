//
//  WorkoutShareCard.swift
//  Silent Gym
//
//  Generates a social-media-ready training summary card.
//  • Uses ImageRenderer (@3x) for high-res export
//  • Share via UIActivityViewController — no special photo-library permission needed
//  • Designed for 9:16 video-thumbnail use (portrait crop friendly)
//

import SwiftUI
import SwiftData

#if os(iOS)
import UIKit
#endif

// MARK: - WorkoutShareCard (Renderable View)

struct WorkoutShareCard: View {
    let session: Session

    // MARK: Computed stats

    private var completedSets: [SetEntry] {
        (session.exercises ?? []).flatMap { $0.sets ?? [] }.filter(\.isCompleted)
    }
    private var totalSets: Int  { completedSets.count }
    private var totalReps: Int  { completedSets.reduce(0) { $0 + $1.reps } }
    private var totalVolume: Double {
        completedSets.reduce(0) { $0 + Double($1.reps) * ($1.weightKg ?? 0) }
    }
    private var durationMin: Int {
        Int((session.duration ?? 0) / 60)
    }
    private var orderedExercises: [SessionExercise] {
        (session.exercises ?? []).sorted { $0.order < $1.order }
    }
    private var exerciseStats: [(name: String, sets: Int, vol: Double)] {
        orderedExercises.prefix(6).compactMap { se in
            guard let name = se.exercise?.name else { return nil }
            let sets = se.sets?.filter(\.isCompleted).count ?? 0
            let vol  = se.sets?.filter(\.isCompleted)
                         .reduce(0.0) { $0 + Double($1.reps) * ($1.weightKg ?? 0) } ?? 0
            return (name, sets, vol)
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().overlay(AppTheme.border)
            statsRow
            Divider().overlay(AppTheme.border)
            exerciseList
            if totalVolume > 0 {
                VolumeBarChart(exerciseStats: exerciseStats)
                    .frame(height: 56)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 12)
            }
            footerSection
        }
        .background(Color(white: 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    // MARK: Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SILENT GYM")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(AppTheme.accent)
                Text(session.routineNameSnapshot)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(session.startAt.formatted(date: .long, time: .omitted))
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 30))
                .foregroundColor(AppTheme.accent)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statBlock(value: "\(durationMin)", unit: "MIN", label: "时长")
            statDivider
            statBlock(value: "\(totalSets)", unit: "SETS", label: "总组数")
            statDivider
            statBlock(value: "\(totalReps)", unit: "REPS", label: "总次数")
            if totalVolume > 0 {
                statDivider
                statBlock(value: String(format: "%.0f", totalVolume), unit: "KG", label: "总重量")
            }
        }
        .padding(.vertical, 16)
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(exerciseStats.enumerated()), id: \.offset) { i, stat in
                HStack(spacing: 10) {
                    Text("\(i + 1)")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 18)
                    Text(stat.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    if stat.vol > 0 {
                        Text(String(format: "%.0f kg", stat.vol))
                            .font(.caption)
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    Text("\(stat.sets) sets")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var footerSection: some View {
        HStack {
            Text("Stay consistent. Stay silent.")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(AppTheme.textTertiary)
            Spacer()
            Text("silent.gym")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundColor(AppTheme.accent.opacity(0.7))
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    // MARK: Helpers

    private func statBlock(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.accent)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(width: 1, height: 44)
    }
}

// MARK: - Volume Bar Chart

private struct VolumeBarChart: View {
    let exerciseStats: [(name: String, sets: Int, vol: Double)]

    private var maxVol: Double { exerciseStats.map(\.vol).max() ?? 1 }

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(exerciseStats.enumerated()), id: \.offset) { _, stat in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accent.opacity(0.55)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: max(4, 44 * stat.vol / max(maxVol, 1)))
                    Text(String(stat.name.prefix(3)))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(AppTheme.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - WorkoutShareSheet (Presentation Layer)

struct WorkoutShareSheet: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss
    @State private var isRendering = false
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        WorkoutShareCard(session: session)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        Text("保存后可直接作为短视频转场素材 🎬")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)

                        Button {
                            renderAndShare()
                        } label: {
                            if isRendering {
                                HStack(spacing: 8) {
                                    ProgressView().tint(AppTheme.accentForeground)
                                    Text("渲染中...")
                                }
                            } else {
                                Label("分享 / 保存", systemImage: "square.and.arrow.up")
                            }
                        }
                        .buttonStyle(SGPrimaryButtonStyle())
                        .padding(.horizontal, 24)
                        .disabled(isRendering)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("训练卡片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        #if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty {
                ActivityViewControllerWrapper(activityItems: shareItems)
                    .ignoresSafeArea()
            }
        }
        #endif
    }

    @MainActor
    private func renderAndShare() {
        isRendering = true
        let card = WorkoutShareCard(session: session)
            .frame(width: 390)
            .preferredColorScheme(.dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0   // @3x — high-res for video use
        #if os(iOS)
        if let uiImage = renderer.uiImage {
            shareItems = [uiImage]
            showShareSheet = true
        }
        #endif
        isRendering = false
    }
}

// MARK: - UIActivityViewController wrapper

#if os(iOS)
struct ActivityViewControllerWrapper: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
