//
//  WatchMessage.swift
//  Silent Gym  (shared between iOS + watchOS targets)
//
//  Phase 4: added message priority, SetEntryPayload, and new message types
//  for the offline-first sync architecture.
//

import Foundation

// MARK: - Priority

/// Delivery guarantee tier.
///  • `.realtime`  — send-and-forget via `sendMessage`. Dropped when disconnected.
///  • `.reliable`  — enqueued locally and retried with `transferUserInfo` until delivered.
public enum MessagePriority: String, Codable {
    case realtime
    case reliable
}

// MARK: - Message types

public enum WatchMessageType: String, Codable {
    // ── Control (reliable) ──────────────────────────────────────────────
    case startWorkout       = "START_WORKOUT"
    case stopWorkout        = "STOP_WORKOUT"
    case workoutSaved       = "WORKOUT_SAVED"
    case setEntryCompleted  = "SET_ENTRY_COMPLETED"   // Watch → iPhone: a set was logged
    case sessionStateChanged = "SESSION_STATE_CHANGED" // iPhone → Watch: coordinator state

    // ── Live / realtime (fire-and-forget) ────────────────────────────────
    case updateNow          = "UPDATE_NOW"            // iPhone → Watch: exercise info
    case heartRateUpdate    = "HEART_RATE_UPDATE"     // Watch → iPhone: live BPM

    // ── System ───────────────────────────────────────────────────────────
    case error              = "ERROR"
}

extension WatchMessageType {
    /// Delivery guarantee for this message type.
    public var priority: MessagePriority {
        switch self {
        case .heartRateUpdate, .updateNow:
            return .realtime
        default:
            return .reliable
        }
    }
}

// MARK: - SetEntry payload (Watch → iPhone when a set is completed)

/// Lightweight, Codable representation of one completed set.
/// Transmitted inside a `WatchMessage` when the user logs a rep from their wrist.
public struct SetEntryPayload: Codable {
    public let sessionId: UUID
    public let exerciseName: String
    public let setIndex: Int
    public let reps: Int
    public let weightKg: Double?
    public let rir: Int
    public let completedAt: Date

    public init(
        sessionId: UUID,
        exerciseName: String,
        setIndex: Int,
        reps: Int,
        weightKg: Double? = nil,
        rir: Int = 0,
        completedAt: Date = Date()
    ) {
        self.sessionId    = sessionId
        self.exerciseName = exerciseName
        self.setIndex     = setIndex
        self.reps         = reps
        self.weightKg     = weightKg
        self.rir          = rir
        self.completedAt  = completedAt
    }
}

// MARK: - WatchMessage

public struct WatchMessage: Codable {
    // Core
    public let type: WatchMessageType
    public let sessionId: UUID?

    // Workout control
    public let activityType: Int?
    public let routineName: String?         // NEW — attached to startWorkout

    // Live exercise info
    public let exerciseName: String?
    public let setIndex: Int?
    public let totalSets: Int?

    // Realtime metrics
    public let heartRate: Double?           // NEW — BPM from Watch
    public let activeCalories: Double?      // NEW — kcal snapshot

    // Set completion (Watch → iPhone)
    public let setEntry: SetEntryPayload?   // NEW

    // Workout saved acknowledgement
    public let healthWorkoutUUID: UUID?

    // Error
    public let errorCode: String?
    public let errorMessage: String?

    public init(
        type: WatchMessageType,
        sessionId: UUID? = nil,
        activityType: Int? = nil,
        routineName: String? = nil,
        exerciseName: String? = nil,
        setIndex: Int? = nil,
        totalSets: Int? = nil,
        heartRate: Double? = nil,
        activeCalories: Double? = nil,
        setEntry: SetEntryPayload? = nil,
        healthWorkoutUUID: UUID? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil
    ) {
        self.type              = type
        self.sessionId         = sessionId
        self.activityType      = activityType
        self.routineName       = routineName
        self.exerciseName      = exerciseName
        self.setIndex          = setIndex
        self.totalSets         = totalSets
        self.heartRate         = heartRate
        self.activeCalories    = activeCalories
        self.setEntry          = setEntry
        self.healthWorkoutUUID = healthWorkoutUUID
        self.errorCode         = errorCode
        self.errorMessage      = errorMessage
    }
}
