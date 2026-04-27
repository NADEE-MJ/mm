import SwiftUI

struct ExerciseSection: View {
    let session: WorkoutSession
    let exercise: SessionExercise
    let exerciseMeta: Exercise?

    @StateObject private var repository = WorkoutRepository.shared
    @State private var optionsSet: SessionSet?
    @State private var showExerciseInfo = false
    @State private var showExerciseSettings = false
    @State private var isExerciseExpanded = true

    var body: some View {
        Section {
            if isExerciseExpanded {
                ForEach(exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                    SetRowView(
                        set: set,
                        weightType: exerciseMeta?.weightType ?? WeightType.rawWeight.rawValue,
                        configuredWarmupSets: exerciseMeta?.warmupSets ?? 0,
                        barbellWeight: AuthManager.shared.currentUser?.barbellWeight ?? 45,
                        unitPreference: AuthManager.shared.currentUser?.unitPreference ?? "lbs"
                    ) { reps, weight, durationSecs, distance, isWarmup, usedAccessories, bandColor in
                        Task {
                            await repository.updateSet(
                                sessionId: session.id,
                                sessionExerciseId: exercise.id,
                                exerciseId: exercise.exerciseId,
                                setNumber: set.setNumber,
                                reps: reps,
                                weight: weight,
                                durationSecs: durationSecs,
                                distance: distance,
                                isWarmup: isWarmup,
                                usedAccessories: usedAccessories,
                                bandColor: bandColor
                            )
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            optionsSet = set
                        } label: {
                            Label("Options", systemImage: "slider.horizontal.3")
                        }
                        .tint(AppTheme.gymboBlue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                await repository.deleteSet(
                                    sessionId: session.id,
                                    sessionExerciseId: exercise.id,
                                    setId: set.id
                                )
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }

                Button {
                    Task {
                        await repository.addSet(
                            sessionId: session.id,
                            sessionExerciseId: exercise.id,
                            exerciseId: exercise.exerciseId
                        )
                    }
                } label: {
                    Label("Add Set", systemImage: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.gymboBlue)
            } else {
                HStack {
                    Text(collapsedSummary)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 6)
            }
        } header: {
            exerciseHeader
        }
        .sheet(item: $optionsSet) { set in
            SetOptionsSheet(
                session: session,
                exercise: exercise,
                set: set,
                accessories: exerciseMeta?.accessories ?? []
            )
        }
        .sheet(isPresented: $showExerciseInfo) {
            ExerciseInfoSheet(exercise: exerciseMeta)
        }
        .sheet(isPresented: $showExerciseSettings) {
            NavigationStack {
                if let exerciseMeta {
                    ExerciseCreatorView(editingExercise: exerciseMeta)
                } else {
                    Text("Exercise not found.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var exerciseHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exerciseMeta?.name ?? exercise.exerciseId)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(weightTypeDisplayName(exerciseMeta?.weightType ?? WeightType.rawWeight.rawValue))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                if let summary = performanceSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.gymboBlue)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExerciseExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExerciseExpanded ? "chevron.down.circle" : "chevron.right.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)

                Button {
                    showExerciseInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)

                Button {
                    showExerciseSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
                .disabled(exerciseMeta == nil)
            }
            .font(.headline)
        }
    }

    private var collapsedSummary: String {
        let totalSets = exercise.sets.count
        let completedSets = exercise.sets.filter(\.completed).count
        return "\(completedSets)/\(totalSets) sets completed"
    }

    private var performanceSummary: String? {
        guard let exerciseMeta else { return nil }
        let unit = AuthManager.shared.currentUser?.unitPreference ?? "lbs"
        var parts: [String] = []

        if exerciseMeta.showHighestSet, let weight = exerciseMeta.highestSetWeight {
            let reps = exerciseMeta.highestSetReps ?? 0
            parts.append("Highest \(formatWeight(weight)) \(unit) x \(reps)")
        }

        if exerciseMeta.showOneRepMax, let oneRepMax = exerciseMeta.oneRepMax {
            parts.append("1RM \(formatWeight(oneRepMax)) \(unit)")
        }

        if let goalMin = exerciseMeta.goalRepsMin, let goalMax = exerciseMeta.goalRepsMax {
            parts.append("Goal \(goalMin)-\(goalMax) reps")
        } else if let goalMin = exerciseMeta.goalRepsMin {
            parts.append("Goal \(goalMin)+ reps")
        } else if let goalMax = exerciseMeta.goalRepsMax {
            parts.append("Goal up to \(goalMax) reps")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func formatWeight(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

private struct ExerciseInfoSheet: View {
    let exercise: Exercise?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("How To") {
                    if let description = exercise?.description?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !description.isEmpty {
                        Text(description)
                    } else {
                        Text("No instructions added yet.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Video") {
                    if let videoURL = exercise?.videoURL,
                       let url = URL(string: videoURL),
                       !videoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Link(destination: url) {
                            Label("Open Demo Video", systemImage: "play.rectangle")
                        }
                    } else {
                        Text("No video link added yet.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(exercise?.name ?? "Exercise Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SetOptionsSheet: View {
    let session: WorkoutSession
    let exercise: SessionExercise
    let set: SessionSet
    let accessories: [String]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var repository = WorkoutRepository.shared
    @State private var isWarmup: Bool
    @State private var usedAccessories: [String]

    init(session: WorkoutSession, exercise: SessionExercise, set: SessionSet, accessories: [String]) {
        self.session = session
        self.exercise = exercise
        self.set = set
        self.accessories = accessories
        _isWarmup = State(initialValue: set.isWarmup)
        _usedAccessories = State(initialValue: set.usedAccessories)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Set Options") {
                    Toggle("Warm-up Set", isOn: $isWarmup)
                        .onChange(of: isWarmup) { _, next in
                            persistOptions(isWarmup: next, usedAccessories: usedAccessories)
                        }
                }

                if !accessories.isEmpty {
                    Section("Accessories Used") {
                        ForEach(accessories, id: \.self) { accessory in
                            let selected = usedAccessories.contains(accessory)
                            Button {
                                var updated = usedAccessories
                                if selected {
                                    updated.removeAll { $0 == accessory }
                                } else {
                                    updated.append(accessory)
                                }
                                usedAccessories = updated
                                persistOptions(isWarmup: isWarmup, usedAccessories: updated)
                            } label: {
                                HStack {
                                    Text(accessory)
                                    Spacer()
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppTheme.gymboBlue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Set \(set.setNumber) Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func persistOptions(isWarmup: Bool, usedAccessories: [String]) {
        Task {
            await repository.updateSetOptions(
                sessionId: session.id,
                sessionExerciseId: exercise.id,
                setId: set.id,
                isWarmup: isWarmup,
                usedAccessories: usedAccessories
            )
        }
    }
}
