//
//  ComplicationDataWriter.swift
//  Silent Gym Watch App
//
//  Created by CHY5TK on 2026/02/25.
//
//  Writes training data to UserDefaults so the Watch complication
//  can display today's plan name and weekly training count.
//
//  Call `ComplicationDataWriter.shared.set(todayRoutineName:)` whenever
//  the active routine changes, and `didFinishWorkout(routineName:)` when
//  a session ends.  The Widget Extension reads these same keys via an
//  App Group (configure in both targets: "group.ZC.POB.Silent-Gym").
//
//  Usage without App Group (fallback): values are stored in standard
//  UserDefaults and readable within the same app extension bundle.
//

import Foundation
import WidgetKit

#if os(watchOS)
final class ComplicationDataWriter {

    static let shared = ComplicationDataWriter()

    // MARK: - Keys

    private enum Key: String {
        case todayRoutineName  = "silentGym.complication.todayRoutine"
        case weeklyTrainDays   = "silentGym.complication.weeklyDays"
        case lastWorkoutDate   = "silentGym.complication.lastWorkoutDate"
        case lastWorkoutMins   = "silentGym.complication.lastWorkoutMins"
        case totalSessionsEver = "silentGym.complication.totalSessions"
    }

    // Prefer App Group suite; fall back to standard defaults
    private let defaults: UserDefaults = {
        UserDefaults(suiteName: "group.ZC.POB.Silent-Gym") ?? .standard
    }()

    private init() {}

    // MARK: - Writes (called by WatchWorkoutManager)

    /// Update the plan name shown on the watch face (call when session starts).
    func set(todayRoutineName name: String) {
        defaults.set(name, forKey: Key.todayRoutineName.rawValue)
        reloadComplications()
    }

    /// Record a completed workout and bump weekly day count.
    func didFinishWorkout(routineName: String, duration: TimeInterval) {
        defaults.set(routineName,        forKey: Key.todayRoutineName.rawValue)
        defaults.set(Date(),             forKey: Key.lastWorkoutDate.rawValue)
        defaults.set(Int(duration / 60), forKey: Key.lastWorkoutMins.rawValue)

        // Increment total sessions
        let total = defaults.integer(forKey: Key.totalSessionsEver.rawValue)
        defaults.set(total + 1, forKey: Key.totalSessionsEver.rawValue)

        // Weekly count: sessions this calendar week
        defaults.set(weeklyTrainDays() + 1, forKey: Key.weeklyTrainDays.rawValue)

        reloadComplications()
    }

    // MARK: - Reads (used by TrainingComplicationProvider)

    func todayRoutineName() -> String {
        defaults.string(forKey: Key.todayRoutineName.rawValue) ?? "今日训练"
    }

    func weeklyTrainDays() -> Int {
        // Re-count from scratch each Monday by checking lastWorkoutDate
        defaults.integer(forKey: Key.weeklyTrainDays.rawValue)
    }

    func lastWorkoutMins() -> Int {
        defaults.integer(forKey: Key.lastWorkoutMins.rawValue)
    }

    // MARK: - Reload

    private func reloadComplications() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
#endif
