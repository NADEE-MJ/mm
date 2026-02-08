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

    // TODO: Replace with actual WebSocket URL
    private let wsURL = URL(string: "ws://localhost:8000/ws")!

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

        task = session.webSocketTask(with: wsURL)
        task?.resume()
        isConnected = true

        addSystemMessage("Connected to sync server")
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
        messages.append(WSMessage(text: text, isOutgoing: true, timestamp: .now))
        task.send(message) { error in
            if let error {
                Task { @MainActor [weak self] in
                    self?.lastError = error.localizedDescription
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
        task?.receive { result in
            Task { @MainActor [weak self] in
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
