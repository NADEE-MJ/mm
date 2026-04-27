import Foundation

struct ExerciseRecordPrompt: Identifiable, Equatable {
    enum Kind: String {
        case highestSet
        case oneRepMax
    }

    let id: String
    let key: String
    let kind: Kind
    let exerciseId: String
    let exerciseName: String
    let candidateWeight: Double?
    let candidateReps: Int?
    let candidateOneRepMax: Double?
    let currentWeight: Double?
    let currentReps: Int?
    let currentOneRepMax: Double?
}

@MainActor
final class WorkoutRepository: ObservableObject, DataRepository {
    static let shared = WorkoutRepository()

    @Published private(set) var workoutTypes: [WorkoutType] = []
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var templates: [WorkoutTemplate] = []
    @Published private(set) var schedule: [WeeklyScheduleEntry] = []
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var metricsSummary: MetricsSummary?
    @Published private(set) var pendingOperationsCount = 0

    @Published private(set) var isSyncing = false
    @Published private(set) var isUsingOfflineData = false
    @Published private(set) var lastSyncError: String?
    @Published private(set) var lastSyncAt: Date?
    @Published var pendingExerciseRecordPrompt: ExerciseRecordPrompt?

    private let networkService = NetworkService.shared
    private let databaseManager = DatabaseManager.shared
    private let syncManager = SyncManager.shared

    private var backgroundSyncTask: Task<Void, Never>?
    private var hasLoadedCache = false
    private var localOnlySessionIDs: Set<String> = []
    private var lastMetricsFetchAt: Date?
    private var queuedExerciseRecordPrompts: [ExerciseRecordPrompt] = []
    private var ignoredExerciseRecordPromptKeys: Set<String> = []

    private let backgroundSyncDebounceNs: UInt64 = 2_000_000_000
    private let fullSyncInterval: TimeInterval = 20 * 60
    private let metricsRefreshInterval: TimeInterval = 10 * 60

    private init() {
        loadFromCache()
        hasLoadedCache = true
    }

    func handleLogoutCleanup() {
        backgroundSyncTask?.cancel()
        backgroundSyncTask = nil
        databaseManager.clearAllUserData()
        workoutTypes = []
        exercises = []
        templates = []
        schedule = []
        sessions = []
        metricsSummary = nil
        localOnlySessionIDs = []
        pendingOperationsCount = 0
        lastSyncAt = nil
        lastSyncError = nil
        isUsingOfflineData = false
        pendingExerciseRecordPrompt = nil
        queuedExerciseRecordPrompts = []
        ignoredExerciseRecordPromptKeys = []
    }

    func loadFromCache() {
        let decoder = JSONDecoder()

        workoutTypes = databaseManager.cachedWorkoutTypes.map { cached in
            WorkoutType(
                id: cached.id,
                name: cached.name,
                slug: cached.slug,
                icon: cached.icon,
                color: cached.color,
                isSystem: cached.isSystem,
                lastModified: cached.lastModified
            )
        }

        exercises = databaseManager.cachedExercises.map { cached in
            let accessories: [String]
            if let data = cached.accessoriesJSON.data(using: .utf8),
               let decoded = try? decoder.decode([String].self, from: data) {
                accessories = decoded
            } else {
                accessories = []
            }
            return Exercise(
                id: cached.id,
                name: cached.name,
                description: cached.description,
                videoURL: cached.videoURL,
                muscleGroups: cached.muscleGroups,
                workoutType: cached.workoutType,
                weightType: cached.weightType,
                warmupSets: max(0, cached.warmupSets),
                accessories: accessories,
                goalRepsMin: cached.goalRepsMin,
                goalRepsMax: cached.goalRepsMax,
                showHighestSet: cached.showHighestSet,
                trackHighestSet: cached.trackHighestSet,
                highestSetWeight: cached.highestSetWeight,
                highestSetReps: cached.highestSetReps,
                showOneRepMax: cached.showOneRepMax,
                trackOneRepMax: cached.trackOneRepMax,
                oneRepMax: cached.oneRepMax,
                isSystem: cached.isSystem,
                sourceExerciseId: cached.sourceExerciseId,
                lastModified: cached.lastModified
            )
        }

        templates = databaseManager.cachedTemplates.compactMap { cached in
            guard let data = cached.jsonData.data(using: .utf8) else { return nil }
            return try? decoder.decode(WorkoutTemplate.self, from: data)
        }

        schedule = databaseManager.cachedSchedule.map { cached in
            WeeklyScheduleEntry(
                id: cached.id,
                dayOfWeek: cached.dayOfWeek,
                templateId: cached.templateId,
                lastModified: cached.lastModified
            )
        }

        sessions = databaseManager.cachedSessions.compactMap { cached in
            guard let data = cached.jsonData.data(using: .utf8) else { return nil }
            return try? decoder.decode(WorkoutSession.self, from: data)
        }
        sessions.sort { $0.date > $1.date }

        localOnlySessionIDs = Set(databaseManager.cachedSessions.filter(\.isLocalOnly).map(\.id))
        pendingOperationsCount = databaseManager.pendingOperationsCount
        metricsSummary = databaseManager.cachedMetricsSummary ?? localMetricsSummary()

        let lastSyncTimestamp = databaseManager.lastSyncTimestamp()
        lastSyncAt = lastSyncTimestamp > 0 ? Date(timeIntervalSince1970: lastSyncTimestamp) : nil
    }

    func performInitialSyncIfNeeded() async {
        ensureCacheLoaded()
        let forceFull = shouldRunFullSync()
        await syncNow(forceFull: forceFull)
    }

    func syncNow(forceFull: Bool = false) async {
        ensureCacheLoaded()
        guard AuthManager.shared.isAuthenticated else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        lastSyncError = nil

        let didReplayQueuedChanges = await syncManager.processPendingOperations()
        let shouldForceFull = forceFull || didReplayQueuedChanges || shouldRunFullSync()
        let success = await pullChanges(forceFull: shouldForceFull)

        if success {
            isUsingOfflineData = false
            pendingOperationsCount = databaseManager.pendingOperationsCount
            if shouldRefreshMetricsSummary(force: shouldForceFull) {
                await refreshMetricsSummary()
            } else if metricsSummary == nil {
                metricsSummary = localMetricsSummary()
            }
            return
        }

        isUsingOfflineData = true
        lastSyncError = networkService.lastError
        loadFromCache()
    }

