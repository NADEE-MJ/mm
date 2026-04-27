import Foundation

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published private(set) var isSyncing = false
    @Published private(set) var pendingCount = 0
    @Published private(set) var pendingOperations: [PendingOperationPreview] = []
    @Published private(set) var recentIssues: [SyncIssue] = []
    @Published private(set) var lastRunAt: Date?
    @Published private(set) var lastRunSummary: SyncRunSummary?

    var unresolvedIssueCount: Int { recentIssues.count }
    var conflictCount: Int { recentIssues.filter(\.isConflict).count }

    private let databaseManager = DatabaseManager.shared
    private let networkService = NetworkService.shared
    private var issuesByOperationID: [String: SyncIssue] = [:]

    private init() {
        refreshPendingState()
    }

    @discardableResult
    func processPendingOperations() async -> Bool {
        guard !isSyncing else { return false }

        isSyncing = true
        defer {
            isSyncing = false
            refreshPendingState()
        }

        let pending = databaseManager.fetchPendingOperations()
        guard !pending.isEmpty else {
            lastRunAt = Date()
            lastRunSummary = SyncRunSummary(
                processed: 0,
                succeeded: 0,
                failed: 0,
                conflicts: 0,
                dropped: 0
            )
            return false
        }

        var didMutateRemoteData = false
        var processed = 0
        var succeeded = 0
        var failed = 0
        var conflicts = 0
        var dropped = 0

        for operation in pending {
            processed += 1
            do {
                let result = try await process(operation: operation)

                switch result {
                case .success:
                    didMutateRemoteData = true
                    succeeded += 1
                    clearIssue(for: operation.id)
                    databaseManager.deletePendingOperation(id: operation.id)

                case .conflict(let message):
                    failed += 1
                    conflicts += 1
                    addIssue(
                        operation: operation,
                        message: message,
                        isConflict: true
                    )

                    if operation.retryCount >= 3 {
                        dropped += 1
                        databaseManager.deletePendingOperation(id: operation.id)
                        addIssue(
                            operation: operation,
                            message: "Dropped after 3 retries due to conflict.",
                            isConflict: true
                        )
                    } else {
                        databaseManager.incrementRetryCount(id: operation.id)
                    }

                case .failure(let message):
                    failed += 1
                    addIssue(
                        operation: operation,
                        message: message,
                        isConflict: false
                    )

                    if operation.retryCount >= 3 {
                        dropped += 1
                        databaseManager.deletePendingOperation(id: operation.id)
                        addIssue(
                            operation: operation,
                            message: "Dropped after 3 retries: \(message)",
                            isConflict: false
                        )
                    } else {
                        databaseManager.incrementRetryCount(id: operation.id)
                    }
                }
            } catch {
                failed += 1
                let message = error.localizedDescription
                AppLog.error("Pending op failed \(operation.type): \(message)", category: .sync)
                addIssue(operation: operation, message: message, isConflict: false)

                if operation.retryCount >= 3 {
                    dropped += 1
                    databaseManager.deletePendingOperation(id: operation.id)
                    addIssue(
                        operation: operation,
                        message: "Dropped after 3 retries: \(message)",
                        isConflict: false
                    )
                } else {
                    databaseManager.incrementRetryCount(id: operation.id)
                }

                if isLikelyConnectivityIssue(message) {
                    break
                }
            }
        }

        lastRunAt = Date()
        lastRunSummary = SyncRunSummary(
            processed: processed,
            succeeded: succeeded,
            failed: failed,
            conflicts: conflicts,
            dropped: dropped
        )
        publishIssues()
        return didMutateRemoteData
    }

    func clearIssues() {
        issuesByOperationID.removeAll()
        recentIssues = []
    }

    func refreshState() {
        refreshPendingState()
    }

    private func process(operation: DatabaseManager.PendingOperation) async throws -> OperationProcessResult {
        switch operation.type {
        case "batch_action":
            guard let payload: QueuedBatchAction = decode(operation.payload) else {
                return .failure("Invalid batch action payload")
            }
            let response = try await networkService.batchSync(actions: [
                SyncBatchAction(action: payload.action, data: payload.data),
            ])
            return parseBatchResponse(response.results.first)

        case "log_set":
            guard let payload = decodeJsonObject(operation.payload) else {
                return .failure("Invalid log set payload")
            }
            let response = try await networkService.batchSync(actions: [
                SyncBatchAction(action: "logSet", data: payload),
            ])
            return parseBatchResponse(response.results.first)

        case "delete_set":
            guard let payload = decodeJsonObject(operation.payload),
                  let sessionId = payload["session_id"]?.value as? String,
                  let sessionExerciseId = payload["session_exercise_id"]?.value as? String,
                  let setId = payload["set_id"]?.value as? String else {
                return .failure("Invalid delete_set payload")
            }
            try await networkService.deleteSet(
                sessionId: sessionId,
                sessionExerciseId: sessionExerciseId,
                setId: setId
            )
            return .success

        case "complete_session":
            guard let payload = decodeJsonObject(operation.payload),
                  let id = payload["id"]?.value as? String else {
                return .failure("Invalid complete_session payload")
            }
            let finishedAt = payload["finished_at"]?.value as? Double
            _ = try await networkService.completeSession(id: id, finishedAt: finishedAt)
            return .success

        case "update_schedule":
            guard let payload = decodeJsonObject(operation.payload),
                  let entriesValue = payload["entries"]?.value else {
                return .failure("Invalid update_schedule payload")
            }

            let rawEntries: [[String: AnyCodable]]
            if let direct = entriesValue as? [[String: AnyCodable]] {
                rawEntries = direct
            } else if let wrapped = entriesValue as? [AnyCodable] {
                rawEntries = wrapped.compactMap { $0.value as? [String: AnyCodable] }
            } else {
                return .failure("Invalid schedule entries format")
            }

            _ = try await networkService.updateSchedule(entries: rawEntries)
            return .success

        case "upload_session_snapshot":
            guard let snapshot: QueuedSessionSnapshot = decode(operation.payload) else {
                return .failure("Invalid upload_session_snapshot payload")
            }
            let uploaded = try await uploadLocalSessionSnapshot(snapshot)
            return uploaded ? .success : .failure("Session snapshot upload failed")

        default:
            return .failure("Unsupported operation: \(operation.type)")
        }
    }

    private func uploadLocalSessionSnapshot(_ snapshot: QueuedSessionSnapshot) async throws -> Bool {
        let startPayload: [String: AnyCodable] = [
            "template_id": AnyCodable(snapshot.session.templateId as Any),
            "date": AnyCodable(snapshot.session.date),
            "notes": AnyCodable(snapshot.session.notes as Any),
        ]
        let started = try await networkService.startSession(payload: startPayload)
        var remoteSession = try await networkService.fetchSession(id: started.id)

        for localExercise in snapshot.session.exercises.sorted(by: { $0.position < $1.position }) {
            var remoteExerciseId = remoteSession.exercises.first(where: { $0.exerciseId == localExercise.exerciseId })?.id
            if remoteExerciseId == nil {
                let createPayload: [String: AnyCodable] = [
                    "exercise_id": AnyCodable(localExercise.exerciseId),
                    "position": AnyCodable(localExercise.position),
                    "notes": AnyCodable(localExercise.notes as Any),
                ]
                let created = try await networkService.addSessionExercise(sessionId: remoteSession.id, payload: createPayload)
                remoteExerciseId = created.id
            }

            guard let remoteExerciseId else { continue }
            for set in localExercise.sets {
                var setPayload: [String: AnyCodable] = [
                    "session_id": AnyCodable(remoteSession.id),
                    "session_exercise_id": AnyCodable(remoteExerciseId),
                    "exercise_id": AnyCodable(localExercise.exerciseId),
                    "set_number": AnyCodable(set.setNumber),
                    "is_warmup": AnyCodable(set.isWarmup),
                    "used_accessories": AnyCodable(set.usedAccessories),
                    "band_color": AnyCodable(set.bandColor as Any),
                    "completed": AnyCodable(set.completed),
                ]
                if let reps = set.reps {
                    setPayload["reps"] = AnyCodable(reps)
                }
                if let weight = set.weight {
                    setPayload["weight"] = AnyCodable(weight)
                }
                if let duration = set.durationSecs {
                    setPayload["duration_secs"] = AnyCodable(duration)
                }
                if let distance = set.distance {
                    setPayload["distance"] = AnyCodable(distance)
                }

                let response = try await networkService.batchSync(actions: [
                    SyncBatchAction(action: "logSet", data: setPayload),
                ])
                let parsed = parseBatchResponse(response.results.first)
                switch parsed {
                case .success:
                    break
                case .conflict(let message):
                    throw NSError(domain: "SyncManager", code: 409, userInfo: [NSLocalizedDescriptionKey: message])
                case .failure(let message):
                    throw NSError(domain: "SyncManager", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
                }
            }
        }

        if snapshot.session.status == "completed" {
            _ = try await networkService.completeSession(id: remoteSession.id)
        }

        remoteSession = try await networkService.fetchSession(id: remoteSession.id)
        WorkoutRepository.shared.replaceLocalOnlySession(localId: snapshot.localSessionId, with: remoteSession)
        return true
    }

    private func parseBatchResponse(_ result: SyncBatchResult?) -> OperationProcessResult {
        guard let result else {
            return .failure("Empty sync response")
        }

        if result.success {
            return .success
        }
        if result.conflict {
            return .conflict(result.error ?? "Server conflict detected")
        }
        return .failure(result.error ?? "Sync action failed")
    }

    private func refreshPendingState() {
        let pending = databaseManager.fetchPendingOperations()
        pendingCount = pending.count
        pendingOperations = pending.map { operation in
            PendingOperationPreview(
                id: operation.id,
                type: operation.type,
                createdAt: Date(timeIntervalSince1970: operation.createdAt),
                retryCount: operation.retryCount
            )
        }
        publishIssues()
    }

    private func addIssue(operation: DatabaseManager.PendingOperation, message: String, isConflict: Bool) {
        let existing = issuesByOperationID[operation.id]
        let issue = SyncIssue(
            id: operation.id,
            operationType: operation.type,
            message: message,
            isConflict: isConflict,
            retryCount: operation.retryCount + 1,
            firstSeenAt: existing?.firstSeenAt ?? Date(),
            lastUpdatedAt: Date()
        )
        issuesByOperationID[operation.id] = issue
        publishIssues()
    }

    private func clearIssue(for operationID: String) {
        issuesByOperationID.removeValue(forKey: operationID)
        publishIssues()
    }

    private func publishIssues() {
        recentIssues = issuesByOperationID.values
            .sorted(by: { $0.lastUpdatedAt > $1.lastUpdatedAt })
    }

    private func decodeJsonObject(_ payload: String) -> [String: AnyCodable]? {
        guard let data = payload.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: AnyCodable].self, from: data) else {
            return nil
        }
        return decoded
    }

    private func decode<T: Decodable>(_ payload: String) -> T? {
        guard let data = payload.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func isLikelyConnectivityIssue(_ message: String) -> Bool {
        let value = message.lowercased()
        let markers = [
            "offline",
            "internet",
            "not connected",
            "cannot connect",
            "connection",
            "timed out",
            "dns",
            "network",
            "socket",
        ]
        return markers.contains { value.contains($0) }
    }
}

private enum OperationProcessResult {
    case success
    case conflict(String)
    case failure(String)
}

struct PendingOperationPreview: Identifiable, Hashable {
    let id: String
    let type: String
    let createdAt: Date
    let retryCount: Int
}

struct SyncIssue: Identifiable, Hashable {
    let id: String
    let operationType: String
    let message: String
    let isConflict: Bool
    let retryCount: Int
    let firstSeenAt: Date
    let lastUpdatedAt: Date
}

struct SyncRunSummary: Hashable {
    let processed: Int
    let succeeded: Int
    let failed: Int
    let conflicts: Int
    let dropped: Int
}

struct QueuedBatchAction: Codable {
    let action: String
    let data: [String: AnyCodable]
}

struct QueuedSessionSnapshot: Codable {
    let localSessionId: String
    let session: WorkoutSession
}
