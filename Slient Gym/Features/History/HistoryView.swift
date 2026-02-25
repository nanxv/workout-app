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
#endif

enum HistoryFilter: String, CaseIterable {
    case all = "全部"
    case strength = "力量"
    case cardio = "有氧"
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \ExternalWorkout.startAt, order: .reverse) private var externalWorkouts: [ExternalWorkout]
    @Query(sort: \Routine.name) private var routines: [Routine]
    @State private var selectedFilter: HistoryFilter = .all
    @StateObject private var importManager = HealthImportManager.shared
    @State private var isImporting = false
    @State private var showNRCGuide = false
    @State private var searchText = ""
    @State private var routineFilterId: UUID?
    @State private var dateRange: DateRange = .week
    @State private var calendarMonth = Date()
    @State private var selectedDay: Date?
    @State private var deleteCandidate: Session?
    
    let selectedRoutineId: UUID?
    
    init(selectedRoutineId: UUID? = nil) {
        self.selectedRoutineId = selectedRoutineId
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(HistoryFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 4)
                
                List {
                    summarySection
                    calendarSection
                    
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
                .listStyle(.plain)
                .scrollIndicators(.hidden)
            }
            .navigationTitle("历史")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .animation(.easeInOut(duration: 0.25), value: selectedFilter)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("时间范围", selection: $dateRange) {
                            ForEach(DateRange.allCases, id: \.self) { range in
                                Text(range.title).tag(range)
                            }
                        }
                        
                        Picker("计划", selection: $routineFilterId) {
                            Text("全部计划").tag(UUID?.none)
                            ForEach(routines) { routine in
                                Text(routine.name).tag(Optional(routine.id))
                            }
                        }
                        
                        Divider()
                        
                        Button(action: {
                            Task {
                                await importRunningWorkouts()
                            }
                        }) {
                            Label("导入跑步记录", systemImage: "arrow.down.circle")
                        }
                        .disabled(isImporting)
                        
                        Button(action: {
                            showNRCGuide = true
                        }) {
                            Label("NRC 设置指南", systemImage: "questionmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showNRCGuide) {
                NRCSetupGuideView()
            }
            .alert("删除记录", isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            )) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let session = deleteCandidate {
                        modelContext.delete(session)
                        try? modelContext.save()
                        deleteCandidate = nil
                    }
                }
            } message: {
                Text("确认删除这条训练记录？此操作不可撤销。")
            }
            .onAppear {
                if routineFilterId == nil {
                    routineFilterId = selectedRoutineId
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
        Section("力量") {
            ForEach(filteredSessions) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    SessionRowView(session: session)
                }
                .contextMenu {
                    Button("复制摘要") {
                        copySummary(for: session)
                    }
                    Button("删除记录", role: .destructive) {
                        deleteCandidate = session
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteCandidate = session
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private var cardioSection: some View {
        Section("有氧") {
            if filteredExternalWorkouts.isEmpty {
                Button("导入跑步记录") {
                    Task {
                        await importRunningWorkouts()
                    }
                }
                .disabled(isImporting)
            } else {
                ForEach(filteredExternalWorkouts) { workout in
                    ExternalWorkoutRowView(workout: workout)
                }
            }
        }
    }
    
    private var filteredSessions: [Session] {
        let routineId = routineFilterId ?? selectedRoutineId
        let dateFiltered = sessions.filter { session in
            dateRange.contains(session.startAt)
        }
        let routineFiltered = routineId == nil
            ? dateFiltered
            : dateFiltered.filter { $0.routine?.id == routineId }
        let dayFiltered = selectedDay.map { selected in
            routineFiltered.filter { Calendar.current.isDate($0.startAt, inSameDayAs: selected) }
        } ?? routineFiltered
        if searchText.isEmpty {
            return dayFiltered
        }
        return dayFiltered.filter { session in
            session.routineNameSnapshot.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var summarySection: some View {
        Section("概览") {
            let summary = summaryForCurrentFilters()
            LabeledContent("训练次数", value: "\(summary.strengthSessions) 次")
            LabeledContent("训练时长", value: "\(summary.strengthMinutes) 分钟")
            if summary.totalSets > 0 || summary.totalReps > 0 {
                LabeledContent("总量", value: "组 \(summary.totalSets) · 次 \(summary.totalReps)")
            }
            if summary.cardioMinutes > 0 {
                LabeledContent("有氧时长", value: "\(summary.cardioMinutes) 分钟")
            }
            if summary.totalDistance > 0 {
                LabeledContent("有氧距离", value: "\(String(format: "%.2f", summary.totalDistance)) 公里")
            }
        }
    }

    private var calendarSection: some View {
        Section("日历") {
            MonthCalendarView(
                month: $calendarMonth,
                selectedDay: $selectedDay,
                sessionDates: filteredSessions.map { $0.startAt },
                workoutDates: filteredExternalWorkouts.map { $0.startAt }
            )
        }
    }

    private var filteredExternalWorkouts: [ExternalWorkout] {
        externalWorkouts.filter { workout in
            dateRange.contains(workout.startAt)
        }
    }

    private func summaryForCurrentFilters() -> (strengthSessions: Int, strengthMinutes: Int, totalSets: Int, totalReps: Int, cardioMinutes: Int, totalDistance: Double) {
        let strengthSessions = filteredSessions.count
        let strengthMinutes = filteredSessions.compactMap { $0.duration }.reduce(0) { $0 + Int($1) / 60 }
        let (totalSets, totalReps) = aggregateStats(for: filteredSessions)
        let cardioMinutes = Int(filteredExternalWorkouts.reduce(0) { $0 + $1.duration }) / 60
        let totalDistance = filteredExternalWorkouts.compactMap { $0.totalDistance }.reduce(0, +) / 1000.0
        return (strengthSessions, strengthMinutes, totalSets, totalReps, cardioMinutes, totalDistance)
    }

    private func aggregateStats(for sessions: [Session]) -> (Int, Int) {
        var sets = 0
        var reps = 0
        for session in sessions {
            guard let exercises = session.exercises else { continue }
            for exercise in exercises {
                guard let entries = exercise.sets else { continue }
                sets += entries.count
                reps += entries.reduce(0) { $0 + $1.reps }
            }
        }
        return (sets, reps)
    }

    private func copySummary(for session: Session) {
        #if os(iOS)
        let durationText = formatDuration(session.duration)
        let summary = "\(session.routineNameSnapshot) · \(session.startAt.formatted(date: .abbreviated, time: .omitted)) · \(durationText)"
        UIPasteboard.general.string = summary
        #endif
    }

    private func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration else { return "—" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    }


struct SessionRowView: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(session.routineNameSnapshot)
                    .font(.headline)
                Spacer()
                if let duration = session.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text(session.startAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            if let stats = statsLine {
                Text(stats)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var statsLine: String? {
        guard let exercises = session.exercises else { return nil }
        var sets = 0
        var reps = 0
        for exercise in exercises {
            guard let entries = exercise.sets else { continue }
            sets += entries.count
            reps += entries.reduce(0) { $0 + $1.reps }
        }
        if sets == 0 && reps == 0 {
            return nil
        }
        return "组 \(sets) · 次 \(reps)"
    }
}

private enum DateRange: String, CaseIterable {
    case week
    case month
    case all
    
    var title: String {
        switch self {
        case .week:
            return "近 7 天"
        case .month:
            return "近 30 天"
        case .all:
            return "全部"
        }
    }
    
    func contains(_ date: Date) -> Bool {
        switch self {
        case .all:
            return true
        case .week:
            return date >= Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        case .month:
            return date >= Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        }
    }
}

private struct MonthCalendarView: View {
    @Binding var month: Date
    @Binding var selectedDay: Date?
    let sessionDates: [Date]
    let workoutDates: [Date]
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(monthTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                ForEach(daysInMonth, id: \.self) { date in
                    if let date {
                        Button(action: {
                            if selectedDay != nil && Calendar.current.isDate(selectedDay!, inSameDayAs: date) {
                                selectedDay = nil
                            } else {
                                selectedDay = date
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.caption)
                                    .foregroundColor(isSelected(date) ? .white : .primary)
                                    .frame(width: 24, height: 24)
                                    .background(isSelected(date) ? Color.primary : Color.clear)
                                    .clipShape(Circle())
                                
                                HStack(spacing: 3) {
                                    if hasSession(on: date) {
                                        Circle()
                                            .fill(Color.primary)
                                            .frame(width: 4, height: 4)
                                    }
                                    if hasWorkout(on: date) {
                                        Circle()
                                            .fill(Color.secondary)
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var monthTitle: String {
        month.formatted(.dateTime.year().month())
    }
    
    private var weekdaySymbols: [String] {
        Calendar.current.shortWeekdaySymbols
    }
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: month),
              let firstWeekday = Calendar.current.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }
        
        let startOffset = (firstWeekday + 6) % 7
        let daysCount = Calendar.current.range(of: .day, in: .month, for: month)?.count ?? 0
        var days: [Date?] = Array(repeating: nil, count: startOffset)
        
        for day in 0..<daysCount {
            if let date = Calendar.current.date(byAdding: .day, value: day, to: monthInterval.start) {
                days.append(date)
            }
        }
        
        let remainder = days.count % 7
        if remainder != 0 {
            days.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return days
    }
    
    private func isSelected(_ date: Date) -> Bool {
        guard let selectedDay else { return false }
        return Calendar.current.isDate(selectedDay, inSameDayAs: date)
    }
    
    private func hasSession(on date: Date) -> Bool {
        sessionDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
    }
    
    private func hasWorkout(on date: Date) -> Bool {
        workoutDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
    }
}

struct SessionDetailView: View {
    let session: Session
    @Environment(\.modelContext) private var modelContext
    #if os(iOS)
    @StateObject private var calendarManager = CalendarManager.shared
    @State private var showPermissionGuide: PermissionType?
    @State private var showRetryAlert = false
    #endif
    
    var body: some View {
        List {
            Section("训练信息") {
                HStack {
                    Text("训练计划")
                    Spacer()
                    Text(session.routineNameSnapshot)
                }
                HStack {
                    Text("开始时间")
                    Spacer()
                    Text(session.startAt, style: .date)
                }
                if let endAt = session.endAt {
                    HStack {
                        Text("结束时间")
                        Spacer()
                        Text(endAt, style: .date)
                    }
                }
                if let duration = session.duration {
                    HStack {
                        Text("训练时长")
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
                            Text("（训练时 Watch 未连接）")
                                .font(.caption2)
                                .foregroundColor(.secondary)
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
                            Button("添加") {
                                retryCalendarAdd()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            #endif
                        }
                    }
                }
            }
            
            Section("动作") {
                if let exercises = session.exercises?.sorted(by: { $0.order < $1.order }) {
                    ForEach(exercises) { sessionExercise in
                        ExerciseDetailSection(sessionExercise: sessionExercise)
                    }
                }
            }
        }
        .navigationTitle("训练详情")
        .navigationBarTitleDisplayMode(.inline)
        #if os(iOS)
        .sheet(item: $showPermissionGuide) { permissionType in
            PermissionGuideView(permissionType: permissionType)
        }
        #endif
    }
    
    #if os(iOS)
    private func retryCalendarAdd() {
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
            } else {
                // 保存成功，更新 session
                session.calendarEventId = eventId
                try? modelContext.save()
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
            Text(sessionExercise.exercise?.name ?? "未知")
                .font(.headline)
            
            if let sets = sessionExercise.sets?.sorted(by: { $0.setIndex < $1.setIndex }) {
                ForEach(sets) { set in
                    HStack {
                        Text("第 \(set.setIndex + 1) 组")
                        Spacer()
                        Text("\(set.reps) 次")
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
                Text("跑步")
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

