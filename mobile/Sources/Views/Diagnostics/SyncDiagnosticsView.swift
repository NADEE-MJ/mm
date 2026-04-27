import SwiftUI

struct SyncDiagnosticsView: View {
    @StateObject private var repository = WorkoutRepository.shared
    @StateObject private var syncManager = SyncManager.shared

    var body: some View {
        List {
            Section("Overview") {
                row("Repository Syncing", value: repository.isSyncing ? "Yes" : "No")
                row("Queue Worker", value: syncManager.isSyncing ? "Running" : "Idle")
                row("Pending Operations", value: "\(syncManager.pendingCount)")
                row("Open Issues", value: "\(syncManager.unresolvedIssueCount)")
                row("Conflicts", value: "\(syncManager.conflictCount)")
                if let lastSync = repository.lastSyncAt {
                    row("Last Data Sync", value: lastSync.formatted(date: .abbreviated, time: .standard))
                }
                if let lastRun = syncManager.lastRunAt {
                    row("Last Queue Run", value: lastRun.formatted(date: .abbreviated, time: .standard))
                }
            }

            if let summary = syncManager.lastRunSummary {
                Section("Last Queue Summary") {
                    row("Processed", value: "\(summary.processed)")
                    row("Succeeded", value: "\(summary.succeeded)")
                    row("Failed", value: "\(summary.failed)")
                    row("Conflicts", value: "\(summary.conflicts)")
                    row("Dropped", value: "\(summary.dropped)")
                }
            }

            Section("Pending Operations") {
                if syncManager.pendingOperations.isEmpty {
                    Text("No pending operations.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(syncManager.pendingOperations) { operation in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(operation.type)
                                .font(.subheadline.weight(.semibold))
                            Text("Retry: \(operation.retryCount) • Created: \(operation.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(operation.id)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Section("Sync Issues") {
                if syncManager.recentIssues.isEmpty {
                    Text("No active issues.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(syncManager.recentIssues) { issue in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Label(
                                    issue.isConflict ? "Conflict" : "Retry Error",
                                    systemImage: issue.isConflict ? "exclamationmark.triangle.fill" : "xmark.octagon.fill"
                                )
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(issue.isConflict ? .yellow : .red)
                                Spacer()
                                Text("retry \(issue.retryCount)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(issue.operationType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(issue.message)
                                .font(.caption)
                            Text("Updated: \(issue.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Actions") {
                Button("Process Pending Queue") {
                    Task {
                        await repository.processPendingOperationsNow()
                        await repository.syncNow(forceFull: false)
                    }
                }

                Button("Run Full Sync") {
                    Task {
                        await repository.syncNow(forceFull: true)
                    }
                }

                Button("Clear Issue List", role: .destructive) {
                    syncManager.clearIssues()
                }
            }
        }
        .appListContainer()
        .navigationTitle("Sync Diagnostics")
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
