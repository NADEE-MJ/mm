import Foundation

struct IpaApp: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let serverId: String
    let serverName: String
    let ipaPath: String
    let copypartyConfigured: Bool
    let lastBuiltAt: String?
    let lastBuildExitCode: Int?
    let lastBuildOutput: String?

    var lastBuildSucceeded: Bool? {
        guard let code = lastBuildExitCode else { return nil }
        return code == 0
    }

    var lastBuiltDate: Date? {
        guard let s = lastBuiltAt else { return nil }
        return ISO8601DateFormatter().date(from: s)
    }
}

struct IpaShareLink: Codable {
    let url: String
    let expiresAt: String
    let ttlMinutes: Int
}

struct BuildResult: Codable {
    let ok: Bool
    let exitCode: Int
    let output: String?
    let builtAt: String
}
