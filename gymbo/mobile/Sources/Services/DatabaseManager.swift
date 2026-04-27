import Foundation
import GRDB

@MainActor
final class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()

    private let dbQueue: DatabaseQueue

    @Published private(set) var cachedWorkoutTypes: [CachedWorkoutType] = []
    @Published private(set) var cachedExercises: [CachedExercise] = []
    @Published private(set) var cachedTemplates: [CachedTemplate] = []
    @Published private(set) var cachedSchedule: [CachedScheduleEntry] = []
    @Published private(set) var cachedSessions: [CachedSession] = []
    @Published private(set) var cachedMetricsSummary: MetricsSummary?
    @Published private(set) var pendingOperationsCount = 0

    struct CachedWorkoutType: FetchableRecord, PersistableRecord, Codable, Identifiable {
        static let databaseTableName = "workout_types"

        var id: String
        var name: String
        var slug: String
        var icon: String?
        var color: String?
        var isSystem: Bool
        var userId: String?
        var lastModified: Double

        enum CodingKeys: String, CodingKey {
            case id, name, slug, icon, color
            case isSystem = "is_system"
            case userId = "user_id"
            case lastModified = "last_modified"
        }
    }

    struct CachedExercise: FetchableRecord, PersistableRecord, Codable, Identifiable {
        static let databaseTableName = "exercises"

        var id: String
        var name: String
        var description: String?
        var videoURL: String?
        var muscleGroups: Int
        var workoutType: Int?
        var weightType: Int
        var warmupSets: Int
        var accessoriesJSON: String
        var goalRepsMin: Int?
        var goalRepsMax: Int?
        var showHighestSet: Bool
        var trackHighestSet: Bool
        var highestSetWeight: Double?
        var highestSetReps: Int?
        var showOneRepMax: Bool
        var trackOneRepMax: Bool
        var oneRepMax: Double?
        var isSystem: Bool
        var userId: String?
        var sourceExerciseId: String?
        var lastModified: Double

        enum CodingKeys: String, CodingKey {
            case id, name, description
            case videoURL = "video_url"
            case muscleGroups = "muscle_groups"
            case workoutType = "workout_type"
            case weightType = "weight_type"
            case warmupSets = "warmup_sets"
            case accessoriesJSON = "accessories_json"
            case goalRepsMin = "goal_reps_min"
            case goalRepsMax = "goal_reps_max"
            case showHighestSet = "show_highest_set"
            case trackHighestSet = "track_highest_set"
            case highestSetWeight = "highest_set_weight"
            case highestSetReps = "highest_set_reps"
            case showOneRepMax = "show_one_rep_max"
            case trackOneRepMax = "track_one_rep_max"
            case oneRepMax = "one_rep_max"
            case isSystem = "is_system"
            case userId = "user_id"
            case sourceExerciseId = "source_exercise_id"
            case lastModified = "last_modified"
        }
    }

    struct CachedTemplate: FetchableRecord, PersistableRecord, Codable, Identifiable {
        static let databaseTableName = "workout_templates"

        var id: String
        var name: String
        var description: String?
        var workoutTypeId: String?
        var isSystem: Bool
        var userId: String?
        var lastModified: Double
        var jsonData: String

        enum CodingKeys: String, CodingKey {
            case id, name, description
            case workoutTypeId = "workout_type_id"
            case isSystem = "is_system"
            case userId = "user_id"
            case lastModified = "last_modified"
            case jsonData = "json_data"
        }
    }

    struct CachedScheduleEntry: FetchableRecord, PersistableRecord, Codable, Identifiable {
        static let databaseTableName = "weekly_schedule"

        var id: String
        var dayOfWeek: Int
        var templateId: String?
        var lastModified: Double

        enum CodingKeys: String, CodingKey {
            case id
            case dayOfWeek = "day_of_week"
            case templateId = "template_id"
            case lastModified = "last_modified"
        }
    }

    struct CachedSession: FetchableRecord, PersistableRecord, Codable, Identifiable {
        static let databaseTableName = "workout_sessions"

        var id: String
        var templateId: String?
        var date: Double
        var startedAt: Double?
        var finishedAt: Double?
        var durationSecs: Int?
        var notes: String?
        var status: String
        var lastModified: Double
        var isLocalOnly: Bool
        var jsonData: String

        enum CodingKeys: String, CodingKey {
            case id, date, notes, status
            case templateId = "template_id"
            case startedAt = "started_at"
            case finishedAt = "finished_at"
            case durationSecs = "duration_secs"
            case lastModified = "last_modified"
            case isLocalOnly = "is_local_only"
            case jsonData = "json_data"
        }
    }

    struct PendingOperation: FetchableRecord, PersistableRecord, Codable, Identifiable {
        static let databaseTableName = "pending_operations"

        var id: String
        var type: String
        var payload: String
        var createdAt: Double
        var retryCount: Int

        enum CodingKeys: String, CodingKey {
            case id, type, payload
            case createdAt = "created_at"
            case retryCount = "retry_count"
        }
    }

    private enum MetadataKey {
        static let lastSyncTimestamp = "last_sync_timestamp"
        static let lastFullSyncTimestamp = "last_full_sync_timestamp"
        static let metricsSummary = "metrics_summary"
    }

    private init() {
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("gymbo.sqlite3")

        do {
            dbQueue = try DatabaseQueue(path: fileURL.path)
            try migrate()
            loadCache()
            AppLog.info("Database opened at \(fileURL.path)", category: .db)
        } catch {
            fatalError("Failed to open database: \(error)")
        }
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_core_cache") { db in
            try db.create(table: "workout_types", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("slug", .text).notNull()
                t.column("icon", .text)
                t.column("color", .text)
                t.column("is_system", .boolean).notNull().defaults(to: false)
                t.column("user_id", .text)
                t.column("last_modified", .double).notNull().defaults(to: 0)
            }

            try db.create(table: "exercises", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("muscle_groups", .integer).notNull().defaults(to: 0)
                t.column("workout_type", .integer)
                t.column("weight_type", .integer).notNull().defaults(to: 4)
                t.column("warmup_sets", .integer).notNull().defaults(to: 0)
                t.column("accessories_json", .text).notNull().defaults(to: "[]")
                t.column("is_system", .boolean).notNull().defaults(to: false)
                t.column("user_id", .text)
                t.column("source_exercise_id", .text)
                t.column("last_modified", .double).notNull().defaults(to: 0)
            }

            try db.create(table: "workout_templates", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("workout_type_id", .text)
                t.column("is_system", .boolean).notNull().defaults(to: false)
                t.column("user_id", .text)
                t.column("last_modified", .double).notNull().defaults(to: 0)
                t.column("json_data", .text).notNull().defaults(to: "{}")
            }

            try db.create(table: "weekly_schedule", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("day_of_week", .integer).notNull()
                t.column("template_id", .text)
                t.column("last_modified", .double).notNull().defaults(to: 0)
            }

            try db.create(table: "workout_sessions", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("template_id", .text)
                t.column("date", .double).notNull()
                t.column("started_at", .double)
                t.column("finished_at", .double)
                t.column("duration_secs", .integer)
                t.column("notes", .text)
                t.column("status", .text).notNull()
                t.column("last_modified", .double).notNull().defaults(to: 0)
                t.column("is_local_only", .boolean).notNull().defaults(to: false)
                t.column("json_data", .text).notNull().defaults(to: "{}")
            }

            try db.create(table: "pending_operations", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("type", .text).notNull()
                t.column("payload", .text).notNull()
                t.column("created_at", .double).notNull()
                t.column("retry_count", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "app_metadata", ifNotExists: true) { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }
        }

        migrator.registerMigration("v2_legacy_columns") { db in
            let workoutTypeColumns = try db.columns(in: "workout_types").map(\.name)
            if !workoutTypeColumns.contains("last_modified") {
                try db.alter(table: "workout_types") { t in
                    t.add(column: "last_modified", .double).notNull().defaults(to: 0)
                }
            }

            let sessionColumns = try db.columns(in: "workout_sessions").map(\.name)
            if !sessionColumns.contains("is_local_only") {
                try db.alter(table: "workout_sessions") { t in
                    t.add(column: "is_local_only", .boolean).notNull().defaults(to: false)
                }
            }

            let scheduleColumns = try db.columns(in: "weekly_schedule").map(\.name)
            if !scheduleColumns.contains("last_modified") {
                try db.alter(table: "weekly_schedule") { t in
                    t.add(column: "last_modified", .double).notNull().defaults(to: 0)
                }
            }
        }

        migrator.registerMigration("v3_exercise_config_fields") { db in
            let exerciseColumns = try db.columns(in: "exercises").map(\.name)
            if !exerciseColumns.contains("warmup_sets") {
                try db.alter(table: "exercises") { t in
                    t.add(column: "warmup_sets", .integer).notNull().defaults(to: 0)
                }
            }
            if !exerciseColumns.contains("accessories_json") {
                try db.alter(table: "exercises") { t in
                    t.add(column: "accessories_json", .text).notNull().defaults(to: "[]")
                }
            }
        }

        migrator.registerMigration("v4_exercise_enum_ints") { db in
            let exerciseColumns = try db.columns(in: "exercises").map(\.name)
            // Add new int columns if they don't exist yet
            if !exerciseColumns.contains("muscle_groups") {
                try db.alter(table: "exercises") { t in
                    t.add(column: "muscle_groups", .integer).notNull().defaults(to: 0)
                }
            }
            if !exerciseColumns.contains("workout_type") {
                try db.alter(table: "exercises") { t in
                    t.add(column: "workout_type", .integer)
                }
            }
            if !exerciseColumns.contains("source_exercise_id") {
                try db.alter(table: "exercises") { t in
                    t.add(column: "source_exercise_id", .text)
                }
            }
            // weight_type column: if it currently stores text, set default int value
            // (Server sync will overwrite with correct values on next full sync)
            // The column type change is handled by simply clearing old data—
            // a full sync is triggered on login which re-downloads all exercises.
        }

        migrator.registerMigration("v5_exercise_tracking_fields") { db in
            let exerciseColumns = try db.columns(in: "exercises").map(\.name)
            try db.alter(table: "exercises") { t in
                if !exerciseColumns.contains("description") {
                    t.add(column: "description", .text)
                }
                if !exerciseColumns.contains("video_url") {
                    t.add(column: "video_url", .text)
                }
                if !exerciseColumns.contains("goal_reps_min") {
                    t.add(column: "goal_reps_min", .integer)
                }
                if !exerciseColumns.contains("goal_reps_max") {
                    t.add(column: "goal_reps_max", .integer)
                }
                if !exerciseColumns.contains("show_highest_set") {
                    t.add(column: "show_highest_set", .boolean).notNull().defaults(to: false)
                }
                if !exerciseColumns.contains("track_highest_set") {
                    t.add(column: "track_highest_set", .boolean).notNull().defaults(to: false)
                }
                if !exerciseColumns.contains("highest_set_weight") {
                    t.add(column: "highest_set_weight", .double)
                }
                if !exerciseColumns.contains("highest_set_reps") {
                    t.add(column: "highest_set_reps", .integer)
                }
                if !exerciseColumns.contains("show_one_rep_max") {
                    t.add(column: "show_one_rep_max", .boolean).notNull().defaults(to: false)
                }
                if !exerciseColumns.contains("track_one_rep_max") {
                    t.add(column: "track_one_rep_max", .boolean).notNull().defaults(to: false)
                }
                if !exerciseColumns.contains("one_rep_max") {
                    t.add(column: "one_rep_max", .double)
                }
            }
        }

        try migrator.migrate(dbQueue)
    }

    func loadCache() {
        do {
            try dbQueue.read { db in
                cachedWorkoutTypes = try CachedWorkoutType
                    .order(Column("name").asc)
                    .fetchAll(db)
                cachedExercises = try CachedExercise
                    .order(Column("name").asc)
                    .fetchAll(db)
                cachedTemplates = try CachedTemplate
                    .order(Column("name").asc)
                    .fetchAll(db)
                cachedSchedule = try CachedScheduleEntry
                    .order(Column("day_of_week").asc)
                    .fetchAll(db)
                cachedSessions = try CachedSession
                    .order(Column("date").desc)
                    .fetchAll(db)
                pendingOperationsCount = try PendingOperation.fetchCount(db)
                cachedMetricsSummary = readMetricsSummaryValue(db)
            }
        } catch {
            AppLog.error("Failed to load cache: \(error)", category: .db)
        }
    }

    func clearAllUserData() {
        do {
            try dbQueue.write { db in
                try CachedWorkoutType.deleteAll(db)
                try CachedExercise.deleteAll(db)
                try CachedTemplate.deleteAll(db)
                try CachedScheduleEntry.deleteAll(db)
                try CachedSession.deleteAll(db)
                try PendingOperation.deleteAll(db)
                try db.execute(
                    sql: "DELETE FROM app_metadata WHERE key IN (?, ?, ?)",
                    arguments: [
                        MetadataKey.lastSyncTimestamp,
                        MetadataKey.lastFullSyncTimestamp,
                        MetadataKey.metricsSummary,
                    ]
                )
            }
            loadCache()
        } catch {
            AppLog.error("Failed to clear local cache: \(error)", category: .db)
        }
    }

    func cacheWorkoutTypes(_ workoutTypes: [WorkoutType], replace: Bool = false) {
        do {
            try dbQueue.write { db in
                if replace {
                    try CachedWorkoutType.deleteAll(db)
                }
                for workoutType in workoutTypes {
                    let cached = CachedWorkoutType(
                        id: workoutType.id,
                        name: workoutType.name,
                        slug: workoutType.slug,
                        icon: workoutType.icon,
                        color: workoutType.color,
                        isSystem: workoutType.isSystem,
                        userId: nil,
                        lastModified: workoutType.lastModified ?? Date().timeIntervalSince1970
                    )
                    try cached.save(db)
                }
            }
            loadCache()
        } catch {
            AppLog.error("Failed to cache workout types: \(error)", category: .db)
        }
    }

    func cacheExercises(_ exercises: [Exercise], replace: Bool = false) {
        do {
            try dbQueue.write { db in
                if replace {
                    try CachedExercise.deleteAll(db)
                }
                for exercise in exercises {
                    let accessoriesData = try JSONEncoder().encode(exercise.accessories)
                    let cached = CachedExercise(
                        id: exercise.id,
                        name: exercise.name,
                        description: exercise.description,
                        videoURL: exercise.videoURL,
                        muscleGroups: exercise.muscleGroups,
                        workoutType: exercise.workoutType,
                        weightType: exercise.weightType,
                        warmupSets: max(0, exercise.warmupSets),
                        accessoriesJSON: String(data: accessoriesData, encoding: .utf8) ?? "[]",
                        goalRepsMin: exercise.goalRepsMin,
                        goalRepsMax: exercise.goalRepsMax,
                        showHighestSet: exercise.showHighestSet,
                        trackHighestSet: exercise.trackHighestSet,
                        highestSetWeight: exercise.highestSetWeight,
                        highestSetReps: exercise.highestSetReps,
                        showOneRepMax: exercise.showOneRepMax,
                        trackOneRepMax: exercise.trackOneRepMax,
                        oneRepMax: exercise.oneRepMax,
                        isSystem: exercise.isSystem,
                        userId: nil,
                        sourceExerciseId: exercise.sourceExerciseId,
                        lastModified: exercise.lastModified ?? Date().timeIntervalSince1970
                    )
                    try cached.save(db)
                }
            }
            loadCache()
        } catch {
            AppLog.error("Failed to cache exercises: \(error)", category: .db)
        }
    }

    func cacheTemplates(_ templates: [WorkoutTemplate], replace: Bool = false) {
        do {
            try dbQueue.write { db in
                if replace {
                    try CachedTemplate.deleteAll(db)
                }
                for template in templates {
                    let data = try JSONEncoder().encode(template)
                    let cached = CachedTemplate(
                        id: template.id,
                        name: template.name,
                        description: template.description,
                        workoutTypeId: template.workoutTypeId,
                        isSystem: template.isSystem,
                        userId: nil,
                        lastModified: template.lastModified ?? Date().timeIntervalSince1970,
                        jsonData: String(data: data, encoding: .utf8) ?? "{}"
                    )
                    try cached.save(db)
                }
            }
            loadCache()
        } catch {
            AppLog.error("Failed to cache templates: \(error)", category: .db)
        }
    }

    func cacheSchedule(_ schedule: [WeeklyScheduleEntry], replace: Bool = false) {
        do {
            try dbQueue.write { db in
                if replace {
                    try CachedScheduleEntry.deleteAll(db)
                }
                for entry in schedule {
                    let cached = CachedScheduleEntry(
                        id: entry.id,
                        dayOfWeek: entry.dayOfWeek,
                        templateId: entry.templateId,
                        lastModified: entry.lastModified ?? Date().timeIntervalSince1970
                    )
                    try cached.save(db)
                }
            }
            loadCache()
        } catch {
            AppLog.error("Failed to cache schedule: \(error)", category: .db)
        }
    }

    func cacheSessions(
        _ sessions: [WorkoutSession],
        replace: Bool = false,
        localOnlyIDs: Set<String> = []
    ) {
        do {
            try dbQueue.write { db in
                if replace {
                    try CachedSession.deleteAll(db)
                }
                for session in sessions {
                    let data = try JSONEncoder().encode(session)
                    let cached = CachedSession(
                        id: session.id,
                        templateId: session.templateId,
                        date: session.date,
                        startedAt: session.startedAt,
                        finishedAt: session.finishedAt,
                        durationSecs: session.durationSecs,
                        notes: session.notes,
                        status: session.status,
                        lastModified: session.lastModified ?? Date().timeIntervalSince1970,
                        isLocalOnly: localOnlyIDs.contains(session.id),
                        jsonData: String(data: data, encoding: .utf8) ?? "{}"
                    )
                    try cached.save(db)
                }
            }
            loadCache()
        } catch {
            AppLog.error("Failed to cache sessions: \(error)", category: .db)
        }
    }

    func upsertSession(_ session: WorkoutSession, isLocalOnly: Bool) {
        do {
            try dbQueue.write { db in
                let data = try JSONEncoder().encode(session)
                let cached = CachedSession(
                    id: session.id,
                    templateId: session.templateId,
                    date: session.date,
                    startedAt: session.startedAt,
                    finishedAt: session.finishedAt,
                    durationSecs: session.durationSecs,
                    notes: session.notes,
                    status: session.status,
                    lastModified: session.lastModified ?? Date().timeIntervalSince1970,
                    isLocalOnly: isLocalOnly,
                    jsonData: String(data: data, encoding: .utf8) ?? "{}"
                )
                try cached.save(db)
            }
            loadCache()
        } catch {
            AppLog.error("Failed to upsert session: \(error)", category: .db)
        }
    }

    func replaceSession(localID: String, with session: WorkoutSession) {
        do {
            try dbQueue.write { db in
                _ = try CachedSession.deleteOne(db, key: localID)
                let data = try JSONEncoder().encode(session)
                let cached = CachedSession(
                    id: session.id,
                    templateId: session.templateId,
                    date: session.date,
                    startedAt: session.startedAt,
                    finishedAt: session.finishedAt,
                    durationSecs: session.durationSecs,
                    notes: session.notes,
                    status: session.status,
                    lastModified: session.lastModified ?? Date().timeIntervalSince1970,
                    isLocalOnly: false,
                    jsonData: String(data: data, encoding: .utf8) ?? "{}"
                )
                try cached.save(db)
            }
            loadCache()
        } catch {
            AppLog.error("Failed to replace local session: \(error)", category: .db)
        }
    }

    func deleteSession(id: String) {
        do {
            try dbQueue.write { db in
                _ = try CachedSession.deleteOne(db, key: id)
            }
            loadCache()
        } catch {
            AppLog.error("Failed to delete session from cache: \(error)", category: .db)
        }
    }

    func localOnlySessionIDs() -> Set<String> {
        Set(cachedSessions.filter(\.isLocalOnly).map(\.id))
    }

    func queuePendingOperation(type: String, payload: String, id: String? = nil) {
        do {
            try dbQueue.write { db in
                let operation = PendingOperation(
                    id: id ?? UUID().uuidString,
                    type: type,
                    payload: payload,
                    createdAt: Date().timeIntervalSince1970,
                    retryCount: 0
                )
                try operation.save(db)
            }
            loadCache()
        } catch {
            AppLog.error("Failed to queue pending operation: \(error)", category: .db)
        }
    }

    func fetchPendingOperations() -> [PendingOperation] {
        do {
            return try dbQueue.read { db in
                try PendingOperation
                    .order(Column("created_at").asc)
                    .fetchAll(db)
            }
        } catch {
            AppLog.error("Failed to fetch pending operations: \(error)", category: .db)
            return []
        }
    }

    func incrementRetryCount(id: String) {
        do {
            try dbQueue.write { db in
                guard var operation = try PendingOperation.fetchOne(db, key: id) else { return }
                operation.retryCount += 1
                try operation.update(db)
            }
            loadCache()
        } catch {
            AppLog.error("Failed to increment retry count: \(error)", category: .db)
        }
    }

    func deletePendingOperation(id: String) {
        do {
            try dbQueue.write { db in
                _ = try PendingOperation.deleteOne(db, key: id)
            }
            loadCache()
        } catch {
            AppLog.error("Failed to delete pending operation: \(error)", category: .db)
        }
    }

    func setLastSyncTimestamp(_ value: Double) {
        setMetadataValue(String(value), forKey: MetadataKey.lastSyncTimestamp)
    }

    func setLastFullSyncTimestamp(_ value: Double) {
        setMetadataValue(String(value), forKey: MetadataKey.lastFullSyncTimestamp)
    }

    func lastSyncTimestamp() -> Double {
        Double(metadataValue(forKey: MetadataKey.lastSyncTimestamp) ?? "") ?? 0
    }

    func lastFullSyncTimestamp() -> Double {
        Double(metadataValue(forKey: MetadataKey.lastFullSyncTimestamp) ?? "") ?? 0
    }

    func cacheMetricsSummary(_ summary: MetricsSummary?) {
        guard let summary else {
            setMetadataValue("", forKey: MetadataKey.metricsSummary)
            cachedMetricsSummary = nil
            return
        }

        do {
            let encoded = try JSONEncoder().encode(summary)
            let payload = String(data: encoded, encoding: .utf8) ?? ""
            setMetadataValue(payload, forKey: MetadataKey.metricsSummary)
            cachedMetricsSummary = summary
        } catch {
            AppLog.error("Failed to cache metrics summary: \(error)", category: .db)
        }
    }

    private func metadataValue(forKey key: String) -> String? {
        do {
            return try dbQueue.read { db in
                try String.fetchOne(db, sql: "SELECT value FROM app_metadata WHERE key = ?", arguments: [key])
            }
        } catch {
            AppLog.error("Failed to read metadata \(key): \(error)", category: .db)
            return nil
        }
    }

    private func setMetadataValue(_ value: String, forKey key: String) {
        do {
            try dbQueue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO app_metadata (key, value)
                        VALUES (?, ?)
                        ON CONFLICT(key) DO UPDATE SET value = excluded.value
                    """,
                    arguments: [key, value]
                )
            }
        } catch {
            AppLog.error("Failed to save metadata \(key): \(error)", category: .db)
        }
    }

    private func readMetricsSummaryValue(_ db: Database) -> MetricsSummary? {
        guard let payload = try? String.fetchOne(
            db,
            sql: "SELECT value FROM app_metadata WHERE key = ?",
            arguments: [MetadataKey.metricsSummary]
        ),
        let data = payload.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(MetricsSummary.self, from: data)
    }
}
