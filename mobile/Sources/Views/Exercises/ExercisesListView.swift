import SwiftUI

struct ExercisesListView: View {
    @StateObject private var repository = WorkoutRepository.shared
    @State private var searchText = ""
    @State private var showCreator = false
    @State private var editingExercise: Exercise?
    @State private var errorMessage: String?

    private var filteredExercises: [Exercise] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return repository.exercises }
        return repository.exercises.filter { exercise in
            exercise.name.localizedCaseInsensitiveContains(trimmed) ||
                muscleGroupsDisplayName(exercise.muscleGroups).localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        List {
            ForEach(filteredExercises) { exercise in
                Button {
                    editingExercise = exercise
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(exerciseTypeEmoji(workoutType: exercise.workoutType, weightType: exercise.weightType))
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            let muscleEmojiSummary = muscleGroupEmojiSummary(exercise.muscleGroups)
                            HStack {
                                Text(exercise.name)
                                    .foregroundStyle(.primary)
                                if !muscleEmojiSummary.isEmpty {
                                    Text(muscleEmojiSummary)
                                        .font(.caption)
                                }
                                Spacer()
                                if exercise.isSystem {
                                    Text("System")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                            Text(weightTypeDisplayName(exercise.weightType))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if exercise.muscleGroups != 0 {
                                Text(muscleGroupsDisplayName(exercise.muscleGroups))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if exercise.warmupSets > 0 {
                                Text("\(exercise.warmupSets) warm-up set\(exercise.warmupSets == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        editingExercise = exercise
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(AppTheme.gymboBlue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !exercise.isSystem {
                        Button(role: .destructive) {
                            Task {
                                do {
                                    try await repository.deleteExercise(id: exercise.id)
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .appListContainer()
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search exercises"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreator = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreator) {
            NavigationStack {
                ExerciseCreatorView()
            }
        }
        .sheet(item: $editingExercise) { exercise in
            NavigationStack {
                ExerciseCreatorView(editingExercise: exercise)
            }
        }
        .alert("Exercise Action Failed", isPresented: Binding(get: {
            errorMessage != nil
        }, set: { isPresented in
            if !isPresented { errorMessage = nil }
        })) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Unknown error.")
        }
    }
}
