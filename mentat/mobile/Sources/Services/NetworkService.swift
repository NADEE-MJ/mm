import Foundation
import LocalAuthentication

private struct ServersResponse: Decodable {
    let servers: [ServerInfo]
}

private struct ServicesResponse: Decodable {
    let services: [ServiceStatus]
}

private struct ContainersResponse: Decodable {
    let containers: [Container]
}

private struct LogsResponse: Decodable {
    let logs: String
}

private struct GitReposResponse: Decodable {
    let repos: [GitRepoState]
}

private struct GitOperationResponse: Decodable {
    let ok: Bool
    let exitCode: Int
    let output: String?
}

private struct JobsResponse: Decodable {
    let jobs: [Job]
}

private struct AppsResponse: Decodable {
    let apps: [IpaApp]
}

// MARK: - Tunnel-disconnected sentinel error

enum NetworkError: LocalizedError {
    case tunnelDisconnected
    case biometricFailed(String)

    var errorDescription: String? {
        switch self {
        case .tunnelDisconnected:
            return "SSH tunnel is not connected. Please wait for reconnection or check SSH settings."
        case .biometricFailed(let reason):
            return "Biometric authentication failed: \(reason)"
        }
    }
}

// MARK: - NetworkService

@MainActor
final class NetworkService {
    static let shared = NetworkService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    // MARK: - Servers

    func fetchServers() async throws -> [ServerInfo] {
        let response: ServersResponse = try await requestJSON(
            path: "/api/servers",
            method: "GET",
            bodyData: nil
        )
        return response.servers
    }

    func fetchMetrics(serverId: String) async throws -> SystemMetrics {
        try await requestJSON(
            path: "/api/servers/\(encodedPathSegment(serverId))/metrics",
            method: "GET",
            bodyData: nil
        )
    }

    func sendWake(serverId: String) async throws {
        _ = try await requestData(
            path: "/api/servers/\(encodedPathSegment(serverId))/wake",
            method: "POST",
            bodyData: Data("{}".utf8)
        )
    }

    // MARK: - Services

    func fetchServices(serverId: String) async throws -> [ServiceStatus] {
        let response: ServicesResponse = try await requestJSON(
            path: "/api/servers/\(encodedPathSegment(serverId))/services",
            method: "GET",
            bodyData: nil
        )
        return response.services
    }

    func performServiceAction(serverId: String, serviceName: String, action: String) async throws {
        _ = try await requestData(
            path: "/api/servers/\(encodedPathSegment(serverId))/services/\(encodedPathSegment(serviceName))/\(encodedPathSegment(action))",
            method: "POST",
            bodyData: Data("{}".utf8)
        )
    }

    // MARK: - Docker

    func fetchContainers(serverId: String, all: Bool = true) async throws -> [Container] {
        let response: ContainersResponse = try await requestJSON(
            path: "/api/servers/\(encodedPathSegment(serverId))/docker/containers?all=\(all ? "true" : "false")",
            method: "GET",
            bodyData: nil
        )
        return response.containers
    }

    func fetchContainerLogs(serverId: String, containerId: String, lines: Int = 200) async throws -> String {
        let response: LogsResponse = try await requestJSON(
            path: "/api/servers/\(encodedPathSegment(serverId))/docker/\(encodedPathSegment(containerId))/logs?lines=\(lines)",
            method: "GET",
            bodyData: nil
        )
        return response.logs
    }

    func performContainerAction(serverId: String, containerId: String, action: String) async throws {
        _ = try await requestData(
            path: "/api/servers/\(encodedPathSegment(serverId))/docker/\(encodedPathSegment(containerId))/\(encodedPathSegment(action))",
            method: "POST",
            bodyData: Data("{}".utf8)
        )
    }

    // MARK: - Git

    func fetchGitRepos(serverId: String) async throws -> [GitRepoState] {
        let response: GitReposResponse = try await requestJSON(
            path: "/api/servers/\(encodedPathSegment(serverId))/git",
            method: "GET",
            bodyData: nil
        )
        return response.repos
    }

    func gitPull(serverId: String, repoName: String, force: Bool = false) async throws -> String {
        let body: [String: Any] = ["repoName": repoName, "force": force]
        let data = try JSONSerialization.data(withJSONObject: body)
        let response: GitOperationResponse = try await requestJSON(
            path: "/api/servers/\(encodedPathSegment(serverId))/git/pull",
            method: "POST",
            bodyData: data
        )
        return response.output ?? (response.ok ? "Already up to date." : "Pull failed (exit \(response.exitCode))")
    }

