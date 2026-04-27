import Foundation

enum RepositoryError: Error {
    case networkError(String)
    case notFound(String)
    case queued(String)
}

protocol DataRepository: AnyObject {
    func syncNow(forceFull: Bool) async
}
