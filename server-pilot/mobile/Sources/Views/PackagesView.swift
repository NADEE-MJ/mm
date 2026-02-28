import SwiftUI

struct PackagesView: View {
    let server: ServerInfo
    let networkService: NetworkService

    @State private var state: PackageState?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if let state {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Server", value: state.serverId)

                    LabeledContent("Last updated") {
                        if let lastUpdatedAt = state.lastUpdatedAt {
                            Text(formatDate(milliseconds: lastUpdatedAt))
                        } else {
                            Text("Never")
                        }
                    }

                    LabeledContent("Days since update") {
                        if let days = state.daysSinceUpdate {
                            Text(String(format: "%.1f", days))
                        } else {
                            Text("-")
                        }
                    }
                }
                .padding()
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))
            } else if isLoading {
                ProgressView()
            } else {
                Text("No package state available")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Refresh") {
                    Task { await refresh() }
                }
                .buttonStyle(.bordered)

                Button("Record Update") {
                    Task { await recordUpdate() }
                }
                .buttonStyle(.borderedProminent)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.background.ignoresSafeArea())
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            state = try await networkService.fetchPackageState(serverId: server.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordUpdate() async {
        isLoading = true
        defer { isLoading = false }

        do {
            state = try await networkService.recordPackageUpdate(serverId: server.id)
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
