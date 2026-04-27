import SwiftUI

struct ActiveSessionView: View {
    let sessionId: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var repository = WorkoutRepository.shared
    @State private var session: WorkoutSession?
    @State private var isFinishing = false
    @State private var showExercisePicker = false

    var body: some View {
        VStack(spacing: 0) {
            if let session {
                header(session: session)

                List {
                    ForEach(session.exercises.sorted(by: { $0.position < $1.position })) { exercise in
                        ExerciseSection(
                            session: session,
                            exercise: exercise,
                            exerciseMeta: repository.exercise(forSessionExerciseId: exercise.exerciseId)
                        )
                    }

                    if session.status != "completed" {
                        Section {
                            Button {
                                showExercisePicker = true
                            } label: {
                                Label("Add Exercise", systemImage: "plus.circle")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppTheme.gymboBlue)
                            .disabled(repository.exercises.isEmpty)
                        }
                    }
                }
                .appListContainer()

                if repository.isSessionQueuedLocally(session.id) {
                    Text("Offline session: changes are queued and will sync automatically.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.gymboOrange)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.surface)
                }
            } else {
                ProgressView("Loading session...")
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .appScreenBackground()
            }
        }
        .navigationTitle(session?.status == "completed" ? "Session Details" : "Active Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let session, session.status != "completed" {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            isFinishing = true
                            await repository.completeSession(id: session.id)
                            isFinishing = false
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .disabled(isFinishing)
                }
            }
        }
        .onAppear {
            session = repository.session(withId: sessionId)
        }
        .onChange(of: repository.sessions) { _, _ in
            session = repository.session(withId: sessionId)
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                guard let session else { return }
                Task {
                    await repository.addExerciseToSession(sessionId: session.id, exerciseId: exercise.id)
                }
            }
        }
        .alert(item: $repository.pendingExerciseRecordPrompt) { prompt in
            Alert(
                title: Text(promptTitle(prompt)),
                message: Text(promptMessage(prompt)),
                primaryButton: .default(Text("Replace")) {
                    Task {
                        await repository.resolvePendingExerciseRecordPrompt(replace: true)
                    }
                },
                secondaryButton: .cancel(Text("Keep Current")) {
                    Task {
                        await repository.resolvePendingExerciseRecordPrompt(replace: false)
                    }
                }
            )
        }
    }

    private func header(session: WorkoutSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(repository.templateName(for: session.templateId))
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(session.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "bolt.heart.fill")
                .foregroundStyle(AppTheme.gymboOrange)
        }
        .padding(14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding([.top, .horizontal], 16)
        .padding(.bottom, 8)
    }

    private func promptTitle(_ prompt: ExerciseRecordPrompt) -> String {
        switch prompt.kind {
        case .highestSet:
            return "New Highest Set"
        case .oneRepMax:
            return "New 1RM Estimate"
        }
    }

    private func promptMessage(_ prompt: ExerciseRecordPrompt) -> String {
        let unit = AuthManager.shared.currentUser?.unitPreference ?? "lbs"
        switch prompt.kind {
        case .highestSet:
            let candidate = "\(formatNumber(prompt.candidateWeight)) \(unit) x \(prompt.candidateReps ?? 0)"
            if let currentWeight = prompt.currentWeight {
                let current = "\(formatNumber(currentWeight)) \(unit) x \(prompt.currentReps ?? 0)"
                return "\(prompt.exerciseName): \(candidate). Replace current \(current)?"
            }
            return "\(prompt.exerciseName): \(candidate). Save as your highest set?"

        case .oneRepMax:
            let candidate = "\(formatNumber(prompt.candidateOneRepMax)) \(unit)"
            if let current = prompt.currentOneRepMax {
                return "\(prompt.exerciseName): \(candidate). Replace current \(formatNumber(current)) \(unit)?"
            }
            return "\(prompt.exerciseName): \(candidate). Save as your 1RM?"
        }
    }

    private func formatNumber(_ value: Double?) -> String {
        guard let value else { return "0" }
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
