import Foundation

struct SyncPlan {
    let mode: ScanMode
    let selectedRoots: [String]
    let missingConfiguredRoots: [String]
    let discoveredRoots: [String]
}

enum SyncPlannerError: LocalizedError {
    case noUsableScanRoots(checkoutPath: String, configured: [String], discovered: [String], mode: ScanMode)

    var errorDescription: String? {
        switch self {
        case .noUsableScanRoots(let checkoutPath, let configured, let discovered, let mode):
            let configuredText = configured.isEmpty ? "(none)" : configured.joined(separator: ", ")
            let discoveredText = discovered.isEmpty ? "(none)" : discovered.joined(separator: ", ")
            return """
            No usable team roots were found in the synced registry checkout.
            Checkout: \(checkoutPath)
            Mode: \(mode.rawValue)
            Configured roots: \(configuredText)
            Discovered roots: \(discoveredText)
            """
        }
    }
}

struct SyncPlanner {
    func plan(settings: AppSettings, registryRoot: URL, logger: @escaping (LogLevel, String) -> Void) throws -> SyncPlan {
        let fileManager = FileManager.default
        let discoveredRoots = TeamDiscovery.discover(registryRoot: registryRoot).map(\.folderName)
        let configuredRoots = normalizedRoots(settings.scanRoots)

        let requestedRoots: [String]
        switch settings.scanMode {
        case .auto:
            if !discoveredRoots.isEmpty {
                requestedRoots = discoveredRoots
            } else if !configuredRoots.isEmpty {
                requestedRoots = configuredRoots
            } else {
                requestedRoots = AppSettings.defaultScanRoots
            }
        case .explicit:
            requestedRoots = configuredRoots.isEmpty ? AppSettings.defaultScanRoots : configuredRoots
        }

        var selectedRoots: [String] = []
        var missingRoots: [String] = []

        for root in requestedRoots {
            let rootURL = registryRoot.appendingPathComponent(root).standardizedFileURL
            if fileManager.fileExists(atPath: rootURL.path) {
                selectedRoots.append(root)
            } else {
                missingRoots.append(root)
            }
        }

        // If the repo uses top-level skills/ and rules/ (no team folder),
        // treat "." as a synthetic root in auto mode.
        if settings.scanMode == .auto && selectedRoots.isEmpty && hasTopLevelContent(registryRoot: registryRoot, fileManager: fileManager) {
            selectedRoots = ["."]
        }

        guard !selectedRoots.isEmpty else {
            throw SyncPlannerError.noUsableScanRoots(
                checkoutPath: registryRoot.path,
                configured: configuredRoots,
                discovered: discoveredRoots,
                mode: settings.scanMode
            )
        }

        if settings.scanMode == .auto {
            logger(.info, "Auto scan mode selected roots: \(selectedRoots.joined(separator: ", "))")
        } else {
            logger(.info, "Explicit scan mode selected roots: \(selectedRoots.joined(separator: ", "))")
        }

        if !missingRoots.isEmpty {
            logger(.warn, "Skipping missing scan roots: \(missingRoots.joined(separator: ", "))")
        }

        return SyncPlan(
            mode: settings.scanMode,
            selectedRoots: selectedRoots,
            missingConfiguredRoots: missingRoots,
            discoveredRoots: discoveredRoots
        )
    }

    private func normalizedRoots(_ roots: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for root in roots.map(\.trimmed).filter({ !$0.isEmpty }) {
            if seen.insert(root).inserted {
                result.append(root)
            }
        }
        return result
    }

    private func hasTopLevelContent(registryRoot: URL, fileManager: FileManager) -> Bool {
        let topLevelSkills = registryRoot.appendingPathComponent("skills").path
        let topLevelRules = registryRoot.appendingPathComponent("rules").path
        return fileManager.fileExists(atPath: topLevelSkills) || fileManager.fileExists(atPath: topLevelRules)
    }
}
