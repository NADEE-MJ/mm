import Foundation

enum AppConfiguration {
    static let apiBaseURLString: String = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !raw.isEmpty else {
            fatalError("Missing API_BASE_URL in Info.plist")
        }

        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased()
        else {
            fatalError("Invalid API_BASE_URL '\(raw)'")
        }

        #if DEBUG
        guard ["http", "https"].contains(scheme) else {
            fatalError("Invalid API_BASE_URL scheme")
        }
        #else
        guard scheme == "https", !["localhost", "127.0.0.1", "::1"].contains(host) else {
            fatalError("Release builds require non-localhost https API_BASE_URL")
        }
        #endif

        var normalizedComponents = components
        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if normalizedPath.isEmpty {
            normalizedComponents.path = "/api"
        } else if normalizedPath == "api" {
            normalizedComponents.path = "/api"
        } else {
            fatalError("API_BASE_URL must be base host URL or end with /api")
        }

        guard let normalizedURL = normalizedComponents.url else {
            fatalError("Unable to normalize API_BASE_URL")
        }
        return normalizedURL.absoluteString
    }()

    static let webSocketURL: URL = {
        guard let components = URLComponents(string: apiBaseURLString) else {
            fatalError("Invalid API_BASE_URL for websocket URL")
        }

        var wsComponents = components
        wsComponents.scheme = components.scheme == "https" ? "wss" : "ws"
        wsComponents.path = "/ws/sync"
        wsComponents.query = nil
        wsComponents.fragment = nil

        guard let url = wsComponents.url else {
            fatalError("Unable to construct websocket URL")
        }
        return url
    }()
}
