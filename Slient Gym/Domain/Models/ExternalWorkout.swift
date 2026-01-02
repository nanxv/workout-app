//
//  ExternalWorkout.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import SwiftData

@Model
final class ExternalWorkout {
    @Attribute(.unique) var uuid: UUID
    var activityType: Int
    var startAt: Date
    var endAt: Date
    var duration: Double
    var totalDistance: Double?
    var totalEnergy: Double?
    var sourceName: String?
    var sourceBundleId: String?
    var importedAt: Date
    
    init(
        uuid: UUID,
        activityType: Int,
        startAt: Date,
        endAt: Date,
        duration: Double,
        totalDistance: Double? = nil,
        totalEnergy: Double? = nil,
        sourceName: String? = nil,
        sourceBundleId: String? = nil,
        importedAt: Date = Date()
    ) {
        self.uuid = uuid
        self.activityType = activityType
        self.startAt = startAt
        self.endAt = endAt
        self.duration = duration
        self.totalDistance = totalDistance
        self.totalEnergy = totalEnergy
        self.sourceName = sourceName
        self.sourceBundleId = sourceBundleId
        self.importedAt = importedAt
    }
}

