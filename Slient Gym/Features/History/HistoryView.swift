//
//  HistoryView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import SwiftData

enum HistoryFilter: String, CaseIterable {
    case all = "All"
    case strength = "Strength"
    case cardio = "Cardio"
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \ExternalWorkout.startAt, order: .reverse) private var externalWorkouts: [ExternalWorkout]
    @State private var selectedFilter: HistoryFilter = .all
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(HistoryFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                List {
                    switch selectedFilter {
                    case .all:
                        strengthSection
                        cardioSection
                    case .strength:
                        strengthSection
                    case .cardio:
                        cardioSection
                    }
                }
            }
            .navigationTitle("History")
        }
    }
    
    private var strengthSection: some View {
        Section("Strength Training") {
            ForEach(filteredSessions) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    SessionRowView(session: session)
                }
            }
        }
    }
    
    private var cardioSection: some View {
        Section("Cardio (Health Import)") {
            ForEach(externalWorkouts) { workout in
                ExternalWorkoutRowView(workout: workout)
            }
        }
    }
    
    private var filteredSessions: [Session] {
        sessions
    }
}

struct SessionRowView: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.routine?.name ?? "Unknown Routine")
                    .font(.headline)
                Spacer()
                if session.healthWorkoutUUID != nil {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                if session.calendarEventId != nil {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            
            Text(session.startAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let duration = session.duration {
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let exercises = session.exercises, !exercises.isEmpty {
                Text("\(exercises.count) exercises")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SessionDetailView: View {
    let session: Session
    
    var body: some View {
        List {
            Section("Session Info") {
                HStack {
                    Text("Routine")
                    Spacer()
                    Text(session.routine?.name ?? "Unknown")
                }
                HStack {
                    Text("Start")
                    Spacer()
                    Text(session.startAt, style: .date)
                }
                if let endAt = session.endAt {
                    HStack {
                        Text("End")
                        Spacer()
                        Text(endAt, style: .date)
                    }
                }
                if let duration = session.duration {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formatDuration(duration))
                    }
                }
                if session.calendarEventId != nil {
                    HStack {
                        Text("Calendar")
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text("已添加")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section("Exercises") {
                if let exercises = session.exercises?.sorted(by: { $0.order < $1.order }) {
                    ForEach(exercises) { sessionExercise in
                        ExerciseDetailSection(sessionExercise: sessionExercise)
                    }
                }
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ExerciseDetailSection: View {
    let sessionExercise: SessionExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sessionExercise.exercise?.name ?? "Unknown")
                .font(.headline)
            
            if let sets = sessionExercise.sets?.sorted(by: { $0.setIndex < $1.setIndex }) {
                ForEach(sets) { set in
                    HStack {
                        Text("Set \(set.setIndex + 1)")
                        Spacer()
                        Text("\(set.reps) reps")
                        Text("RIR: \(set.rir)")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExternalWorkoutRowView: View {
    let workout: ExternalWorkout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Running")
                    .font(.headline)
                Spacer()
                if let sourceName = workout.sourceName {
                    Text(sourceName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(workout.startAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                if let distance = workout.totalDistance {
                    Text(String(format: "%.2f km", distance / 1000))
                        .font(.caption)
                }
                Text(formatDuration(workout.duration))
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Session.self, ExternalWorkout.self], inMemory: true)
}

