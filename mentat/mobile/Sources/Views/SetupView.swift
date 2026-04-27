import SwiftUI

struct SetupView: View {
    @Bindable var config: SSHConfigManager
    @Bindable var sshManager: SSHConnectionManager

    @State private var isConnecting = false
    @State private var connectionResult: ConnectionResult?
    @State private var publicKeyText = ""

    private enum ConnectionResult {
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section {
                if publicKeyText.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text(publicKeyText)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)

                    Button {
                        UIPasteboard.general.string = publicKeyText
                    } label: {
                        Label("Copy Public Key", systemImage: "doc.on.doc")
                    }
                }
            } header: {
                Text("SSH Public Key")
            } footer: {
                Text("Add this key to `~/.ssh/authorized_keys` on your server before connecting.")
            }

            Section("Connection Details") {
                LabeledContent("Local LAN IP") {
                    TextField("192.168.1.10 (optional)", text: $config.localIP)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Tailscale IP") {
                    TextField("100.64.0.1 (optional)", text: $config.tailscaleIP)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("SSH Username") {
                    TextField("ubuntu", text: $config.sshUsername)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("SSH Port") {
                    TextField("22", text: sshPortBinding)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("API Port") {
                    TextField("3000", text: apiPortBinding)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                Button {
                    connect()
                } label: {
                    if isConnecting {
                        HStack {
                            ProgressView()
                            Text("Connecting…")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("Connect")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .disabled(!config.isConfigured || isConnecting)
            }

            if let result = connectionResult {
                Section {
                    switch result {
                    case .success:
                        Label("Connected successfully", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let message):
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("SSH Setup")
        .task {
            loadPublicKey()
        }
    }

    // MARK: - Bindings

    private var sshPortBinding: Binding<String> {
        Binding(
            get: { config.sshPort > 0 ? String(config.sshPort) : "" },
            set: { config.sshPort = Int($0) ?? config.sshPort }
        )
    }

    private var apiPortBinding: Binding<String> {
        Binding(
            get: { config.apiPort > 0 ? String(config.apiPort) : "" },
            set: { config.apiPort = Int($0) ?? config.apiPort }
        )
    }

    // MARK: - Actions

    private func loadPublicKey() {
        Task {
            do {
                let manager = SSHIdentityManager.shared
                try manager.ensureKeyExists()
                let openssh = try manager.exportOpenSSHPublicKey()
                publicKeyText = openssh
            } catch {
                publicKeyText = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func connect() {
        isConnecting = true
        connectionResult = nil

        sshManager.stop()
        sshManager.start()

        Task {
            // Poll connection state up to 15 seconds.
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let state = sshManager.state
                if state == .connectedLocal || state == .connectedTailscale {
                    await MainActor.run {
                        connectionResult = .success
                        isConnecting = false
                    }
                    return
                }
                if state == .disconnected, let err = sshManager.lastError {
                    await MainActor.run {
                        connectionResult = .failure(err)
                        isConnecting = false
                    }
                    return
                }
            }
            await MainActor.run {
                connectionResult = .failure("Connection timed out. Check IPs, port, and that the public key is in authorized_keys.")
                isConnecting = false
            }
        }
    }
}
