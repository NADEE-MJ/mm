import SwiftUI

struct ServicesView: View {
    let server: ServerInfo
    let networkService: NetworkService

    @State private var services: [ServiceStatus] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingAction: (service: ServiceStatus, action: String)?

    var body: some View {
        List {
            ForEach(services) { service in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(service.displayName)
                            .font(.headline)
                        Spacer()
                        StatusBadgeView(status: service.status)
                    }

                    Text(service.unit)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    HStack {
                        ForEach(["start", "stop", "restart"], id: \.self) { action in
                            Button(action.capitalized) {
                                pendingAction = (service, action)
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
        .alert("Service Action", isPresented: Binding(
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
                        await runAction(service: action.service, action: action.action)
                    }
                }
            }
        } message: {
            if let pendingAction {
                Text("\(pendingAction.action.capitalized) \(pendingAction.service.displayName)?")
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
            services = try await networkService.fetchServices(serverId: server.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runAction(service: ServiceStatus, action: String) async {
        do {
            try await networkService.performServiceAction(
                serverId: server.id,
                serviceName: service.name,
                action: action
            )
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
