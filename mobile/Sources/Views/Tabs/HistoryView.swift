import SwiftUI

struct HistoryView: View {
    var embedded: Bool = false
    @StateObject private var repository = WorkoutRepository.shared
    @State private var nextSessionId: String?
    @State private var errorMessage: String?

    private var groupedSessions: [(String, [WorkoutSession])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: repository.sessions.sorted(by: { $0.date > $1.date })) { session in
            formatter.string(from: Date(timeIntervalSince1970: session.date))
        }
        return grouped
            .map { ($0.key, $0.value) }
            .sorted { lhs, rhs in
                guard let leftDate = formatter.date(from: lhs.0),
                      let rightDate = formatter.date(from: rhs.0) else {
                    return lhs.0 > rhs.0
                }
                return leftDate > rightDate
            }
    }

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                NavigationStack {
                    content
                }
            }
        }
    }

    private var content: some View {
        List {
            if repository.sessions.isEmpty {
                ContentUnavailableView(
                    "No Workout History",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    description: Text("Completed workouts will appear here.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(groupedSessions, id: \.0) { month, sessions in
                    Section(month) {
                        ForEach(sessions) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
        }
        .appListContainer()
        .navigationTitle("History")
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
        .navigationDestination(item: nextSessionDestinationBinding) { destination in
            ActiveSessionView(sessionId: destination.id)
        }
        .alert("History Action Failed", isPresented: Binding(get: {
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

    private var nextSessionDestinationBinding: Binding<SessionDestination?> {
        Binding(
            get: { nextSessionId.map(SessionDestination.init(id:)) },
            set: { next in nextSessionId = next?.id }
        )
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        NavigationLink {
            ActiveSessionView(sessionId: session.id)
        } label: {
            SessionSummaryRow(
                session: session,
                templateName: repository.templateName(for: session.templateId)
            )
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                Task {
                    if let started = await repository.startSessionLike(sessionId: session.id) {
                        nextSessionId = started.id
                    }
                }
            } label: {
                Label("Repeat", systemImage: "play.fill")
            }
            .tint(AppTheme.gymboBlue)

            Button {
                Task {
                    do {
                        try await repository.createTemplateFromSession(sessionId: session.id)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                Label("Save Template", systemImage: "square.stack.badge.plus")
            }
            .tint(AppTheme.gymboGreen)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    do {
                        try await repository.deleteSession(id: session.id)
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

private struct SessionDestination: Identifiable, Hashable {
    let id: String
}

struct SessionSummaryRow: View {
    let session: WorkoutSession
    let templateName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(templateName)
                    .font(.headline)
                Spacer()
                Text(session.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Text(Date(timeIntervalSince1970: session.date), format: .dateTime.day().month().hour().minute())
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Text("\(session.exercises.count) exercise\(session.exercises.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}
