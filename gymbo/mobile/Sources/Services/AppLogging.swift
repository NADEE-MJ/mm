import Foundation

enum AppLogCategory: String {
    case app
    case auth
    case network
    case sync
    case db
}

enum AppLog {
    static func info(_ message: String, category: AppLogCategory = .app) {
        print("[INFO][\(category.rawValue)] \(message)")
    }

    static func error(_ message: String, category: AppLogCategory = .app) {
        print("[ERROR][\(category.rawValue)] \(message)")
    }
}
