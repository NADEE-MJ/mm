import Foundation

struct Job: Codable, Hashable, Identifiable {
    let id: String
    let serverId: String
    let command: String
    let schedule: String
    let enabled: Bool
    let lastRunAt: Int?
}