    func gitCheckout(serverId: String, repoName: String, branch: String) async throws -> String {
        let body = ["repoName": repoName, "branch": branch]
        let data = try JSONSerialization.data(withJSONObject: body)
        let response: GitOperationResponse = try await requestJSON(
            path: "/api/servers/\(encodedPathSegment(serverId))/git/checkout",
            method: "POST",
            bodyData: data
        )
        return response.output ?? (response.ok ? "Switched to \(branch)." : "Checkout failed (exit \(response.exitCode))")
    }

    // MARK: - Packages

    func fetchPackageState(serverId: String) async throws -> PackageState {
        try await requestJSON(
            path: "/api/servers/\(encodedPathSegment(serverId))/packages",
            method: "GET",
            bodyData: nil
        )
    }

    func recordPackageUpdate(serverId: String) async throws -> PackageState {
        try await requestJSON(
            path: "/api/servers/\(encodedPathSegment(serverId))/packages/record",
            method: "POST",
            bodyData: Data("{}".utf8)
        )
    }

    // MARK: - Power

    func performPowerAction(serverId: String, action: String) async throws {
        _ = try await requestData(
            path: "/api/servers/\(encodedPathSegment(serverId))/power/\(encodedPathSegment(action))",
            method: "POST",
            bodyData: Data("{}".utf8)
        )
    }

    // MARK: - IPA Apps

    func fetchApps() async throws -> [IpaApp] {
        let response: AppsResponse = try await requestJSON(
            path: "/api/apps",
            method: "GET",
            bodyData: nil
        )
        return response.apps
    }

    func buildApp(serverId: String, appId: String) async throws -> BuildResult {
        try await requestJSON(
            path: "/api/apps/\(encodedPathSegment(serverId))/\(encodedPathSegment(appId))/build",
            method: "POST",
            bodyData: Data("{}".utf8)
        )
    }

    func shareApp(serverId: String, appId: String) async throws -> IpaShareLink {
        try await requestJSON(
            path: "/api/apps/\(encodedPathSegment(serverId))/\(encodedPathSegment(appId))/share",
            method: "POST",
            bodyData: Data("{}".utf8)
        )
    }

    // MARK: - Jobs

    func fetchJobs() async throws -> [Job] {
        let response: JobsResponse = try await requestJSON(
            path: "/api/jobs",
            method: "GET",
            bodyData: nil
        )
        return response.jobs
    }

    // MARK: - OpenCode

    func fetchOpenCodeSessions() async throws -> [OpenCodeSession] {
        let data = try await requestData(path: "/api/opencode/session", method: "GET", bodyData: nil)
        return try JSONDecoder().decode([OpenCodeSession].self, from: data)
    }

    func createOpenCodeSession(title: String? = nil) async throws -> OpenCodeSession {
        var body: [String: String] = [:]
        if let title { body["title"] = title }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await requestData(path: "/api/opencode/session", method: "POST", bodyData: bodyData)
        return try JSONDecoder().decode(OpenCodeSession.self, from: data)
    }

    func deleteOpenCodeSession(id: String) async throws {
        _ = try await requestData(
            path: "/api/opencode/session/\(encodedPathSegment(id))",
            method: "DELETE",
            bodyData: nil
        )
    }

    func fetchOpenCodeMessages(sessionId: String) async throws -> [OpenCodeMessageEnvelope] {
        let data = try await requestData(
            path: "/api/opencode/session/\(encodedPathSegment(sessionId))/message",
            method: "GET",
            bodyData: nil
        )
        // Response is { info: Message, parts: Part[] }[]
        return try JSONDecoder().decode([OpenCodeMessageEnvelope].self, from: data)
    }

    // Sends a message asynchronously (returns 204, no waiting for response).
    // SSE events deliver the streaming reply.
    func sendOpenCodeMessage(sessionId: String, text: String, modelRef: ModelRef? = nil, agent: String? = nil) async throws {
        let request = SendMessageRequest(
            parts: [SendMessageRequest.MessagePart(type: "text", text: text)],
            model: modelRef,
            agent: agent
        )
        let bodyData = try JSONEncoder().encode(request)
        _ = try await requestData(
            path: "/api/opencode/session/\(encodedPathSegment(sessionId))/message",
            method: "POST",
            bodyData: bodyData
        )
    }

