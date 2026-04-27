import SwiftUI

struct SettingsView: View {
    @Bindable var config: SSHConfigManager
    @Bindable var sshManager: SSHConnectionManager

    var body: some View {
        Form {
            Section("SSH Connection") {
                LabeledContent("Status", value: connectionStatusLabel)
                    .foregroundStyle(connectionStatusColor)

                if let error = sshManager.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("SSH Configuration") {
                NavigationLink("Edit Connection Settings") {
                    SetupView(config: config, sshManager: sshManager)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }

            Section("Danger Zone") {
                Button(role: .destructive) {
                    sshManager.stop()
                    config.clearConfiguration()
                    SSHIdentityManager.shared.deleteKey()
                } label: {
                    Text("Reset SSH Identity & Settings")
                }
            }
        }
        .navigationTitle("Settings")
    }

    // MARK: - Helpers

    private var connectionStatusLabel: String {
        switch sshManager.state {
        case .disconnected: return "Disconnected"
        case .connecting:   return "Connecting…"
        case .connectedLocal: return "Connected (Local)"
        case .connectedTailscale: return "Connected (Tailscale)"
        }
    }

    private var connectionStatusColor: Color {
        switch sshManager.state {
        case .disconnected:       return .red
        case .connecting:         return .orange
        case .connectedLocal, .connectedTailscale: return .green
        }
    }
}
