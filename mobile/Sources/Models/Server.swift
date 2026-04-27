import Foundation

enum ServerType: String, Codable {
    case local
    case remote
}

struct ServerInfo: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let type: ServerType
    let online: Bool
    let sshState: String
    let canWake: Bool
}
