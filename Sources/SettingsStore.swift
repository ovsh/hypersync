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
            migrateIfNeeded()
        } catch {
            saveAsync()
        }
    }

    private func migrateIfNeeded() {
        var changed = false
        let fm = FileManager.default
        let checkoutRoot = URL(fileURLWithPath: settings.checkoutPath.expandingTildePath)
        let hasEveryone = fm.fileExists(atPath: checkoutRoot.appendingPathComponent("everyone").path)
        let hasSharedGlobal = fm.fileExists(atPath: checkoutRoot.appendingPathComponent("shared-global").path)

        // Compatibility migration: choose the root that actually exists in the
        // current checkout instead of blindly rewriting legacy names.
        if hasSharedGlobal && !hasEveryone {
            for idx in settings.scanRoots.indices where settings.scanRoots[idx] == "everyone" {
                settings.scanRoots[idx] = "shared-global"
                changed = true
            }
        } else if hasEveryone && !hasSharedGlobal {
            for idx in settings.scanRoots.indices where settings.scanRoots[idx] == "shared-global" {
                settings.scanRoots[idx] = "everyone"
                changed = true
            }
        }

        // Normalize and de-duplicate roots after migration.
        var seen = Set<String>()
        let normalizedRoots = settings.scanRoots
            .map(\.trimmed)
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
        if normalizedRoots != settings.scanRoots {
            settings.scanRoots = normalizedRoots
            changed = true
        }

        if changed { saveAsync() }
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
        if let override = ProcessInfo.processInfo.environment["HYPERSYNC_APP_SUPPORT_DIR"],
           !override.isEmpty {
            let custom = URL(fileURLWithPath: override, isDirectory: true)
            let fm = FileManager.default
            if !fm.fileExists(atPath: custom.path) {
                try? fm.createDirectory(at: custom, withIntermediateDirectories: true)
            }
            return custom
        }

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
