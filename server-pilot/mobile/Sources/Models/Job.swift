import Foundation

struct Job: Codable, Hashable, Identifiable {
    let id: String
    let command: String
    let schedule: String
    let enabled: Bool
    let createdAt: Int
    let lastRunAt: Int?
}
