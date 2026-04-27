import SwiftUI

struct ExerciseCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var repository = WorkoutRepository.shared

    /// When non-nil, we're editing an existing exercise.
    var editingExercise: Exercise?

    @State private var name = ""
    @State private var muscleGroups: Int = 0
    @State private var workoutType: Int? = nil
    @State private var weightType: Int = WeightType.rawWeight.rawValue
    @State private var allSetsSameWeight = true
    @State private var warmupSets = 1
    @State private var accessoryDraft = ""
    @State private var accessories: [String] = []
    @State private var descriptionText = ""
    @State private var videoURL = ""
    @State private var goalRepsMinText = ""
    @State private var goalRepsMaxText = ""
    @State private var showHighestSet = false
    @State private var trackHighestSet = false
    @State private var showOneRepMax = false
    @State private var trackOneRepMax = false
    @State private var statusMessage: String?
    @State private var isSaving = false

    private var isEditing: Bool { editingExercise != nil }
    private var editingId: String? { editingExercise?.id }

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $name)

                // Muscle groups multi-select
                NavigationLink {
                    MuscleGroupPickerView(selection: $muscleGroups)
                } label: {
                    HStack {
                        Text("Muscle Groups")
                        Spacer()
                        Text(muscleGroupsDisplayName(muscleGroups))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Picker("Workout Type", selection: $workoutType) {
                    Text("None").tag(Optional<Int>.none)
                    ForEach(ExerciseWorkoutType.allCases) { type in
                        Text(type.label).tag(Optional(type.rawValue))
                    }
                }

                Picker("Weight Type", selection: $weightType) {
                    ForEach(WeightType.allCases) { type in
                        Text(type.label).tag(type.rawValue)
                    }
                }
            }

            Section("Set Strategy") {
                Toggle("All sets same weight (no warm-ups)", isOn: $allSetsSameWeight)
                if !allSetsSameWeight {
                    Stepper("Warm-up sets: \(warmupSets)", value: $warmupSets, in: 0...12)
                }
            }

            Section("Tracking") {
                Toggle("Track Highest Set", isOn: $trackHighestSet)
                Toggle("Show Highest Set", isOn: $showHighestSet)
                Toggle("Track 1 Rep Max", isOn: $trackOneRepMax)
                Toggle("Show 1 Rep Max", isOn: $showOneRepMax)
            }

            Section("Goal Rep Range") {
                TextField("Min reps", text: $goalRepsMinText)
                    .keyboardType(.numberPad)
                TextField("Max reps", text: $goalRepsMaxText)
                    .keyboardType(.numberPad)
            }

            Section("Exercise Info") {
                TextField("Description", text: $descriptionText, axis: .vertical)
                    .lineLimit(3 ... 8)
                TextField("Video URL", text: $videoURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Accessories") {
                HStack(spacing: 8) {
                    TextField("Belt, Straps, etc.", text: $accessoryDraft)
                    Button("Add") { addAccessory() }
                        .buttonStyle(.bordered)
                }
                if accessories.isEmpty {
                    Text("No accessories configured.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(accessories, id: \.self) { accessory in
                        HStack {
                            Text(accessory)
                            Spacer()
                            Button(role: .destructive) {
                                accessories.removeAll { $0 == accessory }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(isEditing ? "Save Changes" : "Create Exercise")
                    }
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let statusMessage {
                Section("Status") {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Exercise" : "New Exercise")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear { populateFromExisting() }
    }

    private func populateFromExisting() {
        guard let ex = editingExercise else { return }
        name = ex.name
        muscleGroups = ex.muscleGroups
        workoutType = ex.workoutType
        weightType = ex.weightType
        allSetsSameWeight = ex.warmupSets == 0
        warmupSets = ex.warmupSets > 0 ? ex.warmupSets : 1
        accessories = ex.accessories
        descriptionText = ex.description ?? ""
        videoURL = ex.videoURL ?? ""
        goalRepsMinText = ex.goalRepsMin.map(String.init) ?? ""
        goalRepsMaxText = ex.goalRepsMax.map(String.init) ?? ""
        showHighestSet = ex.showHighestSet
        trackHighestSet = ex.trackHighestSet
        showOneRepMax = ex.showOneRepMax
        trackOneRepMax = ex.trackOneRepMax
    }

    private func addAccessory() {
        let trimmed = accessoryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if accessories.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            accessoryDraft = ""
            return
        }
        accessories.append(trimmed)
        accessoryDraft = ""
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let goalMin = parseOptionalInt(goalRepsMinText)
        let goalMax = parseOptionalInt(goalRepsMaxText)
        if (goalRepsMinText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && goalMin == nil) ||
            (goalRepsMaxText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && goalMax == nil) {
            statusMessage = "Goal reps must be whole numbers."
            return
        }
        if let goalMin, let goalMax, goalMin > goalMax {
            statusMessage = "Min reps cannot be greater than max reps."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            if isEditing, let id = editingId {
                try await repository.updateExercise(
                    id: id,
                    name: trimmedName,
                    muscleGroups: muscleGroups,
                    workoutType: workoutType,
                    weightType: weightType,
                    allSetsSameWeight: allSetsSameWeight,
                    warmupSets: warmupSets,
                    accessories: accessories,
                    description: normalizeOptionalText(descriptionText),
                    videoURL: normalizeOptionalText(videoURL),
                    goalRepsMin: goalMin,
                    goalRepsMax: goalMax,
                    showHighestSet: showHighestSet,
                    trackHighestSet: trackHighestSet,
                    highestSetWeight: editingExercise?.highestSetWeight,
                    highestSetReps: editingExercise?.highestSetReps,
                    showOneRepMax: showOneRepMax,
                    trackOneRepMax: trackOneRepMax,
                    oneRepMax: editingExercise?.oneRepMax
                )
            } else {
                try await repository.createExercise(
                    name: trimmedName,
                    muscleGroups: muscleGroups,
                    workoutType: workoutType,
                    weightType: weightType,
                    allSetsSameWeight: allSetsSameWeight,
                    warmupSets: warmupSets,
                    accessories: accessories,
                    description: normalizeOptionalText(descriptionText),
                    videoURL: normalizeOptionalText(videoURL),
                    goalRepsMin: goalMin,
                    goalRepsMax: goalMax,
                    showHighestSet: showHighestSet,
                    trackHighestSet: trackHighestSet,
                    showOneRepMax: showOneRepMax,
                    trackOneRepMax: trackOneRepMax
                )
            }
            dismiss()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func parseOptionalInt(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private func normalizeOptionalText(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Muscle Group Multi-Select Picker

struct MuscleGroupPickerView: View {
    @Binding var selection: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(MuscleGroup.allCases) { group in
                Button {
                    if selection & group.rawValue != 0 {
                        selection &= ~group.rawValue
                    } else {
                        selection |= group.rawValue
                    }
                } label: {
                    HStack {
                        Text(group.label)
                        Spacer()
                        if selection & group.rawValue != 0 {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Muscle Groups")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}
