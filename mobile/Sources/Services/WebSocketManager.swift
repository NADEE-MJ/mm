import Foundation

// MARK: - WebSocket Manager
// Uses URLSessionWebSocketTask for real-time sync with the backend

@MainActor
@Observable
final class WebSocketManager {
    static let shared = WebSocketManager()
    private static let syncUpdateEventTypes: Set<String> = [
        "movieAdded",
        "movieUpdated",
        "movieDeleted",
        "peopleUpdated",
        "listUpdated",
    ]

    private(set) var isConnected = false
    private(set) var messages: [WSMessage] = []
    private(set) var lastError: String?
    private(set) var updateEventCounter = 0
    private(set) var lastServerEventType: String?

    private var task: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var shouldMaintainConnection = false
    private let maxStoredMessages = 250
    private let session = URLSession(configuration: .default)
    private let wsBaseURL = AppConfiguration.webSocketURL

    struct WSMessage: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let isOutgoing: Bool
        let timestamp: Date
    }

    private init() {}

    // MARK: - Connect

    func connect() {
        shouldMaintainConnection = true
        if isConnected, task != nil {
            return
        }

        if let existingTask = task {
            existingTask.cancel(with: .goingAway, reason: nil)
            task = nil
        }

        reconnectTask?.cancel()
        reconnectTask = nil
        lastError = nil

        guard let token = AuthManager.shared.token, !token.isEmpty else {
            shouldMaintainConnection = false
            lastError = "Missing auth token for sync websocket"
            addSystemMessage("Connection failed: not authenticated")
            AppLog.warning("🔌 [WebSocket] Missing auth token", category: .websocket)
            return
        }

        guard var components = URLComponents(url: wsBaseURL, resolvingAgainstBaseURL: false) else {
            lastError = "Invalid websocket URL"
            addSystemMessage("Connection failed: invalid websocket URL")
            AppLog.error("🔌 [WebSocket] Invalid websocket base URL", category: .websocket)
            return
        }
        components.queryItems = [URLQueryItem(name: "token", value: token)]

        guard let wsURL = components.url else {
            lastError = "Unable to construct authenticated websocket URL"
            addSystemMessage("Connection failed: invalid websocket auth URL")
            AppLog.error("🔌 [WebSocket] Could not construct authenticated URL", category: .websocket)
            return
        }

        AppLog.info("🔌 [WebSocket] Connecting to \(wsBaseURL.absoluteString)", category: .websocket)
        let nextTask = session.webSocketTask(with: wsURL)
        task = nextTask
        nextTask.resume()
        isConnected = true
        reconnectAttempt = 0

        addSystemMessage("Connected to sync server")
        receiveLoop(for: nextTask)
    }

    // MARK: - Disconnect

    func disconnect() {
        shouldMaintainConnection = false
        reconnectTask?.cancel()
        reconnectTask = nil

        AppLog.info("🔌 [WebSocket] Disconnect requested", category: .websocket)
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
        addSystemMessage("Disconnected")
    }

    // MARK: - Send

    func send(_ text: String) {
        guard let task, isConnected else { return }
        let message = URLSessionWebSocketTask.Message.string(text)
        appendMessage(WSMessage(text: text, isOutgoing: true, timestamp: .now))
        AppLog.debug("🔌 [WebSocket] Sending message (\(text.count) chars)", category: .websocket)
        task.send(message) { error in
            if let error {
                Task { @MainActor [weak self] in
                    self?.lastError = error.localizedDescription
                    AppLog.error("🔌 [WebSocket] Send failed: \(error.localizedDescription)", category: .websocket)
                }
            }
        }
    }

    // MARK: - Ping

    func ping() {
        task?.sendPing { error in
            Task { @MainActor [weak self] in
                if let error {
                    self?.addSystemMessage("Ping failed: \(error.localizedDescription)")
                    AppLog.warning("🔌 [WebSocket] Ping failed: \(error.localizedDescription)", category: .websocket)
                } else {
                    self?.addSystemMessage("Pong received ✓")
                    AppLog.debug("🔌 [WebSocket] Pong received", category: .websocket)
                }
            }
        }
    }

    // MARK: - Clear

    func clearMessages() {
        messages.removeAll()
    }

    // MARK: - Receive Loop

    private func receiveLoop(for currentTask: URLSessionWebSocketTask) {
        currentTask.receive { result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.task === currentTask else {
                    AppLog.debug("🔌 [WebSocket] Ignoring stale websocket callback", category: .websocket)
                    return
                }

                switch result {
                case .success(let msg):
                    switch msg {
                    case .string(let text):
                        self.appendMessage(WSMessage(text: text, isOutgoing: false, timestamp: .now))
                        self.handlePotentialServerEvent(from: text)
                        AppLog.debug("🔌 [WebSocket] Received text message (\(text.count) chars)", category: .websocket)
                    case .data(let data):
                        let text = String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
                        self.appendMessage(WSMessage(text: text, isOutgoing: false, timestamp: .now))
                        self.handlePotentialServerEvent(from: text)
                        AppLog.debug("🔌 [WebSocket] Received binary message (\(data.count) bytes)", category: .websocket)
                    @unknown default:
                        AppLog.warning("🔌 [WebSocket] Received unknown message type", category: .websocket)
                        break
                    }
                    self.receiveLoop(for: currentTask)

                case .failure(let error):
                    self.task = nil
                    self.isConnected = false
                    self.lastError = error.localizedDescription
                    self.addSystemMessage("Connection lost")
                    AppLog.error("🔌 [WebSocket] Connection lost: \(error.localizedDescription)", category: .websocket)
                    self.scheduleReconnectIfNeeded()
                }
            }
        }
    }

    private func scheduleReconnectIfNeeded() {
        guard shouldMaintainConnection else { return }
        guard reconnectTask == nil else { return }
        guard AuthManager.shared.token != nil else { return }

        reconnectAttempt += 1
        let delaySeconds = min(30, 1 << min(reconnectAttempt - 1, 4))
        addSystemMessage("Reconnecting in \(delaySeconds)s...")
        AppLog.warning("🔌 [WebSocket] Scheduling reconnect in \(delaySeconds)s", category: .websocket)

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
            await MainActor.run {
                guard let self else { return }
                self.reconnectTask = nil
                guard self.shouldMaintainConnection else { return }
                self.connect()
            }
        }
    }

    private func addSystemMessage(_ text: String) {
        appendMessage(WSMessage(text: "⚙️ \(text)", isOutgoing: false, timestamp: .now))
    }

    private func appendMessage(_ message: WSMessage) {
        messages.append(message)
        if messages.count > maxStoredMessages {
            messages.removeFirst(messages.count - maxStoredMessages)
        }
    }

    private func handlePotentialServerEvent(from rawText: String) {
        guard let data = rawText.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ServerEventPayload.self, from: data)
        else {
            return
        }

        guard Self.syncUpdateEventTypes.contains(payload.type) else { return }
        lastServerEventType = payload.type
        updateEventCounter += 1
    }
}

private struct ServerEventPayload: Decodable {
    let type: String
}
