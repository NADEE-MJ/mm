import SwiftUI

struct ServerListView: View {
    let networkService: NetworkService
    @Bindable var config: SSHConfigManager
    @Bindable var sshManager: SSHConnectionManager

    @State private var servers: [ServerInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(servers) { server in
                    NavigationLink {
                        ServerDetailView(server: server, networkService: networkService)
                    } label: {
                        ServerRowView(server: server) {
                            wake(server)
                        }
                    }
                }
            }
            .navigationTitle("Servers")
            .onChange(of: sshManager.state) { _, newState in
                if newState == .connectedLocal || newState == .connectedTailscale {
                    loadServers()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Settings") {
                        SettingsView(config: config, sshManager: sshManager)
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
                        .background(.red.opacity(0.12), in: Capsule())
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
            defer { isLoading = false }
            do {
                servers = try await networkService.fetchServers()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func wake(_ server: ServerInfo) {
        guard server.canWake else { return }

        Task {
            do {
                try await networkService.sendWake(serverId: server.id)
                servers = (try? await networkService.fetchServers()) ?? servers
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Row view

private struct ServerRowView: View {
    let server: ServerInfo
    let onWake: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(server.name)
                    .font(.headline)
                Text(server.sshState)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if server.canWake {
                Button("Wake") {
                    onWake()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }

            Circle()
                .fill(server.online ? Color.green : Color.red)
                .frame(width: 10, height: 10)
        }
    }
}
