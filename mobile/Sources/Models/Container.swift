import Foundation

struct Container: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let image: String
    let state: String
    let status: String
}
