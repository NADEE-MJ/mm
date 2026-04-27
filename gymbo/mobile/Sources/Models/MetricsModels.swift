import Foundation

struct MetricsSummary: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var totalSessions: Int
    var totalVolume: Double
    var prCount: Int

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case totalSessions = "total_sessions"
        case totalVolume = "total_volume"
        case prCount = "pr_count"
    }
}

struct CalendarDayMetric: Codable, Identifiable {
    var id: String { date }
    var date: String
    var sessionCount: Int
    var volume: Double

    enum CodingKeys: String, CodingKey {
        case date, volume
        case sessionCount = "session_count"
    }
}

struct ExerciseProgressPoint: Codable, Identifiable {
    var id: Double { timestamp }
    var timestamp: Double
    var weight: Double?
    var reps: Int?
    var estimated1RM: Double?

    enum CodingKeys: String, CodingKey {
        case timestamp, weight, reps
        case estimated1RM = "estimated_1rm"
    }
}

struct PRRecord: Codable, Identifiable {
    var id: String { "\(exerciseId)-\(reps ?? 0)-\(weight)" }
    var exerciseId: String
    var exerciseName: String
    var reps: Int?
    var weight: Double
    var achievedAt: Double

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case reps, weight
        case achievedAt = "achieved_at"
    }
}

struct FrequencyPoint: Codable, Identifiable {
    var id: String { "\(weekStart)-\(workoutTypeId ?? "unknown")" }
    var weekStart: String
    var workoutTypeId: String?
    var workoutTypeName: String?
    var sessionCount: Int

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case workoutTypeId = "workout_type_id"
        case workoutTypeName = "workout_type_name"
        case sessionCount = "session_count"
    }
}
