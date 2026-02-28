import Foundation

struct EnrollResponse: Decodable {
    let deviceId: String
    let enrolledAt: Int
}

struct ServersResponse: Decodable {
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

private struct JobsResponse: Decodable {
    let jobs: [Job]
}

private struct JobUpsertResponse: Decodable {
    let job: Job
}

private struct SSHResponse: Decodable {
    let exitCode: Int
    let stdout: String
    let stderr: String
}

@MainActor
final class NetworkService {
    static let shared = NetworkService()

    private let deviceIdKey = "server_pilot_device_id"
    private let keyManager = DeviceKeyManager.shared
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    func enroll(code: String, deviceName: String) async throws -> EnrollResponse {
        try keyManager.ensureKeysExist()

        let keyAPem = try keyManager.exportPublicKeyPEM(for: .keyA)
        let keyBPem = try keyManager.exportPublicKeyPEM(for: .keyB)

        let body = [
            "code": code,
            "keyAPem": keyAPem,
            "keyBPem": keyBPem,
            "deviceName": deviceName,
        ]

        let data = try JSONSerialization.data(withJSONObject: body)
        return try await requestJSON(
            path: "/api/auth/enroll",
            method: "POST",
            bodyData: data,
            destructive: false,
            signed: false
        )
    }

    func fetchServers() async throws -> [ServerInfo] {
        let response: ServersResponse = try await requestJSON(
            path: "/api/servers",
            method: "GET",
            bodyData: nil,
            destructive: false,
            signed: true
        )
        return response.servers
    }

    func fetchMetrics(serverId: String) async throws -> SystemMetrics {
        try await requestJSON(
            path: "/api/servers/\(serverId)/metrics",
            method: "GET",
            bodyData: nil,
            destructive: false,
            signed: true
        )
    }

    func sendWake(serverId: String) async throws {
        _ = try await requestData(
            path: "/api/servers/\(serverId)/wake",
            method: "POST",
            bodyData: Data("{}".utf8),
            destructive: true,
            signed: true
        )
    }

    func fetchServices(serverId: String) async throws -> [ServiceStatus] {
        let response: ServicesResponse = try await requestJSON(
            path: "/api/servers/\(serverId)/services",
            method: "GET",
            bodyData: nil,
            destructive: false,
            signed: true
        )
        return response.services
    }

    func performServiceAction(serverId: String, serviceName: String, action: String) async throws {
        _ = try await requestData(
            path: "/api/servers/\(serverId)/services/\(serviceName)/\(action)",
            method: "POST",
            bodyData: Data("{}".utf8),
            destructive: true,
            signed: true
        )
    }

    func fetchContainers(serverId: String, all: Bool = true) async throws -> [Container] {
        let response: ContainersResponse = try await requestJSON(
            path: "/api/servers/\(serverId)/docker/containers?all=\(all ? "true" : "false")",
            method: "GET",
            bodyData: nil,
            destructive: false,
            signed: true
        )
        return response.containers
    }

    func fetchContainerLogs(serverId: String, containerId: String, lines: Int = 200) async throws -> String {
        let response: LogsResponse = try await requestJSON(
            path: "/api/servers/\(serverId)/docker/\(containerId)/logs?lines=\(lines)",
            method: "GET",
            bodyData: nil,
            destructive: false,
            signed: true
        )
        return response.logs
    }

    func performContainerAction(serverId: String, containerId: String, action: String) async throws {
        _ = try await requestData(
            path: "/api/servers/\(serverId)/docker/\(containerId)/\(action)",
            method: "POST",
            bodyData: Data("{}".utf8),
            destructive: true,
            signed: true
        )
    }

    func fetchGitRepos(serverId: String) async throws -> [GitRepoState] {
        let response: GitReposResponse = try await requestJSON(
            path: "/api/servers/\(serverId)/git",
            method: "GET",
            bodyData: nil,
            destructive: false,
            signed: true
        )
        return response.repos
    }

    func gitPull(serverId: String, repoName: String, force: Bool = false) async throws -> String {
        let body = ["repoName": repoName, "force": force] as [String: Any]
        let data = try JSONSerialization.data(withJSONObject: body)
        let response = try await requestData(
            path: "/api/servers/\(serverId)/git/pull",
            method: "POST",
            bodyData: data,
            destructive: true,
            signed: true
        )
        return String(data: response, encoding: .utf8) ?? ""
    }

    func gitCheckout(serverId: String, repoName: String, branch: String) async throws -> String {
        let body = ["repoName": repoName, "branch": branch]
        let data = try JSONSerialization.data(withJSONObject: body)
        let response = try await requestData(
            path: "/api/servers/\(serverId)/git/checkout",
            method: "POST",
            bodyData: data,
            destructive: true,
            signed: true
        )
        return String(data: response, encoding: .utf8) ?? ""
    }

