import SwiftUI

struct PowerView: View {
    let server: ServerInfo
    let networkService: NetworkService

    @State private var pendingAction: String?
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        List {
            Section {
                powerRow(
                    title: "Restart",
                    subtitle: "Reboot the server. The connection will drop briefly.",
                    iconName: "arrow.clockwise.circle.fill",
                    iconColor: .orange,
                    action: "restart"
                )

                powerRow(
                    title: "Shut Down",
                    subtitle: "Power off the server. You may need Wake-on-LAN to turn it back on.",
                    iconName: "power.circle.fill",
                    iconColor: .red,
                    action: "shutdown"
                )
            } header: {
                Text("Power Management")
            } footer: {
                Text("Both actions require passwordless sudo to be configured on the server.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .alert(alertTitle, isPresented: Binding(
            get: { pendingAction != nil },
            set: { value in
                if !value { pendingAction = nil }
            }
        )) {
            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
            Button(alertConfirmLabel, role: .destructive) {
                let action = pendingAction
                pendingAction = nil
                if let action {
                    Task {
                        await runPowerAction(action)
                    }
                }
            }
        } message: {
            if let pendingAction {
                Text(alertMessage(for: pendingAction))
            }
        }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .padding(10)
                    .background(.red.opacity(0.12), in: Capsule())
                    .padding(.bottom, 12)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            self.errorMessage = nil
                        }
                    }
            } else if let successMessage {
                Text(successMessage)
                    .font(.footnote)
                    .padding(10)
                    .background(.green.opacity(0.15), in: Capsule())
                    .padding(.bottom, 12)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            self.successMessage = nil
                        }
                    }
            }
        }
    }

    // MARK: - Subviews

    private func powerRow(
        title: String,
        subtitle: String,
        iconName: String,
        iconColor: Color,
        action: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 36))
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(title) {
                pendingAction = action
            }
            .buttonStyle(.bordered)
            .tint(iconColor)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Alert helpers

    private var alertTitle: String {
        switch pendingAction {
        case "restart": return "Restart \(server.name)?"
        case "shutdown": return "Shut Down \(server.name)?"
        default: return "Confirm Action"
        }
    }

    private var alertConfirmLabel: String {
        switch pendingAction {
        case "restart": return "Restart"
        case "shutdown": return "Shut Down"
        default: return "Confirm"
        }
    }

    private func alertMessage(for action: String) -> String {
        switch action {
        case "restart":
            return "The server will reboot. The SSH connection will drop temporarily."
        case "shutdown":
            return "The server will power off. You will need physical access or Wake-on-LAN to turn it back on."
        default:
            return "Are you sure?"
        }
    }

    // MARK: - Action

    private func runPowerAction(_ action: String) async {
        errorMessage = nil
        successMessage = nil

        do {
            try await networkService.performPowerAction(serverId: server.id, action: action)
            successMessage = action == "restart"
                ? "Restart command sent to \(server.name)."
                : "Shutdown command sent to \(server.name)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
