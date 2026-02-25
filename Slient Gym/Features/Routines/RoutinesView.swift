//
//  RoutinesView.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.name) private var routines: [Routine]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var showingAddRoutine = false
    @State private var selectedRoutine: Routine?
    @State private var cachedLatestSessions: [UUID: Session] = [:]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(routines) { routine in
                    NavigationLink(destination: RoutineDetailView(routine: routine)) {
                        RoutineRow(routine: routine, latestSession: cachedLatestSessions[routine.id])
                    }
                    .onAppear {
                        loadLatestSession(for: routine.id)
                    }
                }
                .onDelete(perform: deleteRoutines)
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .navigationTitle("计划")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddRoutine = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRoutine) {
                AddRoutineView()
            }
        }
    }
    
    private func loadLatestSession(for routineId: UUID) {
        if let session = RoutineHistoryHelper.latestSession(for: routineId, context: modelContext) {
            cachedLatestSessions[routineId] = session
        }
    }
    
    private func deleteRoutines(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(routines[index])
            }
        }
    }
}

private struct RoutineRow: View {
    let routine: Routine
    let latestSession: Session?
    
    var body: some View {
        Text(routine.name)
            .font(.headline)
            .padding(.vertical, 6)
    }
}

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var routine: Routine
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var showingAddExercise = false
    
    var body: some View {
        Form {
            Section("训练计划信息") {
                TextField("名称", text: $routine.name)
            }
            
            Section("动作") {
                if let routineExercises = routine.exercises?.sorted(by: { $0.order < $1.order }) {
                    ForEach(routineExercises) { routineExercise in
                        NavigationLink(destination: RoutineExerciseEditView(routineExercise: routineExercise)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(routineExercise.exercise?.name ?? "Unknown")
                                    .font(.headline)
                                Text("\(routineExercise.targetSets) 组 • 休息 \(routineExercise.restSecondsDefault) 秒")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: { offsets in
                        deleteExercises(offsets: offsets, from: routineExercises)
                    })
                }
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddExercise = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseToRoutineView(routine: routine, availableExercises: exercises)
        }
    }
    
    private func deleteExercises(offsets: IndexSet, from routineExercises: [RoutineExercise]) {
        withAnimation {
            for index in offsets {
                modelContext.delete(routineExercises[index])
            }
        }
    }
}

struct AddRoutineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Routine Name", text: $name)
            }
            .navigationTitle("新建训练计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let routine = Routine(name: name)
                        modelContext.insert(routine)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct AddExerciseToRoutineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var routine: Routine
    let availableExercises: [Exercise]
    @State private var selectedExercise: Exercise?
    @State private var targetSets: Int = 3
    @State private var restSeconds: Int = 90
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("动作", selection: $selectedExercise) {
                    Text("选择动作").tag(nil as Exercise?)
                    ForEach(availableExercises) { exercise in
                        Text(exercise.name).tag(exercise as Exercise?)
                    }
                }
                
                Stepper("目标组数: \(targetSets)", value: $targetSets, in: 1...10)
                Stepper("休息时间（秒）: \(restSeconds)", value: $restSeconds, in: 0...300, step: 15)
            }
            .navigationTitle("添加动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        guard let exercise = selectedExercise else { return }
                        let order = routine.exercises?.count ?? 0
                        let routineExercise = RoutineExercise(
                            routine: routine,
                            exercise: exercise,
                            order: order,
                            targetSets: targetSets,
                            restSecondsDefault: restSeconds
                        )
                        modelContext.insert(routineExercise)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(selectedExercise == nil)
                }
            }
        }
    }
}

struct RoutineExerciseEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var routineExercise: RoutineExercise
    
    var body: some View {
        Form {
            Section("动作") {
                Text(routineExercise.exercise?.name ?? "未知")
            }
            
            Section("配置") {
                Stepper("目标组数: \(routineExercise.targetSets)", value: $routineExercise.targetSets, in: 1...10)
                Stepper("休息时间（秒）: \(routineExercise.restSecondsDefault)", value: $routineExercise.restSecondsDefault, in: 0...300, step: 15)
            }
        }
        .navigationTitle("编辑动作")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    RoutinesView()
        .modelContainer(for: [Routine.self, Exercise.self], inMemory: true)
}

