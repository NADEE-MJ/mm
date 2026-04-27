import SwiftUI

struct LogWorkoutView: View {
    @StateObject private var repository = WorkoutRepository.shared
    @State private var searchText = ""

    private var inProgressSession: WorkoutSession? {
        repository.inProgressSession()
    }

    private var filteredTemplates: [WorkoutTemplate] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return repository.templates }
        return repository.templates.filter { template in
            template.name.localizedCaseInsensitiveContains(trimmed) ||
                (template.description?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            if let inProgressSession {
                ActiveSessionView(sessionId: inProgressSession.id)
            } else {
                List {
                    Section("Start New Session") {
                        Button {
                            Task {
                                _ = await repository.startSession(templateId: nil)
                            }
                        } label: {
                            Label("Start From Scratch", systemImage: "plus.circle.fill")
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }

                    if !repository.todayScheduleEntries.isEmpty {
                        Section("Today") {
                            ForEach(repository.todayScheduleEntries) { entry in
                                templateButton(entry.templateId)
                            }
                        }
                    }

                    Section("Templates") {
                        ForEach(filteredTemplates) { template in
                            templateButton(template.id)
                        }
                    }
                }
                .appListContainer()
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search templates"
                )
                .navigationTitle("Log Workout")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await repository.syncNow(forceFull: false) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
    }

    private func templateButton(_ templateId: String?) -> some View {
        let template = repository.templates.first(where: { $0.id == templateId })
        let workoutType = repository.workoutTypes.first(where: { $0.id == template?.workoutTypeId })
        let accent = AppTheme.color(for: workoutType?.slug ?? "")

        return Button {
            Task {
                _ = await repository.startSession(templateId: templateId)
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 3) {
                    Text(template?.name ?? "Freeform Workout")
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(template?.exercises.count ?? 0) exercise\(template?.exercises.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .foregroundStyle(accent)
            }
            .padding(.vertical, 4)
        }
    }
}
