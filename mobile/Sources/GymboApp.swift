import SwiftUI
import UIKit

@main
struct GymboApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var authManager = AuthManager.shared
    @StateObject private var webSocketManager = WebSocketManager.shared
    @StateObject private var repository = WorkoutRepository.shared
    @StateObject private var syncManager = SyncManager.shared

    @State private var didCompleteInitialAuthCheck = false

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    RootTabHostView()
                } else {
                    LoginView()
                }
            }
            .preferredColorScheme(.dark)
            .tint(AppTheme.gymboBlue)
            .task {
                await authManager.verifyToken()
                if authManager.isAuthenticated {
                    await repository.performInitialSyncIfNeeded()
                    await repository.processPendingOperationsNow()
                    await repository.syncNow(forceFull: false)
                }
                didCompleteInitialAuthCheck = true
                updateWebSocketConnection(reason: "initial-launch")
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard didCompleteInitialAuthCheck else { return }
                guard authManager.isAuthenticated else { return }

                if newPhase == .active {
                    Task {
                        await repository.processPendingOperationsNow()
                        await repository.syncNow(forceFull: false)
                    }
                }
                updateWebSocketConnection(reason: "scene-\(newPhase)")
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                guard didCompleteInitialAuthCheck else { return }
                if !isAuthenticated {
                    webSocketManager.disconnect()
                    repository.handleLogoutCleanup()
                    return
                }

                Task {
                    await repository.performInitialSyncIfNeeded()
                    await repository.syncNow(forceFull: false)
                }
                updateWebSocketConnection(reason: "auth-change")
            }
            .onChange(of: webSocketManager.updateEventCounter) { _, _ in
                repository.scheduleBackgroundSync(reason: webSocketManager.lastServerEventType ?? "websocket")
            }
            .onChange(of: syncManager.pendingCount) { _, newValue in
                if newValue == 0 {
                    repository.scheduleBackgroundSync(reason: "pending-drained")
                }
            }
        }
    }

    private func updateWebSocketConnection(reason _: String) {
        guard authManager.isAuthenticated else {
            webSocketManager.disconnect()
            return
        }

        guard scenePhase == .active else {
            webSocketManager.disconnect()
            return
        }

        webSocketManager.connect()
    }

    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = UIColor(AppTheme.backgroundAccent).withAlphaComponent(0.85)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(AppTheme.surface)
        UITabBar.appearance().standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
    }
}
