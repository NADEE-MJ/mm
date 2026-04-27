import Foundation

struct ServiceStatus: Codable, Hashable, Identifiable {
    let name: String
    let displayName: String
    let unit: String
    let status: String
    let raw: String

    var id: String { name }
}
