import Foundation

final class WebSocketManager {
    nonisolated(unsafe) static let shared = WebSocketManager()

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)

    private init() {}

    func connect(url: URL) {
        disconnect()
        task = session.webSocketTask(with: url)
        task?.resume()
        receiveNextMessage()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    func send(text: String) async {
        guard let task else { return }
        do {
            try await task.send(.string(text))
        } catch {
            AppLog.error("WebSocket send failed: \(error.localizedDescription)")
        }
    }

    private func receiveNextMessage() {
        task?.receive { [weak self] result in
            switch result {
            case .success:
                self?.receiveNextMessage()
            case .failure(let error):
                AppLog.error("WebSocket receive failed: \(error.localizedDescription)")
            }
        }
    }
}
