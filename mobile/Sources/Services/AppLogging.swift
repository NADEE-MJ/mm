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
    private let dayFormatter: DateFormatter
    private let logsDirectoryURL: URL
    private let disabledLogURL: URL
    private let filePrefix = "app-debug-"
    private let maxSizeBytes = 2 * 1024 * 1024
    private let enabled: Bool

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logsDirectoryURL = documents.appendingPathComponent("logs", isDirectory: true)
        disabledLogURL = documents.appendingPathComponent("logs-disabled.txt")
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        enabled = Self.readBuildToggle()
        queue.sync {
            self.prepareCurrentDayLogFile()
        }
    }

    var isEnabled: Bool {
        enabled
    }

    func append(level: String, category: String, message: String) {
        guard enabled else { return }
        let line = "\(formatter.string(from: Date())) [\(level)] [\(category)] \(message)\n"
        queue.async {
            self.prepareCurrentDayLogFile()
            let fileURL = self.currentDayLogFileURL()
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                    self.trimIfNeeded(fileURL: fileURL)
                } catch {
                    try? handle.close()
                }
            }
        }
    }

    func clear() {
        guard enabled else { return }
        queue.async {
            let fileURL = self.currentDayLogFileURL()
            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    func exportURL() -> URL {
        guard enabled else {
            queue.sync {
                writeDisabledLogNoticeIfNeeded()
            }
            return disabledLogURL
        }

        queue.sync {
            prepareCurrentDayLogFile()
        }
        return currentDayLogFileURL()
    }

    private static func readBuildToggle() -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "FILE_LOGGING_ENABLED") else {
            return true
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        if let string = value as? String {
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "1" || normalized == "true" || normalized == "yes"
        }

        return true
    }

    private func currentDayLogFileURL(date: Date = Date()) -> URL {
        let day = dayFormatter.string(from: date)
        return logsDirectoryURL.appendingPathComponent("\(filePrefix)\(day).log")
    }

    private func prepareCurrentDayLogFile() {
        guard enabled else { return }
        try? FileManager.default.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
        purgeLogsOutsideCurrentDay()
        let fileURL = currentDayLogFileURL()
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    private func purgeLogsOutsideCurrentDay() {
        let todayFile = currentDayLogFileURL().lastPathComponent
        let files = (try? FileManager.default.contentsOfDirectory(
            at: logsDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        for file in files where file.lastPathComponent.hasPrefix(filePrefix) && file.lastPathComponent != todayFile {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func trimIfNeeded(fileURL: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? NSNumber
        else { return }
        let totalBytes = size.intValue
        guard totalBytes > maxSizeBytes else { return }

        let keepBytes = maxSizeBytes / 2
        let offset = max(0, totalBytes - keepBytes)

        guard let readHandle = try? FileHandle(forReadingFrom: fileURL) else { return }
        do {
            try readHandle.seek(toOffset: UInt64(offset))
            let data = try readHandle.readToEnd() ?? Data()
            try readHandle.close()
            try data.write(to: fileURL, options: .atomic)
        } catch {
            try? readHandle.close()
        }
    }

    private func writeDisabledLogNoticeIfNeeded() {
        let message = """
        File logging is disabled for this build.
        Set FILE_LOGGING_ENABLED=YES in App.xcconfig (or your generated xcconfig) to enable exports.
        """
        try? message.write(to: disabledLogURL, atomically: true, encoding: .utf8)
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

        FileLogStore.shared.append(level: level.rawValue, category: category.rawValue, message: message)
    }
}
