import Foundation

// MARK: - WebSocket Manager
// Uses URLSessionWebSocketTask for real-time sync with the backend

@MainActor
@Observable
final class WebSocketManager {
    static let shared = WebSocketManager()

    private(set) var isConnected = false
    private(set) var messages: [WSMessage] = []
    private(set) var lastError: String?

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private let wsURL = AppConfiguration.webSocketURL

    struct WSMessage: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let isOutgoing: Bool
        let timestamp: Date
    }

    private init() {}

    // MARK: - Connect

    func connect() {
        guard !isConnected else { return }
        lastError = nil

        AppLog.info("🔌 [WebSocket] Connecting to \(wsURL.absoluteString)", category: .websocket)
        task = session.webSocketTask(with: wsURL)
        task?.resume()
        isConnected = true

        addSystemMessage("Connected to sync server")
        receiveLoop()
    }

    // MARK: - Disconnect

    func disconnect() {
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
        messages.append(WSMessage(text: text, isOutgoing: true, timestamp: .now))
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

    private func receiveLoop() {
        task?.receive { result in
            Task { @MainActor [weak self] in
                switch result {
                case .success(let msg):
                    switch msg {
                    case .string(let text):
                        self?.messages.append(WSMessage(text: text, isOutgoing: false, timestamp: .now))
                        AppLog.debug("🔌 [WebSocket] Received text message (\(text.count) chars)", category: .websocket)
                    case .data(let data):
                        let text = String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
                        self?.messages.append(WSMessage(text: text, isOutgoing: false, timestamp: .now))
                        AppLog.debug("🔌 [WebSocket] Received binary message (\(data.count) bytes)", category: .websocket)
                    @unknown default:
                        AppLog.warning("🔌 [WebSocket] Received unknown message type", category: .websocket)
                        break
                    }
                    self?.receiveLoop()

                case .failure(let error):
                    self?.isConnected = false
                    self?.lastError = error.localizedDescription
                    self?.addSystemMessage("Connection lost")
                    AppLog.error("🔌 [WebSocket] Connection lost: \(error.localizedDescription)", category: .websocket)
                }
            }
        }
    }

    private func addSystemMessage(_ text: String) {
        messages.append(WSMessage(text: "⚙️ \(text)", isOutgoing: false, timestamp: .now))
    }
}
