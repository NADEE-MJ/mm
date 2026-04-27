import Foundation

@MainActor
final class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()

    @Published private(set) var isConnected = false
    @Published private(set) var lastError: String?
    @Published private(set) var updateEventCounter = 0
    @Published private(set) var lastServerEventType: String?

    private static let syncEventTypes: Set<String> = [
        "sessionUpdated",
        "sessionCompleted",
        "templateUpdated",
        "exerciseUpdated",
        "scheduleUpdated",
    ]

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var shouldMaintainConnection = false

    private init() {}

    func connect() {
        shouldMaintainConnection = true
        guard !isConnected else { return }

        guard let token = AuthManager.shared.token, !token.isEmpty else {
            shouldMaintainConnection = false
            lastError = "Missing auth token"
            return
        }

        guard var components = URLComponents(url: AppConfiguration.webSocketURL, resolvingAgainstBaseURL: false) else {
            lastError = "Invalid websocket URL"
            return
        }
        components.queryItems = [URLQueryItem(name: "token", value: token)]

        guard let wsURL = components.url else {
            lastError = "Invalid websocket URL"
            return
        }

        reconnectTask?.cancel()
        reconnectTask = nil
        let nextTask = session.webSocketTask(with: wsURL)
        task = nextTask
        nextTask.resume()
        isConnected = true
        reconnectAttempt = 0
        lastError = nil
        listen(on: nextTask)
    }

    func disconnect() {
        shouldMaintainConnection = false
        reconnectTask?.cancel()
        reconnectTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
    }

    private func listen(on socketTask: URLSessionWebSocketTask) {
        socketTask.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                guard self.task === socketTask else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handle(message: text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handle(message: text)
                        }
                    @unknown default:
                        break
                    }
                    self.listen(on: socketTask)
                case .failure(let error):
                    self.isConnected = false
                    self.task = nil
                    self.lastError = error.localizedDescription
                    self.scheduleReconnectIfNeeded()
                }
            }
        }
    }

    private func handle(message rawText: String) {
        guard let data = rawText.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ServerEventPayload.self, from: data) else {
            return
        }

        guard Self.syncEventTypes.contains(payload.type) else { return }
        lastServerEventType = payload.type
        updateEventCounter += 1
    }

    private func scheduleReconnectIfNeeded() {
        guard shouldMaintainConnection else { return }
        guard reconnectTask == nil else { return }
        guard AuthManager.shared.isAuthenticated else { return }

        reconnectAttempt += 1
        let delaySeconds = min(30, 1 << min(reconnectAttempt - 1, 4))
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
}

private struct ServerEventPayload: Decodable {
    let type: String
}
