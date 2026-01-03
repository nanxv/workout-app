//
//  HistoryViewWireframe.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Based on Wireframe v1.8.3 - History with overview cards and highlights
//

import SwiftUI
import SwiftData

struct HistoryViewWireframe: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \ExternalWorkout.startAt, order: .reverse) private var externalWorkouts: [ExternalWorkout]
    @State private var selectedFilter: HistoryFilter = .all
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 筛选按钮
                    HStack(spacing: 8) {
                        FilterButton(
                            title: "全部",
                            isSelected: selectedFilter == .all,
                            action: { selectedFilter = .all }
                        )
                        FilterButton(
                            title: "力量",
                            isSelected: selectedFilter == .strength,
                            action: { selectedFilter = .strength }
                        )
                        FilterButton(
                            title: "有氧（健康）",
                            isSelected: selectedFilter == .cardio,
                            action: { selectedFilter = .cardio }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // 概览卡片
                    if selectedFilter == .all || selectedFilter == .strength {
                        OverviewCards(sessions: sessions, externalWorkouts: externalWorkouts)
                            .padding(.horizontal)
                    }
                    
                    // 亮点卡片
                    if selectedFilter == .all || selectedFilter == .strength {
                        HighlightsCard(sessions: sessions)
                            .padding(.horizontal)
                    }
                    
                    // 历史列表
                    VStack(spacing: 12) {
                        ForEach(filteredSessions) { session in
                            HistoryItemView(session: session)
                        }
                        
                        if selectedFilter == .all || selectedFilter == .cardio {
                            ForEach(externalWorkouts) { workout in
                                ExternalWorkoutItemView(workout: workout)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("记录")
        }
    }
    
    private var filteredSessions: [Session] {
        switch selectedFilter {
        case .all:
            return sessions
        case .strength:
            return sessions
        case .cardio:
            return []
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.black : Color(.systemGray6))
                .cornerRadius(20)
        }
    }
}

struct OverviewCards: View {
    let sessions: [Session]
    let externalWorkouts: [ExternalWorkout]
    
    var body: some View {
        HStack(spacing: 12) {
            // 本周时长
            OverviewCard(
                title: "本周时长（分钟）",
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        StatBar(label: "力量", value: strengthMinutes, max: 180)
                        StatBar(label: "跑步", value: cardioMinutes, max: 90)
                    }
                }
            )
            
            // 训练量
            OverviewCard(
                title: "训练量（最近 7 次）",
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        StatBar(label: "俯卧撑（次数）", value: pushupReps, max: 220)
                        StatBar(label: "深蹲（次数）", value: squatReps, max: 260)
                    }
                }
            )
        }
    }
    
    private var strengthMinutes: Int {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions
            .filter { $0.startAt >= weekStart }
            .compactMap { $0.duration }
            .reduce(0) { $0 + Int($1) / 60 }
    }
    
    private var cardioMinutes: Int {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return Int(externalWorkouts
            .filter { $0.startAt >= weekStart }
            .reduce(0) { $0 + $1.duration }) / 60
    }
    
    private var pushupReps: Int {
        sessions
            .prefix(7)
            .compactMap { session -> Int? in
                guard let exercises = session.exercises else { return nil }
                for se in exercises {
                    if se.exercise?.name.contains("俯卧撑") == true,
                       let sets = se.sets {
                        return sets.filter { $0.isCompleted }.reduce(0) { $0 + $1.reps }
                    }
                }
                return nil
            }
            .reduce(0, +)
    }
    
    private var squatReps: Int {
        sessions
            .prefix(7)
            .compactMap { session -> Int? in
                guard let exercises = session.exercises else { return nil }
                for se in exercises {
                    if se.exercise?.name.contains("深蹲") == true,
                       let sets = se.sets {
                        return sets.filter { $0.isCompleted }.reduce(0) { $0 + $1.reps }
                    }
                }
                return nil
            }
            .reduce(0, +)
    }
}

struct OverviewCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct StatBar: View {
    let label: String
    let value: Int
    let max: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label) · \(value)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black)
                        .frame(width: max(6, min(geometry.size.width, CGFloat(value) / CGFloat(max) * geometry.size.width)), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct HighlightsCard: View {
    let sessions: [Session]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("亮点")
                .font(.headline)
            
            let highlights = calculateHighlights()
            
            VStack(alignment: .leading, spacing: 8) {
                if highlights.weeklyCompletion > 0 {
                    HighlightItem(text: "本周完成 \(highlights.weeklyCompletion)/\(highlights.weeklyTarget) 次训练")
                }
                if let bestHold = highlights.bestHold {
                    HighlightItem(text: "本周平板支撑最佳：\(bestHold)秒")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func calculateHighlights() -> (weeklyCompletion: Int, weeklyTarget: Int, bestHold: Int?) {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekSessions = sessions.filter { $0.startAt >= weekStart && $0.endAt != nil }
        
        var bestHold: Int? = nil
        for session in weekSessions {
            if let exercises = session.exercises {
                for se in exercises {
                    if se.exercise?.name.contains("平板支撑") == true,
                       let sets = se.sets {
                        for set in sets where set.isCompleted {
                            if let holdSec = set.holdSec, holdSec > (bestHold ?? 0) {
                                bestHold = holdSec
                            }
                        }
                    }
                }
            }
        }
        
        return (weekSessions.count, 3, bestHold)
    }
}

struct HighlightItem: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct HistoryItemView: View {
    let session: Session
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.routine?.name ?? "未知训练计划")
                    .font(.headline)
                Text(session.startAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                StatusDot(state: session.healthWorkoutUUID != nil ? "ok" : "warn", label: "健康")
                StatusDot(state: session.calendarEventId != nil ? "ok" : "warn", label: "日历")
                
                Button("重试") {
                    // 重试逻辑
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ExternalWorkoutItemView: View {
    let workout: ExternalWorkout
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("跑步")
                    .font(.headline)
                if let sourceName = workout.sourceName {
                    Text(sourceName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(workout.startAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let distance = workout.totalDistance {
                Text(String(format: "%.2f 公里", distance / 1000))
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct StatusDot: View {
    let state: String
    let label: String
    
    var color: Color {
        switch state {
        case "ok": return .green
        case "warn": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

