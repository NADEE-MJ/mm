import SwiftUI

struct TemplateDetailView: View {
    let template: WorkoutTemplate
    @StateObject private var repository = WorkoutRepository.shared
    @State private var editingSets: [String: Int] = [:]  // templateExerciseId → draft sets count
    @State private var savingId: String?
    @State private var isAddingExercise = false
    @State private var showExercisePicker = false
    @State private var errorMessage: String?

    private var currentTemplate: WorkoutTemplate {
        repository.templates.first(where: { $0.id == template.id }) ?? template
    }

    private var addableExercises: [Exercise] {
        let usedIds = Set(currentTemplate.exercises.map(\.exerciseId))
        return repository.exercises.filter { !usedIds.contains($0.id) }
    }

    var body: some View {
        List {
            Section("Template") {
                Text(currentTemplate.name)
                if let description = currentTemplate.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if currentTemplate.isSystem {
                    Text("System template")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }

            Section("Exercises") {
                ForEach(currentTemplate.exercises.sorted(by: { $0.position < $1.position })) { exercise in
                    ExerciseSetRow(
                        exercise: exercise,
                        exerciseName: repository.exerciseName(for: exercise.exerciseId),
                        isSaving: savingId == exercise.id,
                        canEdit: !currentTemplate.isSystem,
                        draftSets: Binding(
                            get: { editingSets[exercise.id] ?? (exercise.defaultSets ?? 3) },
                            set: { editingSets[exercise.id] = $0 }
                        ),
                        onSave: {
                            Task { await saveSets(for: exercise) }
                        }
                    )
                }

                if !currentTemplate.isSystem {
                    Button {
                        showExercisePicker = true
                    } label: {
                        if isAddingExercise {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Adding Exercise...")
                            }
                        } else {
                            Label("Add Exercise", systemImage: "plus.circle")
                        }
                    }
                    .disabled(addableExercises.isEmpty || isAddingExercise)
                    .foregroundStyle(AppTheme.gymboBlue)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .appListContainer()
        .navigationTitle("Template")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExercisePicker) {
            NavigationStack {
                TemplateExercisePickerSheet(exercises: addableExercises) { exercise in
                    Task { await addExerciseToTemplate(exercise) }
                }
            }
        }
    }

    private func saveSets(for exercise: TemplateExercise) async {
        let newSets = editingSets[exercise.id] ?? (exercise.defaultSets ?? 3)
        savingId = exercise.id
        defer { savingId = nil }
        do {
            try await repository.updateTemplateExerciseSets(
                templateId: currentTemplate.id,
                templateExerciseId: exercise.id,
                defaultSets: newSets
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addExerciseToTemplate(_ exercise: Exercise) async {
        isAddingExercise = true
        defer { isAddingExercise = false }
        do {
            try await repository.addExerciseToTemplate(
                templateId: currentTemplate.id,
                exerciseId: exercise.id
            )
            showExercisePicker = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TemplateExercisePickerSheet: View {
    let exercises: [Exercise]
    let onPick: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return exercises }
        return exercises.filter { exercise in
            exercise.name.localizedCaseInsensitiveContains(trimmed) ||
                muscleGroupsDisplayName(exercise.muscleGroups).localizedCaseInsensitiveContains(trimmed) ||
                weightTypeDisplayName(exercise.weightType).localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        List {
            if exercises.isEmpty {
                Text("All exercises are already in this template.")
                    .foregroundStyle(.secondary)
            } else {
                if filteredExercises.isEmpty {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            onPick(exercise)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Text(exerciseTypeEmoji(workoutType: exercise.workoutType, weightType: exercise.weightType))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                    Text(weightTypeDisplayName(exercise.weightType))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appListContainer()
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search exercises"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct ExerciseSetRow: View {
    let exercise: TemplateExercise
    let exerciseName: String
    let isSaving: Bool
    let canEdit: Bool
    @Binding var draftSets: Int
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exerciseName)
                .font(.body)
            HStack(spacing: 12) {
                if canEdit {
                    Stepper(
                        value: $draftSets,
                        in: 1...20,
                        onEditingChanged: { editing in
                            if !editing { onSave() }
                        }
                    ) {
                        if isSaving {
                            HStack(spacing: 4) {
                                ProgressView().scaleEffect(0.7)
                                Text("\(draftSets) set\(draftSets == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("\(draftSets) set\(draftSets == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("\(exercise.defaultSets ?? 0) set\(exercise.defaultSets == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let reps = exercise.defaultReps, reps > 0 {
                    Text("× \(reps) reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
