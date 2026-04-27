import SwiftUI

struct JobsView: View {
    let networkService: NetworkService

    @State private var jobs: [Job] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Jobs") {
                if jobs.isEmpty && !isLoading {
                    Text("No jobs configured")
                        .foregroundStyle(.secondary)
                }

                ForEach(jobs) { job in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(job.id)
                                .font(.headline)
                            Spacer()
                            StatusBadgeView(status: job.enabled ? "enabled" : "disabled")
                        }

                        Text(job.command)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)

                        Text(job.schedule)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let lastRunAt = job.lastRunAt {
                            Text("Last run: \(formatDate(milliseconds: lastRunAt))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .refreshable {
            await refresh()
        }
        .task {
            await refresh()
        }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .padding(10)
                    .background(.red.opacity(0.12), in: Capsule())
                    .padding(.bottom, 12)
            }
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            jobs = try await networkService.fetchJobs()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatDate(milliseconds: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
