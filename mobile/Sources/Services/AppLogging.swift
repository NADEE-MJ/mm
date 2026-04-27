import OSLog

enum AppLog {
    private static let logger = Logger(subsystem: "com.nadeem.mentat", category: "app")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .private)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .private)")
    }
}
