import SwiftUI

struct DashboardView: View {
    @StateObject private var repository = WorkoutRepository.shared
    @State private var activeSession: WorkoutSession?

    private var inProgressSession: WorkoutSession? {
        repository.inProgressSession()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    if inProgressSession == nil {
                        todayScheduleSection
                    }
                    recentSessionsSection
                }
                .padding(16)
            }
            .refreshable {
                await repository.syncNow(forceFull: false)
            }
            .appScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $activeSession) { session in
                ActiveSessionView(sessionId: session.id)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let inProgressSession {
                Text("Active Session")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(repository.templateName(for: inProgressSession.templateId))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(inProgressSession.exercises.count) exercise\(inProgressSession.exercises.count == 1 ? "" : "s") in progress")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Button("Resume Workout") {
                    activeSession = inProgressSession
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.gymboBlue)
            } else {
                Text("Ready to train")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Start from Log or today’s plan below.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    private var todayScheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Plan")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if repository.todayScheduleEntries.isEmpty {
                emptyCard(title: "No templates scheduled today", subtitle: "Use Log to start freeform or Build to create templates.")
            } else {
                ForEach(repository.todayScheduleEntries) { entry in
                    let template = repository.templates.first(where: { $0.id == entry.templateId })
                    let workoutType = repository.workoutTypes.first(where: { $0.id == template?.workoutTypeId })
                    let accent = AppTheme.color(for: workoutType?.slug ?? "")

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template?.name ?? "Freeform Workout")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("\(template?.exercises.count ?? 0) exercise\(template?.exercises.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()
                            Circle()
                                .fill(accent)
                                .frame(width: 10, height: 10)
                        }

                        Button("Start Workout") {
                            Task {
                                if let inProgressSession {
                                    activeSession = inProgressSession
                                } else {
                                    activeSession = await repository.startSession(templateId: entry.templateId)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .disabled(inProgressSession != nil)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Sessions")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            let recent = repository.sessions.prefix(6)
            if recent.isEmpty {
                emptyCard(title: "No sessions yet", subtitle: "Start your first workout from the Log tab.")
            } else {
                ForEach(Array(recent)) { session in
                    NavigationLink {
                        ActiveSessionView(sessionId: session.id)
                    } label: {
                        SessionSummaryRow(
                            session: session,
                            templateName: repository.templateName(for: session.templateId)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func emptyCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

}
