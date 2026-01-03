//
//  RoutineHistoryHelper.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import Foundation
import SwiftData

struct RoutineHistoryHelper {
    /// 获取指定 Routine 的最近一次 Session
    static func latestSession(for routineId: UUID, context: ModelContext) -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.routine?.id == routineId },
            sortBy: [SortDescriptor(\.startAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
    
    /// 获取指定 Session 和 Exercise 的所有 SetEntry（按 setIndex 排序）
    static func latestSetEntries(sessionId: UUID, exerciseId: UUID, context: ModelContext) -> [SetEntry] {
        let descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate { 
                $0.sessionExercise?.session?.id == sessionId &&
                $0.sessionExercise?.exercise?.id == exerciseId
            },
            sortBy: [SortDescriptor(\.setIndex, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// 获取指定 Routine 本周完成的次数
    static func weeklyCompletionCount(for routineId: UUID, context: ModelContext) -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return 0
        }
        
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { 
                $0.routine?.id == routineId &&
                $0.startAt >= weekStart &&
                $0.endAt != nil
            }
        )
        return (try? context.fetch(descriptor).count) ?? 0
    }
    
    /// 获取指定 Routine 最近一次训练的时长
    static func latestSessionDuration(for routineId: UUID, context: ModelContext) -> TimeInterval? {
        guard let session = latestSession(for: routineId, context: context) else {
            return nil
        }
        return session.duration
    }
}