    func abortOpenCodeSession(sessionId: String) async throws {
        _ = try await requestData(
            path: "/api/opencode/session/\(encodedPathSegment(sessionId))/command",
            method: "POST",
            bodyData: try JSONSerialization.data(withJSONObject: ["command": "session.interrupt"])
        )
    }

    func fetchOpenCodeProviders() async throws -> OpenCodeProviderList {
        let data = try await requestData(path: "/api/opencode/provider", method: "GET", bodyData: nil)
        return try JSONDecoder().decode(OpenCodeProviderList.self, from: data)
    }

    func fetchOpenCodeAgents() async throws -> [OpenCodeAgent] {
        let data = try await requestData(path: "/api/opencode/agent", method: "GET", bodyData: nil)
        return try JSONDecoder().decode([OpenCodeAgent].self, from: data)
    }

    func fetchOpenCodeConfig() async throws -> OpenCodeConfig {
        let data = try await requestData(path: "/api/opencode/config", method: "GET", bodyData: nil)
        return try JSONDecoder().decode(OpenCodeConfig.self, from: data)
    }

    func updateOpenCodeModel(providerID: String, modelID: String) async throws {
        let body = ["model": "\(providerID)/\(modelID)"]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await requestData(path: "/api/opencode/config", method: "PATCH", bodyData: bodyData)
    }

    func shareOpenCodeSession(sessionId: String) async throws -> String {
        let data = try await requestData(
            path: "/api/opencode/session/\(encodedPathSegment(sessionId))/share",
            method: "POST",
            bodyData: Data("{}".utf8)
        )
        let session = try JSONDecoder().decode(OpenCodeSession.self, from: data)
        return session.share?.url ?? ""
    }

    // Returns a URLRequest pointed at the SSE event endpoint, ready to use
    // with URLSession.bytes(for:) for streaming. No biometric check (read-only stream).
    func makeOpenCodeEventStreamRequest() throws -> URLRequest {
        try makeRequest(path: "/api/opencode/event", method: "GET", bodyData: nil)
    }

    // MARK: - Private request layer

    private func requestData(
        path: String,
        method: String,
        bodyData: Data?
    ) async throws -> Data {
        let request = try makeRequest(path: path, method: method, bodyData: bodyData)

        // Biometric gate for mutating requests.
        let mutatingMethods: Set<String> = ["POST", "PUT", "PATCH", "DELETE"]
        if mutatingMethods.contains(method.uppercased()) {
            try await requireBiometrics()
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    private func requestJSON<T: Decodable>(
        path: String,
        method: String,
        bodyData: Data?
    ) async throws -> T {
        let data = try await requestData(path: path, method: method, bodyData: bodyData)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func makeRequest(
        path: String,
        method: String,
        bodyData: Data?
    ) throws -> URLRequest {
        let tunnelPort = SSHConnectionManager.shared.tunnelPort
        guard tunnelPort > 0 else {
            throw NetworkError.tunnelDisconnected
        }

        guard let url = URL(string: "http://127.0.0.1:\(tunnelPort)")
                .flatMap({ base in
                    var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
                    let normalized = path.hasPrefix("/") ? path : "/\(path)"
                    // Split path from query string before assigning — URLComponents.path
                    // does not accept inline query strings and silently drops them.
                    if let queryStart = normalized.firstIndex(of: "?") {
                        components?.path = String(normalized[normalized.startIndex..<queryStart])
                        components?.query = String(normalized[normalized.index(after: queryStart)...])
                    } else {
                        components?.path = normalized
                    }
                    return components?.url
                })
        else {
            throw NSError(
                domain: "Mentat",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to construct request URL"]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let payload = bodyData, !payload.isEmpty {
            request.httpBody = payload
        }

        return request
    }

    private func requireBiometrics() async throws {
        let context = LAContext()
        var policyError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            let reason = policyError?.localizedDescription ?? "Biometrics unavailable"
            throw NetworkError.biometricFailed(reason)
        }

        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Confirm this action"
            )
        } catch {
            throw NetworkError.biometricFailed(error.localizedDescription)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Mentat", code: 500, userInfo: [NSLocalizedDescriptionKey: "Non-HTTP response"])
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw NSError(domain: "Mentat", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    // MARK: - URL helpers

    /// Percent-encodes a single path segment so that characters like `/`, `?`,
    /// and `#` cannot escape the segment and alter the request path.
    private func encodedPathSegment(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?
            .replacingOccurrences(of: "/", with: "%2F") ?? segment
    }
}