    func scheduleBackgroundSync(reason _: String) {
        guard AuthManager.shared.isAuthenticated else { return }
        let debounce = backgroundSyncDebounceNs

        backgroundSyncTask?.cancel()
        backgroundSyncTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: debounce)
                guard !Task.isCancelled else { return }
                await self?.syncNow(forceFull: false)
            } catch {}
        }
    }

    func processPendingOperationsNow() async {
        _ = await syncManager.processPendingOperations()
        pendingOperationsCount = databaseManager.pendingOperationsCount
        syncManager.refreshState()
    }

    func session(withId id: String) -> WorkoutSession? {
        sessions.first(where: { $0.id == id })
    }

    func inProgressSession() -> WorkoutSession? {
        sessions
            .filter { $0.status == "in_progress" }
            .sorted {
                let lhs = $0.startedAt ?? $0.date
                let rhs = $1.startedAt ?? $1.date
                return lhs > rhs
            }
            .first
    }

    func isSessionQueuedLocally(_ id: String) -> Bool {
        localOnlySessionIDs.contains(id)
    }

    func templateName(for id: String?) -> String {
        guard let id else { return "Freeform Workout" }
        return templates.first(where: { $0.id == id })?.name ?? "Template"
    }

    func exerciseName(for id: String) -> String {
        exercise(forSessionExerciseId: id)?.name ?? "Exercise"
    }

    func exercise(forSessionExerciseId id: String) -> Exercise? {
        if let exact = exercises.first(where: { $0.id == id }) {
            return exact
        }
        return exercises.first(where: { $0.sourceExerciseId == id })
    }

    var todayScheduleEntries: [WeeklyScheduleEntry] {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let normalized = (weekday + 5) % 7
        return schedule.filter { $0.dayOfWeek == normalized }
    }

    func getProgressiveOverloadDefaults(templateId: String) -> [String: [SessionSet]] {
        let completedSessions = sessions
            .filter { $0.status == "completed" }
            .sorted { ($0.finishedAt ?? $0.date) > ($1.finishedAt ?? $1.date) }

        var defaults: [String: [SessionSet]] = [:]

        if let sameTemplateSession = completedSessions.first(where: { $0.templateId == templateId }) {
            for exercise in sameTemplateSession.exercises {
                defaults[exercise.exerciseId] = exercise.sets
            }
            if !defaults.isEmpty {
                return defaults
            }
        }

        for session in completedSessions {
            for exercise in session.exercises where defaults[exercise.exerciseId] == nil {
                defaults[exercise.exerciseId] = exercise.sets
            }
        }

        return defaults
    }

    func startSession(templateId: String?) async -> WorkoutSession {
        if let existing = inProgressSession() {
            return existing
        }

        let now = Date().timeIntervalSince1970
        let payload: [String: AnyCodable] = [
            "template_id": AnyCodable(templateId as Any),
            "date": AnyCodable(now),
        ]

        do {
            let remote = try await networkService.startSession(payload: payload)
            upsertSession(remote, isLocalOnly: false)
            return remote
        } catch {
            let nsError = error as NSError
            if nsError.code == 409 {
                if let remoteSessions = try? await networkService.fetchSessions(),
                   let existing = remoteSessions.first(where: { $0.status == "in_progress" }) {
                    upsertSession(existing, isLocalOnly: false)
                    return existing
                }
                if let existing = inProgressSession() {
                    return existing
                }
            }

            let local = buildLocalSession(templateId: templateId, timestamp: now)
            upsertSession(local, isLocalOnly: true)
            queueSessionSnapshotUpload(local)
            pendingOperationsCount = databaseManager.pendingOperationsCount
            return local
        }
    }

    func addExerciseToSession(sessionId: String, exerciseId: String) async {
        guard var session = sessions.first(where: { $0.id == sessionId }) else { return }

        let wasLocalOnly = isSessionLocalOnly(sessionId)
        let nextPosition = (session.exercises.map(\.position).max() ?? -1) + 1
        let localSessionExercise = SessionExercise(
            id: UUID().uuidString,
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: nextPosition,
            notes: nil,
            sets: []
        )

        session.exercises.append(localSessionExercise)
        session.exercises.sort { $0.position < $1.position }
        session.lastModified = Date().timeIntervalSince1970
        upsertSession(session, isLocalOnly: wasLocalOnly)

        var targetSessionExerciseId = localSessionExercise.id

        if wasLocalOnly {
            if let refreshed = sessions.first(where: { $0.id == sessionId }) {
                queueSessionSnapshotUpload(refreshed)
                pendingOperationsCount = databaseManager.pendingOperationsCount
            }
        } else {
            do {
                let created = try await networkService.addSessionExercise(sessionId: sessionId, payload: [
                    "exercise_id": AnyCodable(exerciseId),
                    "position": AnyCodable(nextPosition),
                ])

                if var refreshed = sessions.first(where: { $0.id == sessionId }) {
                    if let index = refreshed.exercises.firstIndex(where: { $0.id == localSessionExercise.id }) {
                        var merged = created
                        if !refreshed.exercises[index].sets.isEmpty {
                            merged.sets = refreshed.exercises[index].sets
                        }
                        refreshed.exercises[index] = merged
                    } else if !refreshed.exercises.contains(where: { $0.id == created.id }) {
                        refreshed.exercises.append(created)
                    }

                    refreshed.exercises.sort { $0.position < $1.position }
                    refreshed.lastModified = Date().timeIntervalSince1970
                    upsertSession(refreshed, isLocalOnly: false)
                    targetSessionExerciseId = created.id
                } else {
                    targetSessionExerciseId = created.id
                }
            } catch {
                // Keep optimistic local exercise; first set sync can create the remote row when back online.
            }
        }

        if let refreshed = sessions.first(where: { $0.id == sessionId }),
           let targetExercise = refreshed.exercises.first(where: { $0.id == targetSessionExerciseId }),
           targetExercise.sets.isEmpty {
            await addSet(
                sessionId: sessionId,
                sessionExerciseId: targetSessionExerciseId,
                exerciseId: exerciseId
            )
        }
    }

    func updateSet(
        sessionId: String,
        sessionExerciseId: String,
        exerciseId: String,
        setNumber: Int,
        reps: Int?,
        weight: Double?,
        durationSecs: Int?,
        distance: Double?,
        isWarmup: Bool,
        usedAccessories: [String],
        bandColor: String?
    ) async {
        guard var session = sessions.first(where: { $0.id == sessionId }),
              let exerciseIndex = session.exercises.firstIndex(where: { $0.id == sessionExerciseId }) else {
            return
        }

        var sessionExercise = session.exercises[exerciseIndex]
        if let setIndex = sessionExercise.sets.firstIndex(where: { $0.setNumber == setNumber }) {
            sessionExercise.sets[setIndex].reps = reps
            sessionExercise.sets[setIndex].weight = weight
            sessionExercise.sets[setIndex].durationSecs = durationSecs
            sessionExercise.sets[setIndex].distance = distance
            sessionExercise.sets[setIndex].isWarmup = isWarmup
            sessionExercise.sets[setIndex].usedAccessories = usedAccessories
            sessionExercise.sets[setIndex].bandColor = bandColor
            sessionExercise.sets[setIndex].completed = true
        } else {
            let newSet = SessionSet(
                id: UUID().uuidString,
                sessionExerciseId: sessionExerciseId,
                setNumber: setNumber,
                reps: reps,
                weight: weight,
                durationSecs: durationSecs,
                distance: distance,
                isWarmup: isWarmup,
                usedAccessories: usedAccessories,
                bandColor: bandColor,
                completed: true
            )
            sessionExercise.sets.append(newSet)
            sessionExercise.sets.sort { $0.setNumber < $1.setNumber }
        }

        session.exercises[exerciseIndex] = sessionExercise
        session.lastModified = Date().timeIntervalSince1970
        upsertSession(session, isLocalOnly: isSessionLocalOnly(sessionId))
        if let exerciseMeta = exercise(forSessionExerciseId: exerciseId) {
            evaluateExerciseRecordPrompts(exercise: exerciseMeta, sessionExercise: sessionExercise)
        }

        if isSessionLocalOnly(sessionId) {
            queueSessionSnapshotUpload(session)
            pendingOperationsCount = databaseManager.pendingOperationsCount
            return
        }

        var data: [String: AnyCodable] = [
            "session_id": AnyCodable(sessionId),
            "session_exercise_id": AnyCodable(sessionExerciseId),
            "exercise_id": AnyCodable(exerciseId),
            "set_number": AnyCodable(setNumber),
            "completed": AnyCodable(true),
        ]
        if let reps {
            data["reps"] = AnyCodable(reps)
        }
        if let weight {
            data["weight"] = AnyCodable(weight)
        }
        if let durationSecs {
            data["duration_secs"] = AnyCodable(durationSecs)
        }
        if let distance {
            data["distance"] = AnyCodable(distance)
        }
        data["is_warmup"] = AnyCodable(isWarmup)
        data["used_accessories"] = AnyCodable(usedAccessories)
        data["band_color"] = AnyCodable(bandColor as Any)
        // Coalesce repeated edits for the same set into one pending operation.
        // Keep changes local-first; sync will happen via lifecycle/manual triggers.
        let operationId = "log_set_\(sessionId)_\(sessionExerciseId)_\(setNumber)"
        queuePendingOperation(type: "log_set", payload: data, id: operationId)
    }

    func addSet(sessionId: String, sessionExerciseId: String, exerciseId: String) async {
        guard let session = sessions.first(where: { $0.id == sessionId }),
              let exercise = session.exercises.first(where: { $0.id == sessionExerciseId }) else {
            return
        }
        let nextSetNumber = (exercise.sets.map(\.setNumber).max() ?? 0) + 1
        let lastSet = exercise.sets.max(by: { $0.setNumber < $1.setNumber })
        await updateSet(
            sessionId: sessionId,
            sessionExerciseId: sessionExerciseId,
            exerciseId: exerciseId,
            setNumber: nextSetNumber,
            reps: lastSet?.reps,
            weight: lastSet?.weight,
            durationSecs: lastSet?.durationSecs,
            distance: lastSet?.distance,
            isWarmup: lastSet?.isWarmup ?? false,
            usedAccessories: lastSet?.usedAccessories ?? [],
            bandColor: lastSet?.bandColor
        )
    }

    func updateSetOptions(
        sessionId: String,
        sessionExerciseId: String,
        setId: String,
        isWarmup: Bool,
        usedAccessories: [String]
    ) async {
        guard let session = sessions.first(where: { $0.id == sessionId }),
              let sessionExercise = session.exercises.first(where: { $0.id == sessionExerciseId }),
              let targetSet = sessionExercise.sets.first(where: { $0.id == setId }) else {
            return
        }

        await updateSet(
            sessionId: sessionId,
            sessionExerciseId: sessionExerciseId,
            exerciseId: sessionExercise.exerciseId,
            setNumber: targetSet.setNumber,
            reps: targetSet.reps,
            weight: targetSet.weight,
            durationSecs: targetSet.durationSecs,
            distance: targetSet.distance,
            isWarmup: isWarmup,
            usedAccessories: usedAccessories,
            bandColor: targetSet.bandColor
        )
    }

    func deleteSet(sessionId: String, sessionExerciseId: String, setId: String) async {
        guard var session = sessions.first(where: { $0.id == sessionId }),
              let exerciseIndex = session.exercises.firstIndex(where: { $0.id == sessionExerciseId }) else {
            return
        }

        var sessionExercise = session.exercises[exerciseIndex]
        guard sessionExercise.sets.contains(where: { $0.id == setId }) else {
            return
        }

        sessionExercise.sets.removeAll { $0.id == setId }
        session.exercises[exerciseIndex] = sessionExercise
        session.lastModified = Date().timeIntervalSince1970
        upsertSession(session, isLocalOnly: isSessionLocalOnly(sessionId))

        if isSessionLocalOnly(sessionId) {
            queueSessionSnapshotUpload(session)
            pendingOperationsCount = databaseManager.pendingOperationsCount
            return
        }

        queuePendingOperation(
            type: "delete_set",
            payload: [
                "session_id": AnyCodable(sessionId),
                "session_exercise_id": AnyCodable(sessionExerciseId),
                "set_id": AnyCodable(setId),
            ],
            id: "delete_set_\(sessionId)_\(sessionExerciseId)_\(setId)"
        )
    }

    func createExercise(
        name: String,
        muscleGroups: Int,
        workoutType: Int?,
        weightType: Int,
        allSetsSameWeight: Bool,
        warmupSets: Int,
        accessories: [String],
        description: String? = nil,
        videoURL: String? = nil,
        goalRepsMin: Int? = nil,
        goalRepsMax: Int? = nil,
        showHighestSet: Bool = false,
        trackHighestSet: Bool = false,
        highestSetWeight: Double? = nil,
        highestSetReps: Int? = nil,
        showOneRepMax: Bool = false,
        trackOneRepMax: Bool = false,
        oneRepMax: Double? = nil
    ) async throws {
        let configuredWarmups = allSetsSameWeight ? 0 : max(0, warmupSets)
        let now = Date().timeIntervalSince1970
        do {
            let created = try await networkService.createExercise(payload: [
                "name": AnyCodable(name),
                "description": AnyCodable(description as Any),
                "video_url": AnyCodable(videoURL as Any),
                "muscle_groups": AnyCodable(muscleGroups),
                "workout_type": AnyCodable(workoutType as Any),
                "weight_type": AnyCodable(weightType),
                "warmup_sets": AnyCodable(configuredWarmups),
                "accessories": AnyCodable(accessories),
                "goal_reps_min": AnyCodable(goalRepsMin as Any),
                "goal_reps_max": AnyCodable(goalRepsMax as Any),
                "show_highest_set": AnyCodable(showHighestSet),
                "track_highest_set": AnyCodable(trackHighestSet),
                "highest_set_weight": AnyCodable(highestSetWeight as Any),
                "highest_set_reps": AnyCodable(highestSetReps as Any),
                "show_one_rep_max": AnyCodable(showOneRepMax),
                "track_one_rep_max": AnyCodable(trackOneRepMax),
                "one_rep_max": AnyCodable(oneRepMax as Any),
            ])
            exercises.removeAll { $0.id == created.id }
            exercises.append(created)
            exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            databaseManager.cacheExercises(exercises, replace: true)
        } catch {
            let optimistic = Exercise(
                id: UUID().uuidString,
                name: name,
                description: description,
                videoURL: videoURL,
                muscleGroups: muscleGroups,
                workoutType: workoutType,
                weightType: weightType,
                warmupSets: configuredWarmups,
                accessories: accessories,
                goalRepsMin: goalRepsMin,
                goalRepsMax: goalRepsMax,
                showHighestSet: showHighestSet,
                trackHighestSet: trackHighestSet,
                highestSetWeight: highestSetWeight,
                highestSetReps: highestSetReps,
                showOneRepMax: showOneRepMax,
                trackOneRepMax: trackOneRepMax,
                oneRepMax: oneRepMax,
                isSystem: false,
                lastModified: now
            )
            exercises.removeAll { $0.id == optimistic.id }
            exercises.append(optimistic)
            exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            databaseManager.cacheExercises(exercises, replace: true)

            let queuePayload: [String: AnyCodable] = [
                "action": AnyCodable("addExercise"),
                "data": AnyCodable([
                    "name": AnyCodable(name),
                    "description": AnyCodable(description as Any),
                    "video_url": AnyCodable(videoURL as Any),
                    "muscle_groups": AnyCodable(muscleGroups),
                    "workout_type": AnyCodable(workoutType as Any),
                    "weight_type": AnyCodable(weightType),
                    "warmup_sets": AnyCodable(configuredWarmups),
                    "accessories": AnyCodable(accessories),
                    "goal_reps_min": AnyCodable(goalRepsMin as Any),
                    "goal_reps_max": AnyCodable(goalRepsMax as Any),
                    "show_highest_set": AnyCodable(showHighestSet),
                    "track_highest_set": AnyCodable(trackHighestSet),
                    "highest_set_weight": AnyCodable(highestSetWeight as Any),
                    "highest_set_reps": AnyCodable(highestSetReps as Any),
                    "show_one_rep_max": AnyCodable(showOneRepMax),
                    "track_one_rep_max": AnyCodable(trackOneRepMax),
                    "one_rep_max": AnyCodable(oneRepMax as Any),
                ]),
            ]
            queuePendingOperation(type: "batch_action", payload: queuePayload)
            throw RepositoryError.queued("Saved locally. Exercise will sync when online.")
        }
    }

    func updateExercise(
        id: String,
        name: String,
        muscleGroups: Int,
        workoutType: Int?,
        weightType: Int,
        allSetsSameWeight: Bool,
        warmupSets: Int,
        accessories: [String],
        description: String? = nil,
        videoURL: String? = nil,
        goalRepsMin: Int? = nil,
        goalRepsMax: Int? = nil,
        showHighestSet: Bool = false,
        trackHighestSet: Bool = false,
        highestSetWeight: Double? = nil,
        highestSetReps: Int? = nil,
        showOneRepMax: Bool = false,
        trackOneRepMax: Bool = false,
        oneRepMax: Double? = nil
    ) async throws {
        let configuredWarmups = allSetsSameWeight ? 0 : max(0, warmupSets)
        let now = Date().timeIntervalSince1970

        do {
            let updated = try await networkService.updateExercise(id: id, payload: [
                "name": AnyCodable(name),
                "description": AnyCodable(description as Any),
                "video_url": AnyCodable(videoURL as Any),
                "muscle_groups": AnyCodable(muscleGroups),
                "workout_type": AnyCodable(workoutType as Any),
                "weight_type": AnyCodable(weightType),
                "warmup_sets": AnyCodable(configuredWarmups),
                "accessories": AnyCodable(accessories),
                "goal_reps_min": AnyCodable(goalRepsMin as Any),
                "goal_reps_max": AnyCodable(goalRepsMax as Any),
                "show_highest_set": AnyCodable(showHighestSet),
                "track_highest_set": AnyCodable(trackHighestSet),
                "highest_set_weight": AnyCodable(highestSetWeight as Any),
                "highest_set_reps": AnyCodable(highestSetReps as Any),
                "show_one_rep_max": AnyCodable(showOneRepMax),
                "track_one_rep_max": AnyCodable(trackOneRepMax),
                "one_rep_max": AnyCodable(oneRepMax as Any),
            ])
            // Keep list de-duplicated in case server ever returns a remapped row id.
            exercises.removeAll { $0.id == id }
            exercises.removeAll { $0.id == updated.id }
            exercises.append(updated)
            exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            databaseManager.cacheExercises(exercises, replace: true)
        } catch {
            // Optimistic update for user-owned exercises only
            if let existing = exercises.first(where: { $0.id == id }), !existing.isSystem {
                var updated = existing
                updated.name = name
                updated.description = description
                updated.videoURL = videoURL
                updated.muscleGroups = muscleGroups
                updated.workoutType = workoutType
                updated.weightType = weightType
                updated.warmupSets = configuredWarmups
                updated.accessories = accessories
                updated.goalRepsMin = goalRepsMin
                updated.goalRepsMax = goalRepsMax
                updated.showHighestSet = showHighestSet
                updated.trackHighestSet = trackHighestSet
                updated.highestSetWeight = highestSetWeight
                updated.highestSetReps = highestSetReps
                updated.showOneRepMax = showOneRepMax
                updated.trackOneRepMax = trackOneRepMax
                updated.oneRepMax = oneRepMax
                updated.lastModified = now
                exercises.removeAll { $0.id == id }
                exercises.append(updated)
                exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                databaseManager.cacheExercises(exercises, replace: true)

                let queuePayload: [String: AnyCodable] = [
                    "action": AnyCodable("updateExercise"),
                    "data": AnyCodable([
                        "id": AnyCodable(id),
                        "name": AnyCodable(name),
                        "description": AnyCodable(description as Any),
                        "video_url": AnyCodable(videoURL as Any),
                        "muscle_groups": AnyCodable(muscleGroups),
                        "workout_type": AnyCodable(workoutType as Any),
                        "weight_type": AnyCodable(weightType),
                        "warmup_sets": AnyCodable(configuredWarmups),
                        "accessories": AnyCodable(accessories),
                        "goal_reps_min": AnyCodable(goalRepsMin as Any),
                        "goal_reps_max": AnyCodable(goalRepsMax as Any),
                        "show_highest_set": AnyCodable(showHighestSet),
                        "track_highest_set": AnyCodable(trackHighestSet),
                        "highest_set_weight": AnyCodable(highestSetWeight as Any),
                        "highest_set_reps": AnyCodable(highestSetReps as Any),
                        "show_one_rep_max": AnyCodable(showOneRepMax),
                        "track_one_rep_max": AnyCodable(trackOneRepMax),
                        "one_rep_max": AnyCodable(oneRepMax as Any),
                    ]),
                ]
                queuePendingOperation(type: "batch_action", payload: queuePayload)
            }
            throw RepositoryError.queued("Saved locally. Exercise will sync when online.")
        }
    }

    func updateExerciseSessionSettings(
        sessionExerciseId: String,
        description: String?,
        videoURL: String?,
        goalRepsMin: Int?,
        goalRepsMax: Int?,
        showHighestSet: Bool,
        trackHighestSet: Bool,
        showOneRepMax: Bool,
        trackOneRepMax: Bool
    ) async throws {
        guard let target = exercise(forSessionExerciseId: sessionExerciseId) else {
            throw RepositoryError.notFound("Exercise not found")
        }

        if let goalRepsMin, let goalRepsMax, goalRepsMin > goalRepsMax {
            throw RepositoryError.networkError("Goal rep minimum cannot exceed maximum")
        }

        let payload: [String: AnyCodable] = [
            "description": AnyCodable(description as Any),
            "video_url": AnyCodable(videoURL as Any),
            "goal_reps_min": AnyCodable(goalRepsMin as Any),
            "goal_reps_max": AnyCodable(goalRepsMax as Any),
            "show_highest_set": AnyCodable(showHighestSet),
            "track_highest_set": AnyCodable(trackHighestSet),
            "show_one_rep_max": AnyCodable(showOneRepMax),
            "track_one_rep_max": AnyCodable(trackOneRepMax),
        ]

        _ = try await updateExercisePartial(
            id: target.id,
            payload: payload
        ) { exercise in
            exercise.description = description
            exercise.videoURL = videoURL
            exercise.goalRepsMin = goalRepsMin
            exercise.goalRepsMax = goalRepsMax
            exercise.showHighestSet = showHighestSet
            exercise.trackHighestSet = trackHighestSet
            exercise.showOneRepMax = showOneRepMax
            exercise.trackOneRepMax = trackOneRepMax
        }
    }

    func resolvePendingExerciseRecordPrompt(replace: Bool) async {
        guard let prompt = pendingExerciseRecordPrompt else { return }
        pendingExerciseRecordPrompt = nil

        if replace {
            do {
                try await applyExerciseRecordPrompt(prompt)
            } catch {
                ignoredExerciseRecordPromptKeys.insert(prompt.key)
            }
        } else {
            ignoredExerciseRecordPromptKeys.insert(prompt.key)
        }
        promoteNextExerciseRecordPrompt()
    }

    func completeSession(id: String) async {
        guard var session = sessions.first(where: { $0.id == id }) else { return }
        let finishedAt = Date().timeIntervalSince1970
        let duration: Int?
        if let startedAt = session.startedAt {
            duration = max(0, Int(finishedAt - startedAt))
        } else {
            duration = nil
        }

        session.status = "completed"
        session.startedAt = nil
        session.finishedAt = finishedAt
        session.durationSecs = duration
        session.lastModified = Date().timeIntervalSince1970
        upsertSession(session, isLocalOnly: isSessionLocalOnly(id))

        if isSessionLocalOnly(id) {
            queueSessionSnapshotUpload(session)
            pendingOperationsCount = databaseManager.pendingOperationsCount
            metricsSummary = localMetricsSummary()
            scheduleBackgroundSync(reason: "session-completed-local")
            return
        }

        queuePendingOperation(
            type: "complete_session",
            payload: [
                "id": AnyCodable(id),
                "finished_at": AnyCodable(finishedAt),
            ],
            id: "complete_session_\(id)"
        )
        metricsSummary = localMetricsSummary()
        scheduleBackgroundSync(reason: "session-submitted")
    }

    func updateSchedule(entries: [WeeklyScheduleEntry]) async {
        schedule = entries
        databaseManager.cacheSchedule(entries, replace: true)

        let payload = entries.map {
            [
                "day_of_week": AnyCodable($0.dayOfWeek),
                "template_id": AnyCodable($0.templateId as Any),
            ]
        }

        queuePendingOperation(
            type: "update_schedule",
            payload: [
                "entries": AnyCodable(payload),
            ],
            id: "update_schedule"
        )
    }

    func scheduleTemplate(templateId: String, dayOfWeek: Int) async {
        guard (0 ... 6).contains(dayOfWeek) else { return }
        guard templates.contains(where: { $0.id == templateId }) else { return }

        if schedule.contains(where: { $0.dayOfWeek == dayOfWeek && $0.templateId == templateId }) {
            return
        }

        var next = schedule
        next.append(
            WeeklyScheduleEntry(
                id: UUID().uuidString,
                dayOfWeek: dayOfWeek,
                templateId: templateId,
                lastModified: Date().timeIntervalSince1970
            )
        )
        await updateSchedule(entries: next)
    }

    func deleteTemplate(id: String) async throws {
        guard let template = templates.first(where: { $0.id == id }) else { return }
        if template.isSystem {
            throw RepositoryError.networkError("System templates cannot be deleted.")
        }

        var queued = false
        do {
            try await networkService.deleteTemplate(id: id)
        } catch {
            queuePendingOperation(type: "batch_action", payload: [
                "action": AnyCodable("deleteTemplate"),
                "data": AnyCodable(["id": AnyCodable(id)]),
            ])
            queued = true
        }

        templates.removeAll { $0.id == id }
        templates.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        databaseManager.cacheTemplates(templates, replace: true)

        schedule.removeAll { $0.templateId == id }
        databaseManager.cacheSchedule(schedule, replace: true)

        if queued {
            throw RepositoryError.queued("Deleted locally. Template deletion will sync when online.")
        }
    }

    func deleteExercise(id: String) async throws {
        guard let exercise = exercises.first(where: { $0.id == id }) else { return }
        if exercise.isSystem {
            throw RepositoryError.networkError("System exercises cannot be deleted.")
        }

        var queued = false
        do {
            try await networkService.deleteExercise(id: id)
        } catch {
            queuePendingOperation(type: "batch_action", payload: [
                "action": AnyCodable("deleteExercise"),
                "data": AnyCodable(["id": AnyCodable(id)]),
            ])
            queued = true
        }

        exercises.removeAll { $0.id == id }
        exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        databaseManager.cacheExercises(exercises, replace: true)

        var templatesChanged = false
        templates = templates.map { template in
            let previousCount = template.exercises.count
            var updated = template
            updated.exercises.removeAll { $0.exerciseId == id }
            if updated.exercises.count != previousCount {
                templatesChanged = true
            }
            return updated
        }
        if templatesChanged {
            databaseManager.cacheTemplates(templates, replace: true)
        }

        if queued {
            throw RepositoryError.queued("Deleted locally. Exercise deletion will sync when online.")
        }
    }

    func deleteSession(id: String) async throws {
        guard sessions.contains(where: { $0.id == id }) else { return }

        var queued = false
        if !isSessionLocalOnly(id) {
            do {
                try await networkService.deleteSession(id: id)
            } catch {
                queuePendingOperation(type: "batch_action", payload: [
                    "action": AnyCodable("deleteSession"),
                    "data": AnyCodable(["id": AnyCodable(id)]),
                ])
                queued = true
            }
        }

        removeSessionLocally(id: id)

        if queued {
            throw RepositoryError.queued("Deleted locally. Session deletion will sync when online.")
        }
    }

    func startSessionLike(sessionId: String) async -> WorkoutSession? {
        guard let source = sessions.first(where: { $0.id == sessionId }) else { return nil }

        if let templateId = source.templateId {
            return await startSession(templateId: templateId)
        }

        let started = await startSession(templateId: nil)
        let existing = session(withId: started.id) ?? started
        if !existing.exercises.isEmpty {
            return existing
        }

        var seenExerciseIDs: Set<String> = []
        let exerciseIDs = source.exercises
            .sorted(by: { $0.position < $1.position })
            .compactMap { sessionExercise -> String? in
                let id = sessionExercise.exerciseId
                guard !seenExerciseIDs.contains(id) else { return nil }
                seenExerciseIDs.insert(id)
                return id
            }

        for exerciseId in exerciseIDs {
            await addExerciseToSession(sessionId: started.id, exerciseId: exerciseId)
        }

        return session(withId: started.id) ?? started
    }

    func createTemplateFromSession(sessionId: String) async throws {
        guard let session = sessions.first(where: { $0.id == sessionId }) else {
            throw RepositoryError.notFound("Session not found")
        }

        var seenExerciseIDs: Set<String> = []
        let exerciseIDs = session.exercises
            .sorted(by: { $0.position < $1.position })
            .compactMap { sessionExercise -> String? in
                let id = sessionExercise.exerciseId
                guard !seenExerciseIDs.contains(id) else { return nil }
                seenExerciseIDs.insert(id)
                return id
            }
        guard !exerciseIDs.isEmpty else {
            throw RepositoryError.networkError("Session has no exercises to save.")
        }

        let baseName = templateName(for: session.templateId)
        let normalizedBase = (baseName == "Template" || baseName == "Freeform Workout") ? "Session" : baseName
        let dateLabel = Date(timeIntervalSince1970: session.date).formatted(date: .abbreviated, time: .omitted)
        let name = "\(normalizedBase) \(dateLabel)"
        let workoutTypeId = templates.first(where: { $0.id == session.templateId })?.workoutTypeId
        try await createTemplate(
            name: name,
            description: nil,
            workoutTypeId: workoutTypeId,
            exerciseIds: exerciseIDs
        )
    }

    func createTemplate(
        name: String,
        description: String?,
        workoutTypeId: String?,
        exerciseIds: [String]
    ) async throws {
        do {
            let created = try await networkService.createTemplate(payload: [
                "name": AnyCodable(name),
                "description": AnyCodable(description as Any),
                "workout_type_id": AnyCodable(workoutTypeId as Any),
            ])

            for (index, exerciseId) in exerciseIds.enumerated() {
                _ = try await networkService.addTemplateExercise(templateId: created.id, payload: [
                    "exercise_id": AnyCodable(exerciseId),
                    "position": AnyCodable(index),
                    "default_sets": AnyCodable(3),
                    "default_reps": AnyCodable(10),
                ])
            }

            let hydrated = try await networkService.fetchTemplate(id: created.id)
            templates.removeAll { $0.id == hydrated.id }
            templates.append(hydrated)
            templates.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            databaseManager.cacheTemplates(templates, replace: true)
            return
        } catch {
            let optimistic = WorkoutTemplate(
                id: UUID().uuidString,
                name: name,
                description: description,
                workoutTypeId: workoutTypeId,
                isSystem: false,
                createdAt: Date().timeIntervalSince1970,
                lastModified: Date().timeIntervalSince1970,
                exercises: exerciseIds.enumerated().map { index, exerciseId in
                    TemplateExercise(
                        id: UUID().uuidString,
                        templateId: "",
                        exerciseId: exerciseId,
                        position: index,
                        defaultSets: 3,
                        defaultReps: 10,
                        defaultWeight: nil,
                        defaultDurationSecs: nil,
                        defaultDistance: nil,
                        notes: nil
                    )
                }
            )
            templates.append(optimistic)
            templates.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            databaseManager.cacheTemplates(templates, replace: true)

            let queuePayload: [String: AnyCodable] = [
                "action": AnyCodable("addTemplate"),
                "data": AnyCodable([
                    "name": AnyCodable(name),
                    "description": AnyCodable(description as Any),
                    "workout_type_id": AnyCodable(workoutTypeId as Any),
                    "exercises": AnyCodable(exerciseIds.enumerated().map { index, exerciseId in
                        [
                            "exercise_id": AnyCodable(exerciseId),
                            "position": AnyCodable(index),
                            "default_sets": AnyCodable(3),
                            "default_reps": AnyCodable(10),
                        ]
                    }),
                ]),
            ]
            queuePendingOperation(type: "batch_action", payload: queuePayload)
            throw RepositoryError.queued("Saved locally. Template will sync when online.")
        }
    }

    func updateTemplateExerciseSets(templateId: String, templateExerciseId: String, defaultSets: Int) async throws {
        try await networkService.updateTemplateExercise(
            templateId: templateId,
            templateExerciseId: templateExerciseId,
            payload: ["default_sets": AnyCodable(defaultSets)]
        )
        // Refresh template from cache after update
        if let hydrated = try? await networkService.fetchTemplate(id: templateId) {
            templates.removeAll { $0.id == hydrated.id }
            templates.append(hydrated)
            templates.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            databaseManager.cacheTemplates(templates, replace: true)
        }
    }

    func addExerciseToTemplate(templateId: String, exerciseId: String) async throws {
        guard let existingTemplate = templates.first(where: { $0.id == templateId }) else {
            throw RepositoryError.notFound("Template not found")
        }

        if existingTemplate.exercises.contains(where: { $0.exerciseId == exerciseId }) {
            return
        }

        let nextPosition = (existingTemplate.exercises.map(\.position).max() ?? -1) + 1

        _ = try await networkService.addTemplateExercise(templateId: templateId, payload: [
            "exercise_id": AnyCodable(exerciseId),
            "position": AnyCodable(nextPosition),
            "default_sets": AnyCodable(3),
            "default_reps": AnyCodable(10),
        ])

        if let hydrated = try? await networkService.fetchTemplate(id: templateId) {
            templates.removeAll { $0.id == hydrated.id }
            templates.append(hydrated)
            templates.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            databaseManager.cacheTemplates(templates, replace: true)
        }
    }

    func refreshMetricsSummary() async {
        do {
            let summary = try await networkService.fetchMetricsSummary()
            metricsSummary = summary
            databaseManager.cacheMetricsSummary(summary)
            lastMetricsFetchAt = Date()
        } catch {
            let fallback = localMetricsSummary()
            metricsSummary = fallback
            databaseManager.cacheMetricsSummary(fallback)
        }
    }

    func replaceLocalOnlySession(localId: String, with remoteSession: WorkoutSession) {
        localOnlySessionIDs.remove(localId)
        sessions.removeAll { $0.id == localId }
        sessions.removeAll { $0.id == remoteSession.id }
        sessions.append(remoteSession)
        sessions.sort { $0.date > $1.date }
        databaseManager.replaceSession(localID: localId, with: remoteSession)
    }

    private func ensureCacheLoaded() {
        if !hasLoadedCache {
            loadFromCache()
            hasLoadedCache = true
        }
    }

    private func pullChanges(forceFull: Bool) async -> Bool {
        do {
            let since = forceFull ? 0 : databaseManager.lastSyncTimestamp()
            var offset = 0
            var hasMore = true
            var latestServerTimestamp: Double = Date().timeIntervalSince1970

            var mergedWorkoutTypes: [WorkoutType] = []
            var mergedExercises: [Exercise] = []
            var mergedTemplates: [WorkoutTemplate] = []
            var mergedSchedule: [WeeklyScheduleEntry] = []
            var mergedSessions: [WorkoutSession] = []

            while hasMore {
                let page = try await networkService.fetchChanges(since: since, limit: 400, offset: offset)
                latestServerTimestamp = page.serverTimestamp
                hasMore = page.hasMore
                offset = page.nextOffset ?? 0

                if forceFull {
                    mergedWorkoutTypes.append(contentsOf: page.workoutTypes)
                    mergedExercises.append(contentsOf: page.exercises)
                    mergedTemplates.append(contentsOf: page.templates)
                    mergedSchedule.append(contentsOf: page.schedule)
                    mergedSessions.append(contentsOf: page.sessions)
                } else {
                    applyIncrementalChanges(page)
                }
            }

            if forceFull {
                let localOnlySessions = sessions.filter { localOnlySessionIDs.contains($0.id) }
                let remoteIDs = Set(mergedSessions.map(\.id))
                for local in localOnlySessions where !remoteIDs.contains(local.id) {
                    mergedSessions.append(local)
                }

                databaseManager.cacheWorkoutTypes(mergedWorkoutTypes, replace: true)
                databaseManager.cacheExercises(mergedExercises, replace: true)
                databaseManager.cacheTemplates(mergedTemplates, replace: true)
                databaseManager.cacheSchedule(mergedSchedule, replace: true)
                databaseManager.cacheSessions(
                    mergedSessions,
                    replace: true,
                    localOnlyIDs: Set(localOnlySessions.map(\.id))
                )
                databaseManager.setLastFullSyncTimestamp(latestServerTimestamp)
            }

            databaseManager.setLastSyncTimestamp(latestServerTimestamp)
            lastSyncAt = Date(timeIntervalSince1970: latestServerTimestamp)
            loadFromCache()
            return true
        } catch {
            AppLog.error("Sync pull failed: \(error)", category: .sync)
            return false
        }
    }

    private func applyIncrementalChanges(_ page: SyncChangesEnvelope) {
        if !page.workoutTypes.isEmpty {
            databaseManager.cacheWorkoutTypes(page.workoutTypes, replace: false)
        }
        if !page.exercises.isEmpty {
            databaseManager.cacheExercises(page.exercises, replace: false)
        }
        if !page.templates.isEmpty {
            databaseManager.cacheTemplates(page.templates, replace: false)
        }
        if !page.schedule.isEmpty {
            databaseManager.cacheSchedule(page.schedule, replace: false)
        }
        if !page.sessions.isEmpty {
            let serverIDs = Set(page.sessions.map(\.id))
            localOnlySessionIDs.subtract(serverIDs)
            databaseManager.cacheSessions(page.sessions, replace: false)
        }
    }

    private func upsertSession(_ session: WorkoutSession, isLocalOnly: Bool) {
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
        sessions.sort { $0.date > $1.date }
        if isLocalOnly {
            localOnlySessionIDs.insert(session.id)
        } else {
            localOnlySessionIDs.remove(session.id)
        }
        databaseManager.upsertSession(session, isLocalOnly: isLocalOnly)
        metricsSummary = localMetricsSummary()
    }

    private func removeSessionLocally(id: String) {
        sessions.removeAll { $0.id == id }
        localOnlySessionIDs.remove(id)
        databaseManager.deleteSession(id: id)
        databaseManager.deletePendingOperation(id: "session_snapshot_\(id)")
        pendingOperationsCount = databaseManager.pendingOperationsCount
        metricsSummary = localMetricsSummary()
    }

    private func isSessionLocalOnly(_ id: String) -> Bool {
        localOnlySessionIDs.contains(id)
    }

    private func queueSessionSnapshotUpload(_ session: WorkoutSession) {
        let snapshot = QueuedSessionSnapshot(localSessionId: session.id, session: session)
        if let data = try? JSONEncoder().encode(snapshot),
           let payload = String(data: data, encoding: .utf8) {
            databaseManager.queuePendingOperation(
                type: "upload_session_snapshot",
                payload: payload,
                id: "session_snapshot_\(session.id)"
            )
            syncManager.refreshState()
        }
    }

    private func queuePendingOperation(type: String, payload: [String: AnyCodable], id: String? = nil) {
        guard let data = try? JSONEncoder().encode(payload),
              let serialized = String(data: data, encoding: .utf8) else {
            return
        }
        databaseManager.queuePendingOperation(type: type, payload: serialized, id: id)
        pendingOperationsCount = databaseManager.pendingOperationsCount
        syncManager.refreshState()
    }

    @discardableResult
    private func updateExercisePartial(
        id: String,
        payload: [String: AnyCodable],
        optimisticApply: (inout Exercise) -> Void
    ) async throws -> Exercise {
        let now = Date().timeIntervalSince1970
        do {
            let updated = try await networkService.updateExercise(id: id, payload: payload)
            exercises.removeAll { $0.id == id }
            exercises.removeAll { $0.id == updated.id }
            exercises.append(updated)
            exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            databaseManager.cacheExercises(exercises, replace: true)
            return updated
        } catch {
            guard var existing = exercises.first(where: { $0.id == id }), !existing.isSystem else {
                throw RepositoryError.queued("Saved locally. Exercise will sync when online.")
            }

            optimisticApply(&existing)
            existing.lastModified = now
            exercises.removeAll { $0.id == id }
            exercises.append(existing)
            exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            databaseManager.cacheExercises(exercises, replace: true)

            var queuedData = payload
            queuedData["id"] = AnyCodable(id)
            let queuePayload: [String: AnyCodable] = [
                "action": AnyCodable("updateExercise"),
                "data": AnyCodable(queuedData),
            ]
            queuePendingOperation(type: "batch_action", payload: queuePayload)
            throw RepositoryError.queued("Saved locally. Exercise will sync when online.")
        }
    }

    private func evaluateExerciseRecordPrompts(exercise: Exercise, sessionExercise: SessionExercise) {
        let completedSets = sessionExercise.sets.filter { !$0.isWarmup && $0.completed }
        guard !completedSets.isEmpty else { return }

        if exercise.trackHighestSet {
            let candidateHighest = completedSets.compactMap { set -> (weight: Double, reps: Int)? in
                guard let weight = set.weight, let reps = set.reps, weight > 0, reps > 0 else { return nil }
                return (weight, reps)
            }
            .max { lhs, rhs in
                if lhs.weight == rhs.weight {
                    return lhs.reps < rhs.reps
                }
                return lhs.weight < rhs.weight
            }

            if let candidateHighest {
                let shouldPrompt = shouldPromptForHighestSet(
                    candidateWeight: candidateHighest.weight,
                    candidateReps: candidateHighest.reps,
                    currentWeight: exercise.highestSetWeight,
                    currentReps: exercise.highestSetReps
                )
                if shouldPrompt {
                    let key = "highest:\(exercise.id):\(String(format: "%.4f", candidateHighest.weight)):\(candidateHighest.reps)"
                    enqueueExerciseRecordPrompt(
                        ExerciseRecordPrompt(
                            id: UUID().uuidString,
                            key: key,
                            kind: .highestSet,
                            exerciseId: exercise.id,
                            exerciseName: exercise.name,
                            candidateWeight: candidateHighest.weight,
                            candidateReps: candidateHighest.reps,
                            candidateOneRepMax: nil,
                            currentWeight: exercise.highestSetWeight,
                            currentReps: exercise.highestSetReps,
                            currentOneRepMax: nil
                        )
                    )
                }
            }
        }

        if exercise.trackOneRepMax {
            let candidateOneRepMax = completedSets.compactMap { set -> Double? in
                guard let weight = set.weight, let reps = set.reps, weight > 0, reps > 0 else { return nil }
                return estimateOneRepMax(weight: weight, reps: reps)
            }
            .max()

            if let candidateOneRepMax,
               candidateOneRepMax > ((exercise.oneRepMax ?? 0) + 0.0001) {
                let key = "one_rm:\(exercise.id):\(String(format: "%.4f", candidateOneRepMax))"
                enqueueExerciseRecordPrompt(
                    ExerciseRecordPrompt(
                        id: UUID().uuidString,
                        key: key,
                        kind: .oneRepMax,
                        exerciseId: exercise.id,
                        exerciseName: exercise.name,
                        candidateWeight: nil,
                        candidateReps: nil,
                        candidateOneRepMax: candidateOneRepMax,
                        currentWeight: nil,
                        currentReps: nil,
                        currentOneRepMax: exercise.oneRepMax
                    )
                )
            }
        }
    }

    private func shouldPromptForHighestSet(
        candidateWeight: Double,
        candidateReps: Int,
        currentWeight: Double?,
        currentReps: Int?
    ) -> Bool {
        guard let currentWeight else { return true }
        if candidateWeight > currentWeight + 0.0001 {
            return true
        }
        if abs(candidateWeight - currentWeight) <= 0.0001 {
            return candidateReps > (currentReps ?? 0)
        }
        return false
    }

    private func enqueueExerciseRecordPrompt(_ prompt: ExerciseRecordPrompt) {
        guard !ignoredExerciseRecordPromptKeys.contains(prompt.key) else { return }
        if pendingExerciseRecordPrompt?.key == prompt.key {
            return
        }
        if queuedExerciseRecordPrompts.contains(where: { $0.key == prompt.key }) {
            return
        }

        if pendingExerciseRecordPrompt == nil {
            pendingExerciseRecordPrompt = prompt
        } else {
            queuedExerciseRecordPrompts.append(prompt)
        }
    }

    private func promoteNextExerciseRecordPrompt() {
        guard pendingExerciseRecordPrompt == nil else { return }
        guard !queuedExerciseRecordPrompts.isEmpty else { return }
        pendingExerciseRecordPrompt = queuedExerciseRecordPrompts.removeFirst()
    }

    private func applyExerciseRecordPrompt(_ prompt: ExerciseRecordPrompt) async throws {
        switch prompt.kind {
        case .highestSet:
            _ = try await updateExercisePartial(
                id: prompt.exerciseId,
                payload: [
                    "highest_set_weight": AnyCodable(prompt.candidateWeight as Any),
                    "highest_set_reps": AnyCodable(prompt.candidateReps as Any),
                ]
            ) { exercise in
                exercise.highestSetWeight = prompt.candidateWeight
                exercise.highestSetReps = prompt.candidateReps
            }

        case .oneRepMax:
            _ = try await updateExercisePartial(
                id: prompt.exerciseId,
                payload: [
                    "one_rep_max": AnyCodable(prompt.candidateOneRepMax as Any),
                ]
            ) { exercise in
                exercise.oneRepMax = prompt.candidateOneRepMax
            }
        }
    }

    private func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        weight * (1.0 + (Double(reps) / 30.0))
    }

    private func buildLocalSession(templateId: String?, timestamp: Double) -> WorkoutSession {
        let template = templates.first(where: { $0.id == templateId })
        let defaults = templateId.map(getProgressiveOverloadDefaults(templateId:)) ?? [:]
        let sessionId = UUID().uuidString

        let sessionExercises = (template?.exercises.sorted(by: { $0.position < $1.position }) ?? []).map { templateExercise in
            let defaultSets = defaults[templateExercise.exerciseId]
            let exerciseMeta = exercise(forSessionExerciseId: templateExercise.exerciseId)
            let sets = buildSets(
                for: templateExercise,
                sessionExerciseId: UUID().uuidString,
                exerciseMeta: exerciseMeta,
                defaults: defaultSets
            )
            return SessionExercise(
                id: UUID().uuidString,
                sessionId: sessionId,
                exerciseId: templateExercise.exerciseId,
                position: templateExercise.position,
                notes: templateExercise.notes,
                sets: sets
            )
        }

        return WorkoutSession(
            id: sessionId,
            templateId: templateId,
            date: timestamp,
            startedAt: nil,
            finishedAt: nil,
            durationSecs: nil,
            notes: nil,
            status: "in_progress",
            lastModified: timestamp,
            exercises: sessionExercises
        )
    }

    private func buildSets(
        for templateExercise: TemplateExercise,
        sessionExerciseId: String,
        exerciseMeta: Exercise?,
        defaults: [SessionSet]?
    ) -> [SessionSet] {
        if let defaults, !defaults.isEmpty {
            return defaults.enumerated().map { index, previous in
                SessionSet(
                    id: UUID().uuidString,
                    sessionExerciseId: sessionExerciseId,
                    setNumber: index + 1,
                    reps: previous.reps,
                    weight: previous.weight,
                    durationSecs: previous.durationSecs,
                    distance: previous.distance,
                    isWarmup: previous.isWarmup,
                    usedAccessories: previous.usedAccessories,
                    bandColor: previous.bandColor,
                    completed: false
                )
            }
        }

        let setCount = max(1, templateExercise.defaultSets ?? 3)
        let warmupSets = max(0, exerciseMeta?.warmupSets ?? 0)
        return (1 ... setCount).map { number in
            SessionSet(
                id: UUID().uuidString,
                sessionExerciseId: sessionExerciseId,
                setNumber: number,
                reps: templateExercise.defaultReps,
                weight: templateExercise.defaultWeight,
                durationSecs: templateExercise.defaultDurationSecs,
                distance: templateExercise.defaultDistance,
                isWarmup: number <= warmupSets,
                usedAccessories: [],
                bandColor: nil,
                completed: false
            )
        }
    }

    private func shouldRunFullSync() -> Bool {
        let lastFullSync = databaseManager.lastFullSyncTimestamp()
        guard lastFullSync > 0 else { return true }
        return Date().timeIntervalSince1970 - lastFullSync > fullSyncInterval
    }

    private func shouldRefreshMetricsSummary(force: Bool) -> Bool {
        if force {
            return true
        }
        guard let lastMetricsFetchAt else {
            return true
        }
        return Date().timeIntervalSince(lastMetricsFetchAt) > metricsRefreshInterval
    }

    private func localMetricsSummary() -> MetricsSummary {
        let completed = sessions.filter { $0.status == "completed" }
        let totalSessions = completed.count

        let totalVolume = completed.reduce(into: 0.0) { partialResult, session in
            for exercise in session.exercises {
                for set in exercise.sets where set.completed {
                    guard let reps = set.reps, let weight = set.weight else { continue }
                    partialResult += Double(reps) * weight
                }
            }
        }

        var bestByExercise: [String: Double] = [:]
        for session in completed {
            for exercise in session.exercises {
                let maxWeight = exercise.sets.compactMap(\.weight).max() ?? 0
                bestByExercise[exercise.exerciseId] = max(bestByExercise[exercise.exerciseId] ?? 0, maxWeight)
            }
        }

        let streaks = calculateStreaks(from: completed)
        return MetricsSummary(
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            totalSessions: totalSessions,
            totalVolume: totalVolume,
            prCount: bestByExercise.filter { $0.value > 0 }.count
        )
    }

    private func calculateStreaks(from sessions: [WorkoutSession]) -> (current: Int, longest: Int) {
        let calendar = Calendar.current
        let completedDays = Set(
            sessions.map { calendar.startOfDay(for: Date(timeIntervalSince1970: $0.date)) }
        )

        guard !completedDays.isEmpty else { return (0, 0) }

        var longest = 1
        let sortedDays = completedDays.sorted()
        var rolling = 1
        for index in 1 ..< sortedDays.count {
            let previous = sortedDays[index - 1]
            let current = sortedDays[index]
            if calendar.dateComponents([.day], from: previous, to: current).day == 1 {
                rolling += 1
            } else {
                longest = max(longest, rolling)
                rolling = 1
            }
        }
        longest = max(longest, rolling)

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var cursor: Date
        if completedDays.contains(today) {
            cursor = today
        } else if completedDays.contains(yesterday) {
            cursor = yesterday
        } else {
            return (0, longest)
        }

        var currentStreak = 0
        while completedDays.contains(cursor) {
            currentStreak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return (currentStreak, longest)
    }
}
