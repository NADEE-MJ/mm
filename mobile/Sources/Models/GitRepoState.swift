import Foundation

struct GitRepoState: Codable, Hashable, Identifiable {
    let name: String
    let path: String
    let branch: String

    var id: String { name }
}
