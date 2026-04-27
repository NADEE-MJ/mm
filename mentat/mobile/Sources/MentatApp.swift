import SwiftUI

@main
struct MentatApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var sshConfig = SSHConfigManager.shared
    @State private var sshManager = SSHConnectionManager.shared
    @State private var biometricManager = BiometricAuthManager()
    @State private var networkService = NetworkService.shared

    @State private var needsRelock = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if sshConfig.isConfigured {
                    TabView {
                        ServerListView(
                            networkService: networkService,
                            config: sshConfig,
                            sshManager: sshManager
                        )
                        .tabItem {
                            Label("Servers", systemImage: "server.rack")
                        }

                        AppsView(networkService: networkService)
                            .tabItem {
                                Label("Apps", systemImage: "app.badge.fill")
                            }

                        OpenCodeView(networkService: networkService)
                            .tabItem {
                                Label("Code", systemImage: "chevron.left.forwardslash.chevron.right")
                            }
                    }
                } else {
                    SetupView(
                        config: sshConfig,
                        sshManager: sshManager
                    )
                }

                if !biometricManager.isUnlocked {
                    LockScreenView(authManager: biometricManager)
                }
            }
            .onAppear {
                if sshConfig.isConfigured {
                    sshManager.start()
                }
                if needsRelock {
                    biometricManager.lock()
                    biometricManager.authenticate(reason: "Unlock Mentat")
                    needsRelock = false
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    needsRelock = true
                    biometricManager.lock()
                case .active:
                    if needsRelock && !biometricManager.isPrompting {
                        biometricManager.authenticate(reason: "Unlock Mentat")
                        needsRelock = false
                    }
                    if sshConfig.isConfigured && sshManager.state == .disconnected {
                        sshManager.start()
                    }
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}

private struct LockScreenView: View {
    let authManager: BiometricAuthManager

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: authManager.biometryIcon)
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                Text("Mentat")
                    .font(.largeTitle.bold())

                Text("Unlock with \(authManager.biometryLabel)")
                    .foregroundStyle(.secondary)

                Button("Unlock") {
                    authManager.authenticate(reason: "Unlock Mentat")
                }
                .buttonStyle(.borderedProminent)

                if let error = authManager.authError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
    }
}
