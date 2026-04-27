import Foundation

// MARK: - WebSocketManager

/// Manages a WebSocket connection to the backend metrics stream for a single
/// server. While connected the backend pushes a `SystemMetrics` JSON message
/// every second.
///
/// Usage:
///   let manager = WebSocketManager(serverId: server.id)
///   manager.start()         // connect and begin receiving
///   ...
///   manager.stop()          // disconnect
///
/// The `metrics` and `errorMessage` properties are `@MainActor`-isolated and
/// safe to observe directly from SwiftUI views.
@MainActor
@Observable
final class WebSocketManager {

    // MARK: - Observable state

    private(set) var metrics: SystemMetrics?
    private(set) var errorMessage: String?

    // MARK: - Private

    private let serverId: String
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isRunning = false

    // MARK: - Init

    init(serverId: String) {
        self.serverId = serverId
    }

    // MARK: - Public API

    func start() {
        guard !isRunning else { return }
        isRunning = true
        connect()
    }

    func stop() {
        isRunning = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session = nil
    }

    // MARK: - Connection

    private func connect() {
        let port = SSHConnectionManager.shared.tunnelPort
        guard port > 0 else {
            errorMessage = "SSH tunnel is not connected."
            // Retry after a short delay in case the tunnel hasn't come up yet.
            scheduleReconnect(after: 2)
            return
        }

        let encodedId = serverId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?
            .replacingOccurrences(of: "/", with: "%2F") ?? serverId

        guard let url = URL(string: "ws://127.0.0.1:\(port)/api/ws/metrics/\(encodedId)") else {
            errorMessage = "Failed to construct WebSocket URL."
            return
        }

        let config = URLSessionConfiguration.default
        let newSession = URLSession(configuration: config)
        session = newSession

        let wsTask = newSession.webSocketTask(with: url)
        task = wsTask
        wsTask.resume()

        receiveNext()
        AppLog.info("WebSocket connected for server '\(serverId)' on port \(port)")
    }

    // MARK: - Receive loop

    private func receiveNext() {
        guard let wsTask = task, isRunning else { return }

        wsTask.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.receiveNext()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    AppLog.error("WebSocket receive error for '\(self.serverId)': \(error.localizedDescription)")
                    self.task = nil
                    self.session = nil
                    self.scheduleReconnect(after: 3)
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .data(let d):
            data = d
        case .string(let s):
            guard let d = s.data(using: .utf8) else { return }
            data = d
        @unknown default:
            return
        }

        do {
            let decoded = try JSONDecoder().decode(SystemMetrics.self, from: data)
            metrics = decoded
            errorMessage = nil
        } catch {
            // May be an error payload from the server; surface it if decodable
            if let errorPayload = try? JSONDecoder().decode(ServerErrorPayload.self, from: data) {
                errorMessage = errorPayload.error
            }
        }
    }

    // MARK: - Reconnect

    private func scheduleReconnect(after seconds: Double) {
        guard isRunning else { return }
        AppLog.info("WebSocket will reconnect for '\(serverId)' in \(Int(seconds))s")
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, self.isRunning else { return }
            self.connect()
        }
    }
}

// MARK: - Private helpers

private struct ServerErrorPayload: Decodable {
    let error: String
}
