//
//  HistoryView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import SwiftData
#if os(iOS)
import HealthKit
import UIKit
#endif

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
    @StateObject private var importManager = HealthImportManager.shared
    @State private var isImporting = false
    @State private var showNRCGuide = false
    @State private var showFirstTimeNRCGuide = false
    
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            Task {
                                await importRunningWorkouts()
                            }
                        }) {
                            Label("Import Running", systemImage: "arrow.down.circle")
                        }
                        .disabled(isImporting)
                        
                        Button(action: {
                            showNRCGuide = true
                        }) {
                            Label("NRC Setup Guide", systemImage: "questionmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showNRCGuide) {
                NRCSetupGuideView()
            }
            .sheet(isPresented: $showFirstTimeNRCGuide) {
                PermissionGuideView(permissionType: .nrc)
            }
            .onAppear {
                // 首次进入 Cardio 分段时显示引导
                if selectedFilter == .cardio && externalWorkouts.isEmpty {
                    // 检查是否已经显示过引导
                    let hasShownGuide = UserDefaults.standard.bool(forKey: "hasShownNRCGuide")
                    if !hasShownGuide {
                        showFirstTimeNRCGuide = true
                        UserDefaults.standard.set(true, forKey: "hasShownNRCGuide")
                    }
                }
            }
        }
    }
    
    private func importRunningWorkouts() async {
        isImporting = true
        let count = await importManager.importRunningWorkouts(days: 90, context: modelContext)
        isImporting = false
        print("Imported \(count) workouts")
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
                // 状态图标
                HStack(spacing: 8) {
                    if session.healthWorkoutUUID != nil {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Image(systemName: "heart.slash")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    if session.calendarEventId != nil {
                        Image(systemName: "calendar")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Image(systemName: "calendar.badge.minus")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
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
    @Environment(\.modelContext) private var modelContext
    @State private var showPermissionGuide: PermissionType?
    #if os(iOS)
    @StateObject private var calendarManager = CalendarManager.shared
    @StateObject private var watchLauncher = WatchWorkoutLauncher.shared
    #endif
    
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
                // HealthKit 同步状态
                HStack {
                    Text("HealthKit 同步")
                    Spacer()
                    if session.healthWorkoutUUID != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("已同步")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                Text("未同步")
                                    .foregroundColor(.secondary)
                            }
                            #if os(iOS)
                            Button("重试") {
                                retryHealthSync()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            #endif
                        }
                    }
                }
                
                // Calendar 状态
                HStack {
                    Text("日历事件")
                    Spacer()
                    if session.calendarEventId != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("已添加")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                Text("未添加")
                                    .foregroundColor(.secondary)
                            }
                            #if os(iOS)
                            Button("重试") {
                                retryCalendarAdd()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            #endif
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
        #if os(iOS)
        .sheet(item: $showPermissionGuide) { permissionType in
            PermissionGuideView(permissionType: permissionType)
        }
        #endif
    }
    
    #if os(iOS)
    private func retryHealthSync() {
        // 重试写入 HealthKit（通过 Watch）
        // 注意：这需要重新启动 workout，实际实现可能需要更复杂的逻辑
        watchLauncher.startWatchWorkout(sessionId: session.id) { success, error in
            if !success {
                showPermissionGuide = .healthKit
            }
        }
    }
    
    private func retryCalendarAdd() {
        // 获取当前视图控制器来展示日历编辑界面
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            showPermissionGuide = .calendar
            return
        }
        
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        
        calendarManager.createEventForSession(
            session: session,
            presentingViewController: topViewController
        ) { eventId in
            if eventId == nil {
                showPermissionGuide = .calendar
            }
        }
    }
    #endif
    
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
                    HStack(spacing: 4) {
                        if sourceName.contains("Nike") || sourceName.contains("NRC") {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                        Text(sourceName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(workout.startAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                if let distance = workout.totalDistance {
                    HStack(spacing: 4) {
                        Image(systemName: "map.fill")
                            .font(.caption2)
                        Text(String(format: "%.2f km", distance / 1000))
                            .font(.caption)
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text(formatDuration(workout.duration))
                        .font(.caption)
                }
                if let energy = workout.totalEnergy {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                        Text(String(format: "%.0f kcal", energy))
                            .font(.caption)
                    }
                }
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

