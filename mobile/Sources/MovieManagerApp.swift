import SwiftUI

@main
struct MovieManagerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var authManager = AuthManager.shared
    @State private var bioManager = BiometricAuthManager()
    @State private var wsManager = WebSocketManager.shared
    @State private var repository = MovieRepository.shared
    @State private var syncManager = SyncManager.shared
    @State private var didCompleteInitialAuthCheck = false

    init() {
        configureImageCache()
    }

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
                AppLog.info("📱 [App] Launching app and verifying auth token", category: .app)
                await authManager.verifyToken()
                if authManager.isAuthenticated {
                    await repository.performInitialSyncIfNeeded()
                    await repository.syncNow()
                }
                didCompleteInitialAuthCheck = true
                updateWebSocketConnection(reason: "initial-auth-check")
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard didCompleteInitialAuthCheck else { return }
                guard newPhase == .active else { return }

                Task {
                    await syncManager.processPendingOperations()
                    await syncManager.enrichPendingMovies()
                }

                updateWebSocketConnection(reason: "scene-active")
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                guard didCompleteInitialAuthCheck else { return }
                if !isAuthenticated {
                    wsManager.disconnect()
                    repository.handleLogoutCleanup()
                    return
                }

                Task {
                    await repository.performInitialSyncIfNeeded()
                    await repository.syncNow()
                }

                if scenePhase == .active {
                    updateWebSocketConnection(reason: "auth-changed")
                }
            }
        }
    }

    private func updateWebSocketConnection(reason: String) {
        guard authManager.isAuthenticated else {
            wsManager.disconnect()
            return
        }

        guard scenePhase == .active else { return }

        AppLog.info("🔌 [App] Ensuring websocket connection (\(reason))", category: .app)
        wsManager.connect()
    }

    private func configureImageCache() {
        let cache = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            diskPath: "movie_images"
        )
        URLCache.shared = cache
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
