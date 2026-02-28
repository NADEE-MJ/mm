import SwiftUI

struct ServerListView: View {
    @Bindable var authManager: AuthManager
    let networkService: NetworkService
    let deviceKeyManager: DeviceKeyManager

    @State private var servers: [ServerInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(servers) { server in
                        NavigationLink {
                            ServerDetailView(server: server, networkService: networkService, authManager: authManager)
                        } label: {
                            ServerCardView(server: server) {
                                wake(server)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Servers")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Settings") {
                        SettingsView(authManager: authManager)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        loadServers()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .padding(10)
                        .background(.red.opacity(0.15), in: Capsule())
                        .padding(.bottom, 20)
                }
            }
            .task {
                loadServers()
            }
        }
    }

    private func loadServers() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let value = try await networkService.fetchServers()
                await MainActor.run {
                    servers = value
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func wake(_ server: ServerInfo) {
        guard server.canWake else { return }

        Task {
            do {
                try await networkService.sendWake(serverId: server.id)
                loadServers()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
