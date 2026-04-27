import Foundation

@MainActor
final class NetworkService {
    static let shared = NetworkService()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private(set) var lastError: String?

    private init() {
        session = URLSession(configuration: .default)
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: AppConfiguration.apiBaseURLString + path) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = AuthManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if http.statusCode == 401 {
                AuthManager.shared.logout()
                throw URLError(.userAuthenticationRequired)
            }

            guard (200...299).contains(http.statusCode) else {
                let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                throw NSError(domain: "NetworkService", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: detail,
                ])
            }

            let decoded = try decoder.decode(T.self, from: data)
            lastError = nil
            return decoded
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    private func requestVoid(
        _ path: String,
        method: String = "POST",
        body: Data? = nil,
        requiresAuth: Bool = true
    ) async throws {
        struct Empty: Decodable {}
        _ = try await request(path, method: method, body: body, requiresAuth: requiresAuth) as Empty
    }

    func login(email: String, password: String) async throws -> LoginEnvelope {
        let data = try encoder.encode(["email": email, "password": password])
        return try await request("/auth/login", method: "POST", body: data, requiresAuth: false)
    }

    func verifyToken() async throws -> UserProfile {
        try await request("/auth/me")
    }

    func updateProfile(unitPreference: String, barbellWeight: Double) async throws -> UserProfile {
        let payload: [String: AnyCodable] = [
            "unit_preference": AnyCodable(unitPreference),
            "barbell_weight": AnyCodable(barbellWeight),
        ]
        let body = try encoder.encode(payload)
        return try await request("/auth/me", method: "PUT", body: body)
    }

    func fetchWorkoutTypes() async throws -> [WorkoutType] {
        try await request("/workout-types")
    }

    func fetchExercises() async throws -> [Exercise] {
        try await request("/exercises")
    }

    func createExercise(payload: [String: AnyCodable]) async throws -> Exercise {
        let body = try encoder.encode(payload)
        return try await request("/exercises", method: "POST", body: body)
    }

    func updateExercise(id: String, payload: [String: AnyCodable]) async throws -> Exercise {
        let body = try encoder.encode(payload)
        return try await request("/exercises/\(id)", method: "PUT", body: body)
    }

    func deleteExercise(id: String) async throws {
        try await requestVoid("/exercises/\(id)", method: "DELETE")
    }

    func fetchTemplates() async throws -> [WorkoutTemplate] {
        try await request("/templates")
    }

    func fetchTemplate(id: String) async throws -> WorkoutTemplate {
        try await request("/templates/\(id)")
    }

    func createTemplate(payload: [String: AnyCodable]) async throws -> WorkoutTemplate {
        let body = try encoder.encode(payload)
        return try await request("/templates", method: "POST", body: body)
    }

    func deleteTemplate(id: String) async throws {
        try await requestVoid("/templates/\(id)", method: "DELETE")
    }

    func addTemplateExercise(templateId: String, payload: [String: AnyCodable]) async throws -> TemplateExercise {
        let body = try encoder.encode(payload)
        return try await request("/templates/\(templateId)/exercises", method: "POST", body: body)
    }

    func updateTemplateExercise(templateId: String, templateExerciseId: String, payload: [String: AnyCodable]) async throws {
        let body = try encoder.encode(payload)
        let _: TemplateExercise = try await request("/templates/\(templateId)/exercises/\(templateExerciseId)", method: "PUT", body: body)
    }

    func fetchSchedule() async throws -> [WeeklyScheduleEntry] {
        try await request("/schedule")
    }

    func updateSchedule(entries: [[String: AnyCodable]]) async throws -> [WeeklyScheduleEntry] {
        let body = try encoder.encode(["entries": entries])
        return try await request("/schedule", method: "PUT", body: body)
    }

    func fetchSessions() async throws -> [WorkoutSession] {
        try await request("/sessions")
    }

    func startSession(payload: [String: AnyCodable]) async throws -> WorkoutSession {
        let body = try encoder.encode(payload)
        return try await request("/sessions", method: "POST", body: body)
    }

    func fetchSession(id: String) async throws -> WorkoutSession {
        try await request("/sessions/\(id)")
    }

    func deleteSession(id: String) async throws {
        try await requestVoid("/sessions/\(id)", method: "DELETE")
    }

    func addSessionExercise(sessionId: String, payload: [String: AnyCodable]) async throws -> SessionExercise {
        let body = try encoder.encode(payload)
        return try await request("/sessions/\(sessionId)/exercises", method: "POST", body: body)
    }

    func deleteSet(sessionId: String, sessionExerciseId: String, setId: String) async throws {
        try await requestVoid(
            "/sessions/\(sessionId)/exercises/\(sessionExerciseId)/sets/\(setId)",
            method: "DELETE"
        )
    }

    func completeSession(id: String, finishedAt: Double? = nil) async throws -> WorkoutSession {
        var payload: [String: AnyCodable] = [:]
        if let finishedAt {
            payload["finished_at"] = AnyCodable(finishedAt)
        }
        let body = try encoder.encode(payload)
        let envelope: CompleteSessionEnvelope = try await request(
            "/sessions/\(id)/complete",
            method: "POST",
            body: body
        )
        return envelope.session
    }

    func fetchMetricsSummary() async throws -> MetricsSummary {
        try await request("/metrics/summary")
    }

    func fetchExerciseProgress(id: String) async throws -> [ExerciseProgressPoint] {
        try await request("/metrics/exercise/\(id)")
    }

    func fetchChanges(since: Double, limit: Int = 500, offset: Int = 0) async throws -> SyncChangesEnvelope {
        try await request("/sync/changes?since=\(since)&limit=\(limit)&offset=\(offset)")
    }

    func batchSync(actions: [SyncBatchAction]) async throws -> SyncBatchResponseEnvelope {
        let payload = SyncBatchRequest(actions: actions)
        let body = try encoder.encode(payload)
        return try await request("/sync/batch", method: "POST", body: body)
    }

    func exportBackup() async throws -> [String: AnyCodable] {
        try await request("/backup/export")
    }

    func importBackup(payload: [String: AnyCodable]) async throws {
        let body = try encoder.encode(payload)
        try await requestVoid("/backup/import", method: "POST", body: body)
    }

    func getBackupSettings() async throws -> [String: AnyCodable] {
        try await request("/backup/settings")
    }

    func updateBackupSettings(enabled: Bool) async throws -> [String: AnyCodable] {
        let body = try encoder.encode(["backup_enabled": AnyCodable(enabled)])
        return try await request("/backup/settings", method: "PUT", body: body)
    }
}

