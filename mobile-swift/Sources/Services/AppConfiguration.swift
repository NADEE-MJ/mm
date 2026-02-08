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
              scheme == "https",
              let host = components.host?.lowercased(),
              !["localhost", "127.0.0.1", "::1"].contains(host)
        else {
            fatalError("Invalid API_BASE_URL '\(raw)'. Expected non-localhost https URL.")
        }

        return raw.hasSuffix("/") ? String(raw.dropLast()) : raw
    }()

    static let webSocketURL: URL = {
        guard let apiComponents = URLComponents(string: apiBaseURLString) else {
            fatalError("Invalid API_BASE_URL when creating websocket URL.")
        }

        var wsComponents = apiComponents
        wsComponents.scheme = "wss"
        wsComponents.path = "/ws"
        wsComponents.query = nil
        wsComponents.fragment = nil

        guard let url = wsComponents.url else {
            fatalError("Unable to construct websocket URL from API_BASE_URL.")
        }
        return url
    }()
}
