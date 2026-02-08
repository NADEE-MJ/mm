import SwiftUI

@main
struct MobileSwiftApp: App {
    @State private var authManager = AuthManager.shared
    @State private var bioManager = BiometricAuthManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if !authManager.isAuthenticated {
                    // Not logged in — show login
                    LoginView()
                        .transition(.opacity)
                } else {
                    ZStack {
                        RootTabHostView()

                        // ── Lock Screen Overlay (biometric) ──
                        if !bioManager.isUnlocked {
                            LockScreenView(authManager: bioManager)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: bioManager.isUnlocked)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .task {
                await authManager.verifyToken()
            }
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let authManager: BiometricAuthManager

    var body: some View {
        ZStack {
            // Heavy blur over the entire app
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: authManager.biometryIcon)
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.blue)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Movie Manager")
                    .font(.title.bold())
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Tap to unlock with \(authManager.biometryLabel)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                Button {
                    authManager.authenticate()
                } label: {
                    Label("Unlock", systemImage: authManager.biometryIcon)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(AppTheme.blue, in: .capsule)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact, trigger: authManager.isUnlocked)

                if let error = authManager.authError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
        .onAppear {
            authManager.authenticate()
        }
    }
}
