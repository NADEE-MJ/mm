import SwiftUI

struct RootTabHostView: View {
    @StateObject private var repository = WorkoutRepository.shared
    @StateObject private var syncManager = SyncManager.shared
    @State private var selectedTab: TabItem = .log

    var body: some View {
        TabView(selection: $selectedTab) {
            LogWorkoutView()
                .tabItem { Label(TabItem.log.title, systemImage: TabItem.log.icon) }
                .tag(TabItem.log)

            BuilderHomeView()
                .tabItem { Label(TabItem.builder.title, systemImage: TabItem.builder.icon) }
                .tag(TabItem.builder)

            ProgressHomeView()
                .tabItem { Label(TabItem.progress.title, systemImage: TabItem.progress.icon) }
                .tag(TabItem.progress)

            AccountView()
                .tabItem { Label(TabItem.account.title, systemImage: TabItem.account.icon) }
                .tag(TabItem.account)
                .badge(accountBadgeCount > 0 ? accountBadgeCount : 0)
        }
        .tint(AppTheme.gymboBlue)
        .toolbarBackground(AppTheme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }

    private var accountBadgeCount: Int {
        repository.pendingOperationsCount + syncManager.unresolvedIssueCount
    }
}

private struct BuilderHomeView: View {
    @StateObject private var repository = WorkoutRepository.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Programming") {
                    NavigationLink {
                        TemplatesListView()
                    } label: {
                        Label("Templates", systemImage: "square.stack")
                    }

                    NavigationLink {
                        ExercisesListView()
                    } label: {
                        Label("Exercises", systemImage: "figure.strengthtraining.traditional")
                    }

                    NavigationLink {
                        ScheduleEditorView()
                    } label: {
                        Label("Weekly Schedule", systemImage: "calendar")
                    }
                }

                Section("Library") {
                    LabeledContent("Templates", value: "\(repository.templates.count)")
                    LabeledContent("Exercises", value: "\(repository.exercises.count)")
                }
            }
            .appListContainer()
            .navigationTitle("Build")
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

private struct ProgressHomeView: View {
    @StateObject private var repository = WorkoutRepository.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Insights") {
                    NavigationLink {
                        HistoryView(embedded: true)
                    } label: {
                        Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    }

                    NavigationLink {
                        MetricsView(embedded: true)
                    } label: {
                        Label("Metrics", systemImage: "chart.bar")
                    }
                }

                Section("Summary") {
                    LabeledContent("Sessions", value: "\(repository.metricsSummary?.totalSessions ?? 0)")
                    LabeledContent("Current Streak", value: "\(repository.metricsSummary?.currentStreak ?? 0)")
                    LabeledContent("PRs", value: "\(repository.metricsSummary?.prCount ?? 0)")
                }
            }
            .appListContainer()
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
