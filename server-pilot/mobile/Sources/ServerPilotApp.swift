import SwiftUI

@main
struct ServerPilotApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var authManager = AuthManager.shared
    @State private var biometricManager = BiometricAuthManager()
    @State private var deviceKeyManager = DeviceKeyManager.shared
    @State private var networkService = NetworkService.shared

    @State private var needsRelock = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authManager.isEnrolled {
                    ServerListView(
                        authManager: authManager,
                        networkService: networkService,
                        deviceKeyManager: deviceKeyManager
                    )
                } else {
                    SetupView(
                        authManager: authManager,
                        networkService: networkService,
                        deviceKeyManager: deviceKeyManager
                    )
                }

                if !biometricManager.isUnlocked {
                    LockScreenView(authManager: biometricManager)
                }
            }
            .onAppear {
                if needsRelock {
                    biometricManager.lock()
                    biometricManager.authenticate(reason: "Unlock ServerPilot")
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
                        biometricManager.authenticate(reason: "Unlock ServerPilot")
                        needsRelock = false
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
                    .foregroundStyle(AppTheme.accent)

                Text("ServerPilot")
                    .font(.largeTitle.bold())

                Text("Unlock with \(authManager.biometryLabel)")
                    .foregroundStyle(.secondary)

                Button("Unlock") {
                    authManager.authenticate(reason: "Unlock ServerPilot")
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
