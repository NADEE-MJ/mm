import Foundation
import OSLog

enum DebugSettings {
    private static let loggingEnabledKey = "debug_logging_enabled"

    static var loggingEnabled: Bool {
        get {
            #if DEBUG
            if UserDefaults.standard.object(forKey: loggingEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: loggingEnabledKey)
            #else
            return false
            #endif
        }
        set {
            #if DEBUG
            UserDefaults.standard.set(newValue, forKey: loggingEnabledKey)
            #endif
        }
    }
}

enum AppLogCategory: String {
    case app
    case auth
    case network
    case websocket
    case database
    case debug
}

private enum AppLogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

final class FileLogStore: @unchecked Sendable {
    static let shared = FileLogStore()

    private let queue = DispatchQueue(label: "com.moviemanager.app.filelog")
    private let formatter = ISO8601DateFormatter()
    private let fileURL: URL
    private let rotatedFileURL: URL
    private let maxSizeBytes = 2 * 1024 * 1024

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("app-debug.log")
        rotatedFileURL = documents.appendingPathComponent("app-debug.log.1")
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        ensureFileExists()
    }

    func append(level: String, category: String, message: String) {
        let line = "\(formatter.string(from: Date())) [\(level)] [\(category)] \(message)\n"
        queue.async {
            self.rotateIfNeeded()
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } catch {
                    try? handle.close()
                }
            }
        }
    }

    func clear() {
        queue.async {
            try? "".write(to: self.fileURL, atomically: true, encoding: .utf8)
        }
    }

    func exportURL() -> URL {
        queue.sync {
            ensureFileExists()
        }
        return fileURL
    }

    private func ensureFileExists() {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    private func rotateIfNeeded() {
        ensureFileExists()
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? NSNumber,
              size.intValue > maxSizeBytes
        else { return }

        try? FileManager.default.removeItem(at: rotatedFileURL)
        try? FileManager.default.moveItem(at: fileURL, to: rotatedFileURL)
        ensureFileExists()
    }
}

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.moviemanager.app"

    static func debug(_ message: @autoclosure () -> String, category: AppLogCategory = .app) {
        guard DebugSettings.loggingEnabled else { return }
        write(level: .debug, category: category, message: message())
    }

    static func info(_ message: @autoclosure () -> String, category: AppLogCategory = .app) {
        guard DebugSettings.loggingEnabled else { return }
        write(level: .info, category: category, message: message())
    }

    static func warning(_ message: @autoclosure () -> String, category: AppLogCategory = .app) {
        write(level: .warning, category: category, message: message())
    }

    static func error(_ message: @autoclosure () -> String, category: AppLogCategory = .app) {
        write(level: .error, category: category, message: message())
    }

    private static func write(level: AppLogLevel, category: AppLogCategory, message: String) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }

        #if DEBUG
        FileLogStore.shared.append(level: level.rawValue, category: category.rawValue, message: message)
        #endif
    }
}
