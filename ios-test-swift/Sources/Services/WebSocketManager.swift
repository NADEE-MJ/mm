import Foundation

// MARK: - WebSocket Manager
// Uses URLSessionWebSocketTask (built into Foundation) to demonstrate
// a real-time bidirectional connection.
// Connects to a public echo server for demo purposes.

@Observable
final class WebSocketManager {
    static let shared = WebSocketManager()

    private(set) var isConnected = false
    private(set) var messages: [WSMessage] = []
    private(set) var lastError: String?

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)

    // Public echo server (sends back whatever you send)
    private let echoURL = URL(string: "wss://echo.websocket.org")!

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

        task = session.webSocketTask(with: echoURL)
        task?.resume()
        isConnected = true

        addSystemMessage("Connected to echo server")
        receiveLoop()
    }

    // MARK: - Disconnect

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
        addSystemMessage("Disconnected")
    }

    // MARK: - Send

    func send(_ text: String) {
        guard let task, isConnected else { return }
        let message = URLSessionWebSocketTask.Message.string(text)
        task.send(message) { [weak self] error in
            if let error {
                Task { @MainActor in
                    self?.lastError = error.localizedDescription
                }
            }
        }
        messages.append(WSMessage(text: text, isOutgoing: true, timestamp: .now))
    }

    // MARK: - Ping

    func ping() {
        task?.sendPing { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.addSystemMessage("Ping failed: \(error.localizedDescription)")
                } else {
                    self?.addSystemMessage("Pong received ✓")
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
        task?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let msg):
                    switch msg {
                    case .string(let text):
                        self?.messages.append(WSMessage(text: text, isOutgoing: false, timestamp: .now))
                    case .data(let data):
                        let text = String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
                        self?.messages.append(WSMessage(text: text, isOutgoing: false, timestamp: .now))
                    @unknown default:
                        break
                    }
                    // Continue listening
                    self?.receiveLoop()

                case .failure(let error):
                    self?.isConnected = false
                    self?.lastError = error.localizedDescription
                    self?.addSystemMessage("Connection lost")
                }
            }
        }
    }

    private func addSystemMessage(_ text: String) {
        messages.append(WSMessage(text: "⚙️ \(text)", isOutgoing: false, timestamp: .now))
    }
}
