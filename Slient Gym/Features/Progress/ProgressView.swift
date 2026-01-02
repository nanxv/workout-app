//
//  ProgressView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import SwiftData

struct ProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \ExternalWorkout.startAt, order: .reverse) private var externalWorkouts: [ExternalWorkout]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    weeklySummarySection
                    exerciseTrendsSection
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }
    
    private var weeklySummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.title2)
                .bold()
            
            let weekStats = calculateWeekStats()
            
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    StatCard(title: "Strength", value: "\(weekStats.strengthMinutes) min", icon: "dumbbell.fill")
                    StatCard(title: "Cardio", value: "\(weekStats.cardioMinutes) min", icon: "figure.run")
                    StatCard(title: "Sessions", value: "\(weekStats.totalSessions)", icon: "calendar")
                }
                
                if weekStats.totalDistance > 0 {
                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundColor(.blue)
                        Text("Total Distance: \(String(format: "%.2f", weekStats.totalDistance)) km")
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var exerciseTrendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Trends")
                .font(.title2)
                .bold()
            
            // Group exercises and show recent performance
            let exerciseStats = calculateExerciseStats()
            
            ForEach(Array(exerciseStats.keys.sorted()), id: \.self) { exerciseName in
                if let stats = exerciseStats[exerciseName] {
                    ExerciseTrendCard(exerciseName: exerciseName, stats: stats)
                }
            }
        }
    }
    
    private func calculateWeekStats() -> (strengthMinutes: Int, cardioMinutes: Int, totalSessions: Int, totalDistance: Double) {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(byAdding: .day, value: -7, to: now) else {
            return (0, 0, 0, 0)
        }
        
        let weekSessions = sessions.filter { $0.startAt >= weekStart }
        let weekWorkouts = externalWorkouts.filter { $0.startAt >= weekStart }
        
        let strengthMinutes = weekSessions.compactMap { $0.duration }.reduce(0) { $0 + Int($1) / 60 }
        let cardioMinutes = Int(weekWorkouts.reduce(0) { $0 + $1.duration }) / 60
        let totalSessions = weekSessions.count + weekWorkouts.count
        let totalDistance = weekWorkouts.compactMap { $0.totalDistance }.reduce(0, +) / 1000.0 // Convert to km
        
        return (strengthMinutes, cardioMinutes, totalSessions, totalDistance)
    }
    
    private func calculateExerciseStats() -> [String: (bestReps: Int, totalReps: Int, avgRIR: Double)] {
        var stats: [String: (bestReps: Int, totalReps: Int, avgRIR: Double, count: Int, rirSum: Int)] = [:]
        
        for session in sessions {
            guard let exercises = session.exercises else { continue }
            for sessionExercise in exercises {
                guard let exerciseName = sessionExercise.exercise?.name,
                      let sets = sessionExercise.sets else { continue }
                
                let reps = sets.map { $0.reps }
                let bestReps = reps.max() ?? 0
                let totalReps = reps.reduce(0, +)
                let rirSum = sets.map { $0.rir }.reduce(0, +)
                
                if let existing = stats[exerciseName] {
                    stats[exerciseName] = (
                        bestReps: max(existing.bestReps, bestReps),
                        totalReps: existing.totalReps + totalReps,
                        avgRIR: 0,
                        count: existing.count + sets.count,
                        rirSum: existing.rirSum + rirSum
                    )
                } else {
                    stats[exerciseName] = (
                        bestReps: bestReps,
                        totalReps: totalReps,
                        avgRIR: 0,
                        count: sets.count,
                        rirSum: rirSum
                    )
                }
            }
        }
        
        return stats.mapValues { (bestReps: $0.bestReps, totalReps: $0.totalReps, avgRIR: Double($0.rirSum) / Double($0.count)) }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(value)
                .font(.title3)
                .bold()
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

struct ExerciseTrendCard: View {
    let exerciseName: String
    let stats: (bestReps: Int, totalReps: Int, avgRIR: Double)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exerciseName)
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Best Reps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.bestReps)")
                        .font(.title3)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Total Reps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.totalReps)")
                        .font(.title3)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Avg RIR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", stats.avgRIR))
                        .font(.title3)
                        .bold()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    ProgressView()
        .modelContainer(for: [Session.self, ExternalWorkout.self], inMemory: true)
}

