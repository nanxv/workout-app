//
//  TrainingComplication.swift
//  Silent Gym — Watch Complication Widget Extension
//
//  Created by CHY5TK on 2026/02/25.
//
//  ──────────────────────────────────────────────────────────────────────
//  XCODE SETUP REQUIRED (one-time, ~5 minutes):
//
//  1. In Xcode, File → New → Target → watchOS → Widget Extension.
//     Name it "Silent Gym Complication".
//     Uncheck "Include Configuration App Intent".
//
//  2. In both the Watch App target AND this new extension target,
//     add an App Group capability: "group.ZC.POB.Silent-Gym".
//     (This lets ComplicationDataWriter share data with the widget.)
//
//  3. Add this file + ComplicationDataWriter.swift to the extension target.
//     (Don't add them to the Watch App target; ComplicationDataWriter is
//      already included there via the watchOS conditional.)
//
//  4. Build & run on a paired Watch simulator / device.
//  ──────────────────────────────────────────────────────────────────────

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct TrainingComplicationEntry: TimelineEntry {
    let date: Date
    let routineName: String
    let weeklyDays: Int
    let lastWorkoutMins: Int
}

// MARK: - Timeline Provider

struct TrainingComplicationProvider: TimelineProvider {

    private let defaults = UserDefaults(suiteName: "group.ZC.POB.Silent-Gym") ?? .standard

    func placeholder(in context: Context) -> TrainingComplicationEntry {
        .init(date: .now, routineName: "深蹲推举日", weeklyDays: 4, lastWorkoutMins: 48)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (TrainingComplicationEntry) -> Void
    ) {
        completion(entry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<TrainingComplicationEntry>) -> Void
    ) {
        let current = entry()
        // Refresh at next midnight (routine names change daily)
        let midnight = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [current], policy: .after(midnight)))
    }

    private func entry() -> TrainingComplicationEntry {
        TrainingComplicationEntry(
            date: .now,
            routineName: defaults.string(forKey: "silentGym.complication.todayRoutine") ?? "今日训练",
            weeklyDays:  defaults.integer(forKey: "silentGym.complication.weeklyDays"),
            lastWorkoutMins: defaults.integer(forKey: "silentGym.complication.lastWorkoutMins")
        )
    }
}

// MARK: - Complication Views

/// Circular (corner + modular small family).
struct CircularComplicationView: View {
    let entry: TrainingComplicationEntry

    var body: some View {
        ZStack {
            Circle().fill(.blue.opacity(0.25))
            VStack(spacing: 1) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("\(entry.weeklyDays)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }
        }
        .containerBackground(.black, for: .widget)
    }
}

/// Rectangular (modular large / extra large family).
struct RectangularComplicationView: View {
    let entry: TrainingComplicationEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.routineName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("本周 \(entry.weeklyDays) 天")
                    if entry.lastWorkoutMins > 0 {
                        Text("·")
                        Text("上次 \(entry.lastWorkoutMins) 分钟")
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.black, for: .widget)
    }
}

/// Inline (smallest, single line).
struct InlineComplicationView: View {
    let entry: TrainingComplicationEntry

    var body: some View {
        Text("💪 \(entry.routineName)  \(entry.weeklyDays)天/周")
            .font(.system(size: 10, weight: .semibold))
            .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Bundle Entry Point
// ⚠️  Add @main ONLY in the Widget Extension target's main Swift file,
//     not in the Watch App target.  Rename this struct in your extension.

struct SilentGymComplication: Widget {
    static let kind = "SilentGymTrainingComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TrainingComplicationProvider()) { entry in
            switch WidgetFamily.accessoryCircular {
            default:
                // The system picks the view that matches the slot family.
                // In practice you'd use an @Environment(\.widgetFamily) switch.
                RectangularComplicationView(entry: entry)
            }
        }
        .configurationDisplayName("Silent Gym 今日训练")
        .description("在表盘上显示今日计划名称和本周训练天数。")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

/// The actual `@main` entry point for the Widget Extension target.
/// Move this into a new file (e.g. `SilentGymComplicationBundle.swift`) inside
/// your Widget Extension target and annotate it with @main there.
struct SilentGymComplicationBundle: WidgetBundle {
    var body: some Widget {
        SilentGymComplication()
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    SilentGymComplication()
} timeline: {
    TrainingComplicationEntry(
        date: .now,
        routineName: "推胸 + 三头",
        weeklyDays: 3,
        lastWorkoutMins: 52
    )
}
