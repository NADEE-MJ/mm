import SwiftUI

struct TemplateBuilderView: View {
    @State private var name = ""
    @State private var workoutTypeId: String?
    @State private var selectedExerciseIds: [String] = []
    @State private var statusMessage: String?

    @StateObject private var repository = WorkoutRepository.shared

    var body: some View {
        Form {
            Section("Template") {
                TextField("Name", text: $name)

                Picker("Workout Type", selection: $workoutTypeId) {
                    Text("None").tag(Optional<String>.none)
                    ForEach(repository.workoutTypes) { type in
                        Text(type.name).tag(Optional(type.id))
                    }
                }
            }

            Section("Exercises") {
                ForEach(repository.exercises) { exercise in
                    Button {
                        if selectedExerciseIds.contains(exercise.id) {
                            selectedExerciseIds.removeAll { $0 == exercise.id }
                        } else {
                            selectedExerciseIds.append(exercise.id)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                Text(weightTypeDisplayName(exercise.weightType))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedExerciseIds.contains(exercise.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.gymboBlue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Button("Create Template") {
                    Task {
                        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            statusMessage = "Template name is required."
                            return
                        }

                        do {
                            try await repository.createTemplate(
                                name: name,
                                description: nil,
                                workoutTypeId: workoutTypeId,
                                exerciseIds: selectedExerciseIds
                            )
                            statusMessage = "Template created."
                            name = ""
                            selectedExerciseIds = []
                        } catch {
                            statusMessage = error.localizedDescription
                        }
                    }
                }
            }

            if let statusMessage {
                Section("Status") {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .appFormContainer()
        .navigationTitle("Template Builder")
    }
}
