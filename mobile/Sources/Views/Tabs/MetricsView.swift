import Charts
import SwiftUI

struct MetricsView: View {
    var embedded: Bool = false
    @StateObject private var repository = WorkoutRepository.shared
    @State private var selectedExerciseId: String?

    private var completedSessions: [WorkoutSession] {
        repository.sessions.filter { $0.status == "completed" }
    }

    private var weeklyVolumePoints: [WeeklyVolumePoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: completedSessions) { session in
            let day = Date(timeIntervalSince1970: session.date)
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)) ?? day
        }

        return grouped.map { weekStart, sessions in
            WeeklyVolumePoint(
                weekStart: weekStart,
                volume: sessions.reduce(into: 0.0) { partialResult, session in
                    for exercise in session.exercises {
                        for set in exercise.sets where set.completed {
                            guard let reps = set.reps, let weight = set.weight else { continue }
                            partialResult += Double(reps) * weight
                        }
                    }
                }
            )
        }
        .sorted { $0.weekStart < $1.weekStart }
    }

    private var exerciseProgressPoints: [ExerciseProgressPoint] {
        guard let selectedExerciseId else { return [] }
        return completedSessions.compactMap { session in
            let sets = session.exercises
                .filter { $0.exerciseId == selectedExerciseId }
                .flatMap(\.sets)
                .filter(\.completed)

            guard let maxWeight = sets.compactMap(\.weight).max() else { return nil }
            let reps = sets.compactMap(\.reps).max()
            let estimated1RM = reps.map { maxWeight * (1 + (Double($0) / 30.0)) }
            return ExerciseProgressPoint(
                timestamp: session.date,
                weight: maxWeight,
                reps: reps,
                estimated1RM: estimated1RM
            )
        }
        .sorted { $0.timestamp < $1.timestamp }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryRow

                GroupBox("Weekly Volume") {
                    Chart(weeklyVolumePoints) { point in
                        BarMark(
                            x: .value("Week", point.weekStart, unit: .weekOfYear),
                            y: .value("Volume", point.volume)
                        )
                        .foregroundStyle(AppTheme.gymboBlue.gradient)
                    }
                    .frame(height: 220)
                }
                .tint(AppTheme.textPrimary)

                GroupBox("Exercise Progress") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Exercise", selection: $selectedExerciseId) {
                            Text("Select").tag(Optional<String>.none)
                            ForEach(repository.exercises) { exercise in
                                Text(exercise.name).tag(Optional(exercise.id))
                            }
                        }
                        .pickerStyle(.menu)

                        if exerciseProgressPoints.isEmpty {
                            Text("Log a completed session for this exercise to see progression.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        } else {
                            Chart(exerciseProgressPoints) { point in
                                if let weight = point.weight {
                                    LineMark(
                                        x: .value("Date", Date(timeIntervalSince1970: point.timestamp)),
                                        y: .value("Weight", weight)
                                    )
                                    .foregroundStyle(AppTheme.gymboGreen)
                                }
                                if let oneRM = point.estimated1RM {
                                    LineMark(
                                        x: .value("Date", Date(timeIntervalSince1970: point.timestamp)),
                                        y: .value("1RM", oneRM)
                                    )
                                    .foregroundStyle(AppTheme.gymboOrange)
                                }
                            }
                            .frame(height: 220)
                        }
                    }
                }
                .tint(AppTheme.textPrimary)
            }
            .padding(16)
        }
        .appScreenBackground()
        .navigationTitle("Metrics")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await repository.syncNow(forceFull: false) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            if selectedExerciseId == nil {
                selectedExerciseId = repository.exercises.first?.id
            }
        }
    }

    private var summaryRow: some View {
        let summary = repository.metricsSummary
        return HStack(spacing: 10) {
            metricCard("Streak", value: "\(summary?.currentStreak ?? 0)")
            metricCard("Sessions", value: "\(summary?.totalSessions ?? 0)")
            metricCard("PRs", value: "\(summary?.prCount ?? 0)")
        }
    }

    private func metricCard(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }
}

private struct WeeklyVolumePoint: Identifiable {
    let id = UUID()
    let weekStart: Date
    let volume: Double
}
