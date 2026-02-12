import Foundation

enum AppConfiguration {
    static let apiBaseURLString: String = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !raw.isEmpty else {
            fatalError("Missing API_BASE_URL in Info.plist. CI must inject MOBILE_SWIFT_API_BASE_URL.")
        }

        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased()
        else {
            fatalError("Invalid API_BASE_URL '\(raw)'. Expected valid URL.")
        }

        #if DEBUG
        // Debug builds: allow http/https and localhost
        guard ["http", "https"].contains(scheme) else {
            fatalError("Invalid API_BASE_URL '\(raw)'. Expected http or https scheme.")
        }
        #else
        // Release builds: require https and non-localhost
        guard scheme == "https",
              !["localhost", "127.0.0.1", "::1"].contains(host)
        else {
            fatalError("Invalid API_BASE_URL '\(raw)'. Expected non-localhost https URL.")
        }
        #endif

        var normalizedComponents = components
        normalizedComponents.query = nil
        normalizedComponents.fragment = nil

        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if normalizedPath.isEmpty {
            normalizedComponents.path = "/api"
        } else if normalizedPath == "api" {
            normalizedComponents.path = "/api"
        } else {
            fatalError("Invalid API_BASE_URL '\(raw)'. Expected base host URL or URL ending with '/api'.")
        }

        guard let normalizedURL = normalizedComponents.url else {
            fatalError("Unable to normalize API_BASE_URL '\(raw)'.")
        }

        return normalizedURL.absoluteString
    }()

    static let webSocketURL: URL = {
        guard let apiComponents = URLComponents(string: apiBaseURLString) else {
            fatalError("Invalid API_BASE_URL when creating websocket URL.")
        }

        var wsComponents = apiComponents
        // Use ws:// for http and wss:// for https
        wsComponents.scheme = apiComponents.scheme == "https" ? "wss" : "ws"
        wsComponents.path = "/ws/sync"
        wsComponents.query = nil
        wsComponents.fragment = nil

        guard let url = wsComponents.url else {
            fatalError("Unable to construct websocket URL from API_BASE_URL.")
        }
        return url
    }()
}
