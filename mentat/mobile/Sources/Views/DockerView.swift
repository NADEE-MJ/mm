import SwiftUI

struct DockerView: View {
    let server: ServerInfo
    let networkService: NetworkService

    @State private var containers: [Container] = []
    @State private var includeStopped = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var logText = ""
    @State private var showLogs = false
    @State private var pendingAction: (container: Container, action: String)?

    var body: some View {
        List {
            Section {
                Toggle("Include stopped", isOn: $includeStopped)
                    .onChange(of: includeStopped) { _, _ in
                        Task { await refresh() }
                    }
            }

            ForEach(containers) { container in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(container.name)
                                .font(.headline)
                            Text(container.image)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadgeView(status: container.state)
                    }

                    HStack {
                        Button("Logs") {
                            Task { await loadLogs(container) }
                        }
                        .buttonStyle(.bordered)

                        ForEach(["start", "stop", "restart"], id: \.self) { action in
                            Button(action.capitalized) {
                                pendingAction = (container, action)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.vertical, 4)
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
        .sheet(isPresented: $showLogs) {
            NavigationStack {
                ScrollView {
                    Text(logText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle("Container Logs")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .alert("Container Action", isPresented: Binding(
            get: { pendingAction != nil },
            set: { value in
                if !value { pendingAction = nil }
            }
        )) {
            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
            Button("Confirm", role: .destructive) {
                let action = pendingAction
                pendingAction = nil
                if let action {
                    Task {
                        await runAction(container: action.container, action: action.action)
                    }
                }
            }
        } message: {
            if let pendingAction {
                Text("\(pendingAction.action.capitalized) container \(pendingAction.container.name)?")
            }
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
            containers = try await networkService.fetchContainers(serverId: server.id, all: includeStopped)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadLogs(_ container: Container) async {
        do {
            logText = try await networkService.fetchContainerLogs(serverId: server.id, containerId: container.id)
            showLogs = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runAction(container: Container, action: String) async {
        do {
            try await networkService.performContainerAction(
                serverId: server.id,
                containerId: container.id,
                action: action
            )
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
