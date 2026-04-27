import SwiftUI

struct PackagesView: View {
    let server: ServerInfo
    let networkService: NetworkService

    @State private var state: PackageState?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if let state {
                Section("Package State") {
                    LabeledContent("Server", value: state.serverId)

                    LabeledContent("Last Updated") {
                        if let lastUpdatedAt = state.lastUpdatedAt {
                            Text(formatDate(milliseconds: lastUpdatedAt))
                        } else {
                            Text("Never")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Days Since Update") {
                        if let days = state.daysSinceUpdate {
                            Text(String(format: "%.1f", days))
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                Section {
                    Text("No package state available")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Refresh") {
                    Task { await refresh() }
                }

                Button("Record Update") {
                    Task { await recordUpdate() }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
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
