import Foundation

struct PackageState: Codable, Hashable {
    let serverId: String
    let lastUpdatedAt: Int?
    let daysSinceUpdate: Double?
}
