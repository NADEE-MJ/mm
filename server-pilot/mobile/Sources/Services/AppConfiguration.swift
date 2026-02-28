import Foundation

enum AppConfiguration {
    static let apiBaseURL: URL = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !raw.isEmpty, let url = URL(string: raw) else {
            fatalError("Missing or invalid API_BASE_URL in Info.plist")
        }

        guard let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased()
        else {
            fatalError("API_BASE_URL must include scheme and host")
        }

        guard ["http", "https"].contains(scheme) else {
            fatalError("API_BASE_URL must use http/https")
        }

        #if !DEBUG
        guard isTailscaleHost(host) else {
            fatalError("Release API_BASE_URL must be a Tailscale host/ip")
        }
        #endif

        return url
    }()

    private static func isTailscaleHost(_ host: String) -> Bool {
        if host.hasSuffix(".ts.net") {
            return true
        }

        let parts = host.split(separator: ".")
        if parts.count == 4,
           let first = Int(parts[0]),
           let second = Int(parts[1]),
           first == 100,
           (64...127).contains(second) {
            return true
        }

        return false
    }
}
