import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings

    let settingsFileURL: URL

    init() {
        let appSupportURL = SettingsStore.appSupportDirectory()
        self.settingsFileURL = appSupportURL.appendingPathComponent("settings.json")
        self.settings = AppSettings.defaults()
        load()
    }

    func replace(with updated: AppSettings) {
        settings = updated
        saveAsync()
    }

    private func load() {
        do {
            let data = try Data(contentsOf: settingsFileURL)
            settings = try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            saveAsync()
        }
    }

    private func saveAsync() {
        let url = settingsFileURL
        let snapshot = settings
        DispatchQueue.global(qos: .utility).async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                print("Failed to save settings: \(error)")
            }
        }
    }

    static func appSupportDirectory() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("HyperSync")

        if !fileManager.fileExists(atPath: base.path) {
            try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }
}
