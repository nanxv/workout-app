//
//  SampleDataGenerator.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import SwiftData

class SampleDataGenerator {
    static func generateSampleData(context: ModelContext) {
        // Check if data already exists
        let routineDescriptor = FetchDescriptor<Routine>()
        if let existingRoutines = try? context.fetch(routineDescriptor), !existingRoutines.isEmpty {
            return // Data already exists
        }
        
        // Create exercises
        let pushup = Exercise(name: "俯卧撑", tags: ["上肢", "胸"])
        let squat = Exercise(name: "深蹲", tags: ["下肢", "腿"])
        let pullup = Exercise(name: "引体向上", tags: ["上肢", "背"])
        let plank = Exercise(name: "平板支撑", tags: ["核心"])
        let burpee = Exercise(name: "Burpee", tags: ["全身", "有氧"])
        let lunge = Exercise(name: "箭步蹲", tags: ["下肢", "腿"])
        
        context.insert(pushup)
        context.insert(squat)
        context.insert(pullup)
        context.insert(plank)
        context.insert(burpee)
        context.insert(lunge)
        
        // Create Day A routine
        let dayA = Routine(name: "Day A")
        context.insert(dayA)
        
        let dayA_pushup = RoutineExercise(
            routine: dayA,
            exercise: pushup,
            order: 0,
            targetSets: 3,
            restSecondsDefault: 90
        )
        let dayA_squat = RoutineExercise(
            routine: dayA,
            exercise: squat,
            order: 1,
            targetSets: 3,
            restSecondsDefault: 120
        )
        let dayA_plank = RoutineExercise(
            routine: dayA,
            exercise: plank,
            order: 2,
            targetSets: 3,
            restSecondsDefault: 60
        )
        
        context.insert(dayA_pushup)
        context.insert(dayA_squat)
        context.insert(dayA_plank)
        
        // Create Day B routine
        let dayB = Routine(name: "Day B")
        context.insert(dayB)
        
        let dayB_pullup = RoutineExercise(
            routine: dayB,
            exercise: pullup,
            order: 0,
            targetSets: 3,
            restSecondsDefault: 90
        )
        let dayB_lunge = RoutineExercise(
            routine: dayB,
            exercise: lunge,
            order: 1,
            targetSets: 3,
            restSecondsDefault: 120
        )
        let dayB_burpee = RoutineExercise(
            routine: dayB,
            exercise: burpee,
            order: 2,
            targetSets: 3,
            restSecondsDefault: 90
        )
        
        context.insert(dayB_pullup)
        context.insert(dayB_lunge)
        context.insert(dayB_burpee)
        
        // Create Day C routine
        let dayC = Routine(name: "Day C")
        context.insert(dayC)
        
        let dayC_pushup = RoutineExercise(
            routine: dayC,
            exercise: pushup,
            order: 0,
            targetSets: 4,
            restSecondsDefault: 90
        )
        let dayC_squat = RoutineExercise(
            routine: dayC,
            exercise: squat,
            order: 1,
            targetSets: 4,
            restSecondsDefault: 120
        )
        let dayC_pullup = RoutineExercise(
            routine: dayC,
            exercise: pullup,
            order: 2,
            targetSets: 3,
            restSecondsDefault: 90
        )
        
        context.insert(dayC_pushup)
        context.insert(dayC_squat)
        context.insert(dayC_pullup)
        
        do {
            try context.save()
        } catch {
            print("Failed to save sample data: \(error)")
        }
    }
}

