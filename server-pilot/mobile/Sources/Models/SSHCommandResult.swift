import Foundation

struct SSHCommandResult: Hashable {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
