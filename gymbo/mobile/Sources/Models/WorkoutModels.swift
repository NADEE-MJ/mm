import Foundation

// MARK: - Exercise Enums

enum MuscleGroup: Int, CaseIterable, Identifiable {
    case chest = 1
    case back = 2
    case shoulders = 4
    case biceps = 8
    case triceps = 16
    case legs = 32
    case core = 64
    case cardio = 128
    case fullBody = 256
    case plyometric = 512
    case pilates = 1024
    case mobility = 2048

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .legs: return "Legs"
        case .core: return "Core"
        case .cardio: return "Cardio"
        case .fullBody: return "Full Body"
        case .plyometric: return "Plyometric"
        case .pilates: return "Pilates"
        case .mobility: return "Mobility"
        }
    }
}

enum WeightType: Int, CaseIterable, Identifiable {
    case bodyweight = 1
    case dumbbells = 2
    case plates = 3
    case rawWeight = 4
    case bands = 5
    case timeBased = 6
    case distance = 7

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .bodyweight: return "No Weight / Bodyweight"
        case .dumbbells: return "Dumbbells"
        case .plates: return "Plates"
        case .rawWeight: return "Raw Weight (Machine/Cable)"
        case .bands: return "Bands"
        case .timeBased: return "Time Based"
        case .distance: return "Distance"
        }
    }
}

enum ExerciseWorkoutType: Int, CaseIterable, Identifiable {
    case lifting = 1
    case running = 2
    case pilates = 3
    case mobility = 4
    case plyometric = 5
    case hyrox = 6
    case custom = 7

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .lifting: return "Lifting"
        case .running: return "Running"
        case .pilates: return "Pilates"
        case .mobility: return "Mobility/Stretching"
        case .plyometric: return "Plyometric"
        case .hyrox: return "Hyrox Training"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Helper Functions

func weightTypeDisplayName(_ value: Int) -> String {
    WeightType(rawValue: value)?.label ?? "Unknown"
}

func muscleGroupsDisplayName(_ bitmask: Int) -> String {
    let groups = MuscleGroup.allCases.filter { bitmask & $0.rawValue != 0 }
    if groups.isEmpty { return "—" }
    return groups.map(\.label).joined(separator: ", ")
}

func exerciseTypeEmoji(workoutType: Int?, weightType: Int) -> String {
    if let workoutType, let type = ExerciseWorkoutType(rawValue: workoutType) {
        switch type {
        case .lifting: return "🏋️"
        case .running: return "🏃"
        case .pilates: return "🧘"
        case .mobility: return "🤸"
        case .plyometric: return "⚡"
        case .hyrox: return "🔥"
        case .custom: return "💪"
        }
    }

    switch WeightType(rawValue: weightType) {
    case .bodyweight: return "🤸"
    case .dumbbells: return "🏋️"
    case .plates: return "🏋️"
    case .rawWeight: return "🏋️"
    case .bands: return "🟣"
    case .timeBased: return "⏱️"
    case .distance: return "🏃"
    case .none: return "💪"
    }
}

func muscleGroupEmoji(_ group: MuscleGroup) -> String {
    switch group {
    case .chest: return "🫁"
    case .back: return "🦍"
    case .shoulders: return "🦾"
    case .biceps: return "💪"
    case .triceps: return "🏹"
    case .legs: return "🦵"
    case .core: return "🧱"
    case .cardio: return "❤️"
    case .fullBody: return "🧍"
    case .plyometric: return "⚡"
    case .pilates: return "🧘"
    case .mobility: return "🤸"
    }
}

func muscleGroupEmojiSummary(_ bitmask: Int, limit: Int = 2) -> String {
    let groups = MuscleGroup.allCases.filter { bitmask & $0.rawValue != 0 }
    guard !groups.isEmpty else { return "" }

    let emojis = groups.map(muscleGroupEmoji)
    let visible = Array(emojis.prefix(max(1, limit)))
    let remaining = max(0, emojis.count - visible.count)
    if remaining > 0 {
        return "\(visible.joined(separator: " ")) +\(remaining)"
    }
    return visible.joined(separator: " ")
}

// MARK: - Models

struct WorkoutType: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var slug: String
    var icon: String?
    var color: String?
    var isSystem: Bool
    var lastModified: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, icon, color
        case isSystem = "is_system"
        case lastModified = "last_modified"
    }
}

