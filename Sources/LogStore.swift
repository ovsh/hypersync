import Foundation
import SwiftUI

enum LogLevel: String {
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
}

final class LogStore: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []

    private let maxEntries = 300
    private let logFileURL: URL

    init() {
        self.logFileURL = SettingsStore.appSupportDirectory().appendingPathComponent("sync.log")
    }

    func append(_ level: LogLevel, _ message: String) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        let formatter = ISO8601DateFormatter()
        let line = "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] \(entry.message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }

        do {
            let handle = try FileHandle(forWritingTo: logFileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            print("Failed to append log: \(error)")
        }
    }
}
