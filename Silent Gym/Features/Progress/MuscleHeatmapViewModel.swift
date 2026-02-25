//
//  MuscleHeatmapViewModel.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/02/25.
//
//  Drives the real-time muscle heatmap.
//  • Historical sessions provide the 7-day fatigue baseline.
//  • The live SessionCoordinator state adds in-progress volume immediately.
//  • Colors animate smoothly via withAnimation when muscle intensities change.
//

import Foundation
import Combine
import SwiftData
import SwiftUI

// MARK: - MuscleGroupData

/// Value type that drives one heatmap card. Equatable so SwiftUI can diff precisely.
struct MuscleGroupData: Identifiable, Equatable {
    let id: UUID
    let name: String
    let emoji: String
    let keywords: [String]

    /// 0 (fully rested) → 1 (peak load / just trained). Animated.
    var intensity: Double
    /// Accumulated volume from the current session (kg × reps). For live label.
    var liveVolume: Double
    /// Days since last training event. –1 = never.
    var daysSinceLast: Double

    static func == (lhs: MuscleGroupData, rhs: MuscleGroupData) -> Bool {
        lhs.id == rhs.id &&
        abs(lhs.intensity - rhs.intensity) < 0.005 &&
        abs(lhs.liveVolume - rhs.liveVolume) < 0.5 &&
        abs(lhs.daysSinceLast - rhs.daysSinceLast) < 0.1
    }
}

// MARK: - MuscleHeatmapViewModel

@MainActor
final class MuscleHeatmapViewModel: ObservableObject {

    @Published private(set) var groups: [MuscleGroupData] = MuscleHeatmapViewModel.defaultGroups()

    private var historicalSessions: [Session] = []
    private let coordinator: SessionCoordinator
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(coordinator: SessionCoordinator) {
        self.coordinator = coordinator
        setupBindings()
    }

    // MARK: - Public API

    /// Called by ProgressView whenever the `@Query` result changes.
    func refresh(sessions: [Session]) {
        historicalSessions = sessions
        recompute()
    }

    // MARK: - Bindings

    private func setupBindings() {
        // Re-compute every time a set is completed or rest starts (state changes)
        coordinator.$state
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)

        coordinator.$currentSession
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
    }

    // MARK: - Computation

    private func recompute() {
        let newGroups = computeGroups(
            historical: historicalSessions,
            live: coordinator.currentSession
        )
        // Only animate if something actually changed
        guard newGroups != groups else { return }
        withAnimation(.easeInOut(duration: 0.55)) {
            groups = newGroups
        }
    }

    private func computeGroups(
        historical: [Session],
        live: Session?
    ) -> [MuscleGroupData] {
        var defs = MuscleHeatmapViewModel.defaultGroups()
        let calendar = Calendar.current
        let now = Date()

        for i in defs.indices {
            var totalLoad = 0.0
            var liveVolume = 0.0
            var earliest = Double.infinity

            // ── Historical sessions (7-day decay) ──
            for session in historical.prefix(30) {
                let hoursAgo = calendar.dateComponents([.hour], from: session.startAt, to: now)
                    .hour.map(Double.init) ?? 999
                let daysAgo = hoursAgo / 24.0
                guard daysAgo < 7 else { continue }

                for se in session.exercises ?? [] {
                    guard matches(exercise: se.exercise, group: defs[i]) else { continue }
                    let completedSets = se.sets?.filter(\.isCompleted).count ?? 0
                    let decay = max(0, 1.0 - daysAgo / 7.0)
                    totalLoad += Double(completedSets) * decay
                    earliest = min(earliest, daysAgo)
                }
            }

            // ── Live session (no decay, full weight) ──
            if let live {
                for se in live.exercises ?? [] {
                    guard matches(exercise: se.exercise, group: defs[i]) else { continue }
                    for set in se.sets ?? [] where set.isCompleted {
                        let vol = (set.weightKg ?? 0) * Double(set.reps)
                            + Double(set.reps) // bodyweight contribution
                        liveVolume += vol
                        // Count each completed set as ~1.5 load units (heavier than historical)
                        totalLoad += 1.5
                    }
                    if !(se.sets?.filter(\.isCompleted).isEmpty ?? true) {
                        earliest = min(earliest, 0)
                    }
                }
            }

            defs[i].intensity    = min(1.0, totalLoad / 12.0)
            defs[i].liveVolume   = liveVolume
            defs[i].daysSinceLast = earliest < .infinity ? earliest : -1
        }

        return defs
    }

    private func matches(exercise: Exercise?, group: MuscleGroupData) -> Bool {
        guard let name = exercise?.name else { return false }
        return group.keywords.contains { name.localizedCaseInsensitiveContains($0) }
    }

    // MARK: - Default group definitions

    static func defaultGroups() -> [MuscleGroupData] {
        [
            MuscleGroupData(id: UUID(), name: "胸",   emoji: "💪",
                keywords: ["俯卧撑","push","chest","bench","卧推","夹胸"],
                intensity: 0, liveVolume: 0, daysSinceLast: -1),
            MuscleGroupData(id: UUID(), name: "背",   emoji: "🏋️",
                keywords: ["引体","划船","硬拉","pull","row","lat","back"],
                intensity: 0, liveVolume: 0, daysSinceLast: -1),
            MuscleGroupData(id: UUID(), name: "肩",   emoji: "🤸",
                keywords: ["肩","overhead","press","推举","侧平举","military"],
                intensity: 0, liveVolume: 0, daysSinceLast: -1),
            MuscleGroupData(id: UUID(), name: "手臂", emoji: "💪",
                keywords: ["弯举","curl","tricep","二头","三头","dip"],
                intensity: 0, liveVolume: 0, daysSinceLast: -1),
            MuscleGroupData(id: UUID(), name: "核心", emoji: "🔥",
                keywords: ["平板","plank","hollow","腹","core","crunch"],
                intensity: 0, liveVolume: 0, daysSinceLast: -1),
            MuscleGroupData(id: UUID(), name: "腿",   emoji: "🦵",
                keywords: ["深蹲","squat","弓步","lunge","腿","leg press"],
                intensity: 0, liveVolume: 0, daysSinceLast: -1),
            MuscleGroupData(id: UUID(), name: "臀",   emoji: "🍑",
                keywords: ["臀","glute","hip","bridge","deadlift","硬拉"],
                intensity: 0, liveVolume: 0, daysSinceLast: -1),
            MuscleGroupData(id: UUID(), name: "有氧", emoji: "🏃",
                keywords: ["run","跑","rowing","bike","cardio","burpee","jump"],
                intensity: 0, liveVolume: 0, daysSinceLast: -1),
        ]
    }
}