    func fetchPackageState(serverId: String) async throws -> PackageState {
        try await requestJSON(
            path: "/api/servers/\(serverId)/packages",
            method: "GET",
            bodyData: nil,
            destructive: false,
            signed: true
        )
    }

    func recordPackageUpdate(serverId: String) async throws -> PackageState {
        try await requestJSON(
            path: "/api/servers/\(serverId)/packages/record",
            method: "POST",
            bodyData: Data("{}".utf8),
            destructive: true,
            signed: true
        )
    }

    func fetchJobs() async throws -> [Job] {
        let response: JobsResponse = try await requestJSON(
            path: "/api/jobs",
            method: "GET",
            bodyData: nil,
            destructive: false,
            signed: true
        )
        return response.jobs
    }

    func upsertJob(id: String, command: String, schedule: String, enabled: Bool = true) async throws -> Job {
        let body: [String: Any] = [
            "id": id,
            "command": command,
            "schedule": schedule,
            "enabled": enabled,
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let response: JobUpsertResponse = try await requestJSON(
            path: "/api/jobs",
            method: "POST",
            bodyData: data,
            destructive: true,
            signed: true
        )
        return response.job
    }

    func deleteJob(id: String) async throws {
        _ = try await requestData(
            path: "/api/jobs/\(id)",
            method: "DELETE",
            bodyData: Data("{}".utf8),
            destructive: true,
            signed: true
        )
    }

    func runSSHCommand(serverId: String, command: String) async throws -> SSHCommandResult {
        let body = ["command": command]
        let data = try JSONSerialization.data(withJSONObject: body)
        let response: SSHResponse = try await requestJSON(
            path: "/api/servers/\(serverId)/ssh",
            method: "POST",
            bodyData: data,
            destructive: true,
            signed: true
        )

        return SSHCommandResult(exitCode: response.exitCode, stdout: response.stdout, stderr: response.stderr)
    }

    func signedRequest(path: String, method: String, bodyData: Data?, destructive: Bool) throws -> URLRequest {
        try makeRequest(path: path, method: method, bodyData: bodyData, destructive: destructive, signed: true)
    }

    private func requestData(
        path: String,
        method: String,
        bodyData: Data?,
        destructive: Bool,
        signed: Bool
    ) async throws -> Data {
        let request = try makeRequest(path: path, method: method, bodyData: bodyData, destructive: destructive, signed: signed)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    private func requestJSON<T: Decodable>(
        path: String,
        method: String,
        bodyData: Data?,
        destructive: Bool,
        signed: Bool
    ) async throws -> T {
        let data = try await requestData(path: path, method: method, bodyData: bodyData, destructive: destructive, signed: signed)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func makeRequest(
        path: String,
        method: String,
        bodyData: Data?,
        destructive: Bool,
        signed: Bool
    ) throws -> URLRequest {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = bodyData ?? Data()
        if !payload.isEmpty {
            request.httpBody = payload
        }

        if signed {
            guard let deviceId = UserDefaults.standard.string(forKey: deviceIdKey) else {
                throw NSError(domain: "ServerPilot", code: 401, userInfo: [NSLocalizedDescriptionKey: "Device not enrolled"])
            }

            let signedHeaders = try keyManager.signRequest(
                deviceId: deviceId,
                method: method,
                url: url,
                bodyData: payload,
                destructive: destructive
            )

            request.setValue(signedHeaders.timestamp, forHTTPHeaderField: "X-Timestamp")
            request.setValue(signedHeaders.nonce, forHTTPHeaderField: "X-Nonce")
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
            request.setValue(signedHeaders.keyType, forHTTPHeaderField: "X-Key-Type")
            request.setValue(signedHeaders.signatureBase64, forHTTPHeaderField: "X-Signature")

            if destructive {
                request.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "Idempotency-Key")
            }
        }

        return request
    }

    private func buildURL(path: String) throws -> URL {
        guard var components = URLComponents(url: AppConfiguration.apiBaseURL, resolvingAgainstBaseURL: false) else {
            throw NSError(domain: "ServerPilot", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }

        let normalizedBase = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if normalizedBase.isEmpty {
            components.path = "/\(normalizedPath)"
        } else {
            components.path = "/\(normalizedBase)/\(normalizedPath)"
        }

        guard let url = components.url else {
            throw NSError(domain: "ServerPilot", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create URL"])
        }

        return url
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "ServerPilot", code: 500, userInfo: [NSLocalizedDescriptionKey: "Non-HTTP response"])
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw NSError(domain: "ServerPilot", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