struct Exercise: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var description: String?
    var videoURL: String?
    var muscleGroups: Int
    var workoutType: Int?
    var weightType: Int
    var warmupSets: Int
    var accessories: [String]
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
    var sourceExerciseId: String?
    var lastModified: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case videoURL = "video_url"
        case muscleGroups = "muscle_groups"
        case workoutType = "workout_type"
        case weightType = "weight_type"
        case warmupSets = "warmup_sets"
        case accessories
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
        case sourceExerciseId = "source_exercise_id"
        case lastModified = "last_modified"
    }

    init(
        id: String,
        name: String,
        description: String?,
        videoURL: String? = nil,
        muscleGroups: Int,
        workoutType: Int?,
        weightType: Int,
        warmupSets: Int = 0,
        accessories: [String] = [],
        goalRepsMin: Int? = nil,
        goalRepsMax: Int? = nil,
        showHighestSet: Bool = false,
        trackHighestSet: Bool = false,
        highestSetWeight: Double? = nil,
        highestSetReps: Int? = nil,
        showOneRepMax: Bool = false,
        trackOneRepMax: Bool = false,
        oneRepMax: Double? = nil,
        isSystem: Bool,
        sourceExerciseId: String? = nil,
        lastModified: Double?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.videoURL = videoURL
        self.muscleGroups = muscleGroups
        self.workoutType = workoutType
        self.weightType = weightType
        self.warmupSets = max(0, warmupSets)
        self.accessories = accessories
        self.goalRepsMin = goalRepsMin
        self.goalRepsMax = goalRepsMax
        self.showHighestSet = showHighestSet
        self.trackHighestSet = trackHighestSet
        self.highestSetWeight = highestSetWeight
        self.highestSetReps = highestSetReps
        self.showOneRepMax = showOneRepMax
        self.trackOneRepMax = trackOneRepMax
        self.oneRepMax = oneRepMax
        self.isSystem = isSystem
        self.sourceExerciseId = sourceExerciseId
        self.lastModified = lastModified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        videoURL = try container.decodeIfPresent(String.self, forKey: .videoURL)
        muscleGroups = try container.decodeIfPresent(Int.self, forKey: .muscleGroups) ?? 0
        workoutType = try container.decodeIfPresent(Int.self, forKey: .workoutType)
        weightType = try container.decode(Int.self, forKey: .weightType)
        warmupSets = max(0, try container.decodeIfPresent(Int.self, forKey: .warmupSets) ?? 0)
        accessories = try container.decodeIfPresent([String].self, forKey: .accessories) ?? []
        goalRepsMin = try container.decodeIfPresent(Int.self, forKey: .goalRepsMin)
        goalRepsMax = try container.decodeIfPresent(Int.self, forKey: .goalRepsMax)
        showHighestSet = try container.decodeIfPresent(Bool.self, forKey: .showHighestSet) ?? false
        trackHighestSet = try container.decodeIfPresent(Bool.self, forKey: .trackHighestSet) ?? false
        highestSetWeight = try container.decodeIfPresent(Double.self, forKey: .highestSetWeight)
        highestSetReps = try container.decodeIfPresent(Int.self, forKey: .highestSetReps)
        showOneRepMax = try container.decodeIfPresent(Bool.self, forKey: .showOneRepMax) ?? false
        trackOneRepMax = try container.decodeIfPresent(Bool.self, forKey: .trackOneRepMax) ?? false
        oneRepMax = try container.decodeIfPresent(Double.self, forKey: .oneRepMax)
        isSystem = try container.decode(Bool.self, forKey: .isSystem)
        sourceExerciseId = try container.decodeIfPresent(String.self, forKey: .sourceExerciseId)
        lastModified = try container.decodeIfPresent(Double.self, forKey: .lastModified)
    }
}

