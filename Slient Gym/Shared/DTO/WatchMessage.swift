//
//  WatchMessage.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation

enum WatchMessageType: String, Codable {
    case startWorkout = "START_WORKOUT"
    case stopWorkout = "STOP_WORKOUT"
    case updateNow = "UPDATE_NOW"
    case workoutSaved = "WORKOUT_SAVED"
    case error = "ERROR"
}

struct WatchMessage: Codable {
    let type: WatchMessageType
    let sessionId: UUID?
    let activityType: Int?
    let exerciseName: String?
    let setIndex: Int?
    let totalSets: Int?
    let healthWorkoutUUID: UUID?
    let errorCode: String?
    let errorMessage: String?
    
    init(
        type: WatchMessageType,
        sessionId: UUID? = nil,
        activityType: Int? = nil,
        exerciseName: String? = nil,
        setIndex: Int? = nil,
        totalSets: Int? = nil,
        healthWorkoutUUID: UUID? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil
    ) {
        self.type = type
        self.sessionId = sessionId
        self.activityType = activityType
        self.exerciseName = exerciseName
        self.setIndex = setIndex
        self.totalSets = totalSets
        self.healthWorkoutUUID = healthWorkoutUUID
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

