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
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(routines) { routine in
                    NavigationLink(destination: RoutineDetailView(routine: routine)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(routine.name)
                                .font(.headline)
                            if let exercises = routine.exercises, !exercises.isEmpty {
                                Text("\(exercises.count) exercises")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteRoutines)
            }
            .navigationTitle("Routines")
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
    
    private func deleteRoutines(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(routines[index])
            }
        }
    }
}

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var routine: Routine
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var showingAddExercise = false
    
    var body: some View {
        Form {
            Section("Routine Info") {
                TextField("Name", text: $routine.name)
            }
            
            Section("Exercises") {
                if let routineExercises = routine.exercises?.sorted(by: { $0.order < $1.order }) {
                    ForEach(routineExercises) { routineExercise in
                        NavigationLink(destination: RoutineExerciseEditView(routineExercise: routineExercise)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(routineExercise.exercise?.name ?? "Unknown")
                                    .font(.headline)
                                Text("\(routineExercise.targetSets) sets • \(routineExercise.restSecondsDefault)s rest")
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
            .navigationTitle("New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
                Picker("Exercise", selection: $selectedExercise) {
                    Text("Select Exercise").tag(nil as Exercise?)
                    ForEach(availableExercises) { exercise in
                        Text(exercise.name).tag(exercise as Exercise?)
                    }
                }
                
                Stepper("Target Sets: \(targetSets)", value: $targetSets, in: 1...10)
                Stepper("Rest (seconds): \(restSeconds)", value: $restSeconds, in: 0...300, step: 15)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
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
            Section("Exercise") {
                Text(routineExercise.exercise?.name ?? "Unknown")
            }
            
            Section("Configuration") {
                Stepper("Target Sets: \(routineExercise.targetSets)", value: $routineExercise.targetSets, in: 1...10)
                Stepper("Rest (seconds): \(routineExercise.restSecondsDefault)", value: $routineExercise.restSecondsDefault, in: 0...300, step: 15)
            }
        }
        .navigationTitle("Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    RoutinesView()
        .modelContainer(for: [Routine.self, Exercise.self], inMemory: true)
}