struct TemplateExercise: Codable, Identifiable, Hashable {
    var id: String
    var templateId: String
    var exerciseId: String
    var position: Int
    var defaultSets: Int?
    var defaultReps: Int?
    var defaultWeight: Double?
    var defaultDurationSecs: Int?
    var defaultDistance: Double?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, position, notes
        case templateId = "template_id"
        case exerciseId = "exercise_id"
        case defaultSets = "default_sets"
        case defaultReps = "default_reps"
        case defaultWeight = "default_weight"
        case defaultDurationSecs = "default_duration_secs"
        case defaultDistance = "default_distance"
    }
}

struct WorkoutTemplate: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var description: String?
    var workoutTypeId: String?
    var isSystem: Bool
    var createdAt: Double?
    var lastModified: Double?
    var exercises: [TemplateExercise]

    enum CodingKeys: String, CodingKey {
        case id, name, description, exercises
        case workoutTypeId = "workout_type_id"
        case isSystem = "is_system"
        case createdAt = "created_at"
        case lastModified = "last_modified"
    }
}

struct WeeklyScheduleEntry: Codable, Identifiable, Hashable {
    var id: String
    var dayOfWeek: Int
    var templateId: String?
    var lastModified: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case dayOfWeek = "day_of_week"
        case templateId = "template_id"
        case lastModified = "last_modified"
    }
}

struct SessionSet: Codable, Identifiable, Hashable {
    var id: String
    var sessionExerciseId: String
    var setNumber: Int
    var reps: Int?
    var weight: Double?
    var durationSecs: Int?
    var distance: Double?
    var isWarmup: Bool
    var usedAccessories: [String]
    var bandColor: String?
    var completed: Bool

    enum CodingKeys: String, CodingKey {
        case id, reps, weight, distance, completed
        case isWarmup = "is_warmup"
        case usedAccessories = "used_accessories"
        case bandColor = "band_color"
        case sessionExerciseId = "session_exercise_id"
        case setNumber = "set_number"
        case durationSecs = "duration_secs"
    }

    init(
        id: String,
        sessionExerciseId: String,
        setNumber: Int,
        reps: Int?,
        weight: Double?,
        durationSecs: Int?,
        distance: Double?,
        isWarmup: Bool = false,
        usedAccessories: [String] = [],
        bandColor: String? = nil,
        completed: Bool
    ) {
        self.id = id
        self.sessionExerciseId = sessionExerciseId
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.durationSecs = durationSecs
        self.distance = distance
        self.isWarmup = isWarmup
        self.usedAccessories = usedAccessories
        self.bandColor = bandColor
        self.completed = completed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sessionExerciseId = try container.decode(String.self, forKey: .sessionExerciseId)
        setNumber = try container.decode(Int.self, forKey: .setNumber)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        durationSecs = try container.decodeIfPresent(Int.self, forKey: .durationSecs)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        isWarmup = try container.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
        usedAccessories = try container.decodeIfPresent([String].self, forKey: .usedAccessories) ?? []
        bandColor = try container.decodeIfPresent(String.self, forKey: .bandColor)
        completed = try container.decode(Bool.self, forKey: .completed)
    }
}

struct SessionExercise: Codable, Identifiable, Hashable {
    var id: String
    var sessionId: String
    var exerciseId: String
    var position: Int
    var notes: String?
    var sets: [SessionSet]

    enum CodingKeys: String, CodingKey {
        case id, position, notes, sets
        case sessionId = "session_id"
        case exerciseId = "exercise_id"
    }
}

struct WorkoutSession: Codable, Identifiable, Hashable {
    var id: String
    var templateId: String?
    var date: Double
    var startedAt: Double?
    var finishedAt: Double?
    var durationSecs: Int?
    var notes: String?
    var status: String
    var lastModified: Double?
    var exercises: [SessionExercise]

    enum CodingKeys: String, CodingKey {
        case id, date, notes, status, exercises
        case templateId = "template_id"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case durationSecs = "duration_secs"
        case lastModified = "last_modified"
    }
}

struct PendingOperation: Codable, Identifiable {
    var id: String
    var type: String
    var payload: String
    var createdAt: Double
    var retryCount: Int
}