struct SyncChangesEnvelope: Codable {
    var workoutTypes: [WorkoutType]
    var exercises: [Exercise]
    var templates: [WorkoutTemplate]
    var schedule: [WeeklyScheduleEntry]
    var sessions: [WorkoutSession]
    var hasMore: Bool
    var nextOffset: Int?
    var serverTimestamp: Double

    enum CodingKeys: String, CodingKey {
        case workoutTypes = "workout_types"
        case exercises
        case templates
        case schedule
        case sessions
        case hasMore = "has_more"
        case nextOffset = "next_offset"
        case serverTimestamp = "server_timestamp"
    }
}

struct SyncBatchRequest: Codable {
    let actions: [SyncBatchAction]
    let clientTimestamp: Double

    init(actions: [SyncBatchAction]) {
        self.actions = actions
        self.clientTimestamp = Date().timeIntervalSince1970
    }

    enum CodingKeys: String, CodingKey {
        case actions
        case clientTimestamp = "client_timestamp"
    }
}

struct SyncBatchAction: Codable {
    let action: String
    let data: [String: AnyCodable]
    let timestamp: Double

    init(action: String, data: [String: AnyCodable], timestamp: Double = Date().timeIntervalSince1970) {
        self.action = action
        self.data = data
        self.timestamp = timestamp
    }
}

struct SyncBatchResponseEnvelope: Codable {
    var results: [SyncBatchResult]
    var serverTimestamp: Double

    enum CodingKeys: String, CodingKey {
        case results
        case serverTimestamp = "server_timestamp"
    }
}

struct SyncBatchResult: Codable {
    var success: Bool
    var lastModified: Double?
    var error: String?
    var conflict: Bool

    enum CodingKeys: String, CodingKey {
        case success, error, conflict
        case lastModified = "last_modified"
    }
}

struct CompleteSessionEnvelope: Codable {
    var session: WorkoutSession
}

struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self.value = value
        } else if let value = try? container.decode([AnyCodable].self) {
            self.value = value
        } else {
            self.value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let value as String: try container.encode(value)
        case let value as Int: try container.encode(value)
        case let value as Double: try container.encode(value)
        case let value as Bool: try container.encode(value)
        case let value as [String: AnyCodable]: try container.encode(value)
        case let value as [AnyCodable]: try container.encode(value)
        case let value as [String: Any]:
            let converted = value.mapValues { AnyCodable($0) }
            try container.encode(converted)
        case let value as [Any]:
            let converted = value.map { AnyCodable($0) }
            try container.encode(converted)
        default: try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}
