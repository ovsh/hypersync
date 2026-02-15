import AppKit
import Combine
import Foundation
import SwiftUI

final class AppState: ObservableObject, @unchecked Sendable {
    @Published var isSyncing = false
    @Published var syncStatus: SyncStatus = AppState.restoreSyncStatus()
    @Published var lastSyncAt: Date? = UserDefaults.standard.object(forKey: "lastSyncAt") as? Date
    @Published var lastErrorMessage: String? = UserDefaults.standard.string(forKey: "lastErrorMessage")
    @Published var lastSummary: SyncSummary?
    @Published var isRunningSetupCheck = false
    @Published var setupCheckPassed: Bool? = UserDefaults.standard.object(forKey: "setupCheckPassed") as? Bool
    @Published var setupCheckLines: [String] = []
    @Published var lastSetupCheckAt: Date?
    @Published var isAwaitingAuthSetup = false
    @Published var updateAvailable: UpdateInfo?
    @Published var isCheckingForUpdate = false
    @Published var isDownloadingUpdate = false
    @Published var updateError: String?
    @Published var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    private static func restoreSyncStatus() -> SyncStatus {
        guard let raw = UserDefaults.standard.string(forKey: "lastSyncStatus") else { return .idle }
        switch raw {
        case "succeeded": return .succeeded
        case "failed": return .failed
        default: return .idle
        }
    }

    private func persistSyncState() {
        let defaults = UserDefaults.standard
        defaults.set(lastSyncAt, forKey: "lastSyncAt")
        defaults.set(lastErrorMessage, forKey: "lastErrorMessage")
        switch syncStatus {
        case .succeeded: defaults.set("succeeded", forKey: "lastSyncStatus")
        case .failed: defaults.set("failed", forKey: "lastSyncStatus")
        default: defaults.removeObject(forKey: "lastSyncStatus")
        }
    }

    private func persistSetupCheckPassed() {
        if let passed = setupCheckPassed {
            UserDefaults.standard.set(passed, forKey: "setupCheckPassed")
        } else {
            UserDefaults.standard.removeObject(forKey: "setupCheckPassed")
        }
    }

    let settingsStore: SettingsStore
    let logStore: LogStore

    private let syncService = SyncService()
    private let setupChecker = SetupChecker()
    private let updateChecker = UpdateChecker()

    private var autoSyncTimer: Timer?
    private var updateCheckTimer: Timer?
    private var settingsObserver: AnyCancellable?

    init(settingsStore: SettingsStore = SettingsStore(), logStore: LogStore = LogStore()) {
        self.settingsStore = settingsStore
        self.logStore = logStore

        self.settingsObserver = settingsStore.$settings.sink { [weak self] _ in
            self?.configureAutoSyncTimer()
        }

        configureAutoSyncTimer()
        logStore.append(.info, "Hypersync started.")

        // Run setup check shortly after launch if remote is configured
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            let remote = self.settingsStore.settings.remoteGitURL.trimmed
            if !remote.isEmpty && GitSync.isGitHubRemote(remote) {
                self.runSetupCheck()
            }
        }

        // Check for updates shortly after launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.checkForUpdate()
        }
        configureUpdateCheckTimer()
    }

    deinit {
        autoSyncTimer?.invalidate()
        updateCheckTimer?.invalidate()
    }

    var menuIconName: String {
        switch syncStatus {
        case .idle:
            return "arrow.triangle.2.circlepath"
        case .syncing:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .succeeded:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        }
    }

    var statusLine: String {
        switch syncStatus {
        case .idle:
            return "Idle"
        case .syncing:
            return "Syncing"
        case .succeeded:
            return "Last sync succeeded"
        case .failed:
            return "Last sync failed"
        }
    }

    var needsSetup: Bool {
        let remote = settingsStore.settings.remoteGitURL.trimmed
        if remote.isEmpty { return true }
        if !GitSync.isGitHubRemote(remote) { return true }
        if setupCheckPassed == false { return true }
        if setupCheckPassed == nil && lastSyncAt == nil { return true }
        return false
    }

    func syncNow(trigger: String) {
        if isSyncing {
            logStore.append(.warn, "Sync already running. Ignoring trigger: \(trigger)")
            return
        }

        let settings = settingsStore.settings
        if settings.remoteGitURL.trimmed.isEmpty {
            syncStatus = .failed
            lastSyncAt = Date()
            lastErrorMessage = "Configure a GitHub repo URL in Settings before syncing."
            persistSyncState()
            logStore.append(.error, "Sync blocked: missing remote GitHub repo URL.")
            return
        }

        // For manual syncs, probe git auth first and auto-fix if needed
        if trigger == "manual" && !ensureGitAuth(remote: settings.remoteGitURL.trimmed) {
            return
        }

        isAwaitingAuthSetup = false
        isSyncing = true
        syncStatus = .syncing
        lastErrorMessage = nil
        logStore.append(.info, "Starting sync (trigger: \(trigger))")
        Analytics.track(.syncStarted(trigger: trigger))

        let syncStartedAt = Date()
        DispatchQueue.global(qos: .userInitiated).async { [syncService] in
            do {
                let summary = try syncService.run(settings: settings) { level, message in
                    DispatchQueue.main.async { [weak self] in
                        self?.logStore.append(level, message)
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.isSyncing = false
                    self.syncStatus = .succeeded
                    self.lastSyncAt = Date()
                    self.lastSummary = summary
                    self.lastErrorMessage = nil
                    self.setupCheckPassed = true
                    self.logStore.append(.info, "Sync completed: updated global agent config")
                    self.persistSyncState()
                    let durationMs = Int(Date().timeIntervalSince(syncStartedAt) * 1000)
                    Analytics.track(.syncCompleted(trigger: trigger, mappingCount: summary.mappingCount, durationMs: durationMs))
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.isSyncing = false
                    self.syncStatus = .failed
                    self.lastSyncAt = Date()
                    self.lastErrorMessage = error.localizedDescription
                    self.logStore.append(.error, error.localizedDescription)
                    self.persistSyncState()
                    let durationMs = Int(Date().timeIntervalSince(syncStartedAt) * 1000)
                    Analytics.track(.syncFailed(trigger: trigger, error: error.localizedDescription, durationMs: durationMs))
                }
            }
        }
    }

    func saveSettings(_ settings: AppSettings) {
        settingsStore.replace(with: settings)
        setupCheckPassed = nil
        persistSetupCheckPassed()
        setupCheckLines = []
        logStore.append(.info, "Settings saved.")
        Analytics.track(.settingsSaved(autoSyncEnabled: settings.autoSyncEnabled, intervalMinutes: settings.autoSyncIntervalMinutes))

        // Auto-run setup check when remote URL looks valid
        let remote = settings.remoteGitURL.trimmed
        if !remote.isEmpty && GitSync.isGitHubRemote(remote) {
            runSetupCheck()
        }
    }

    func runSetupCheck() {
        if isRunningSetupCheck {
            return
        }

        let remote = settingsStore.settings.remoteGitURL
        isRunningSetupCheck = true
        setupCheckLines = []
        setupCheckPassed = nil
        logStore.append(.info, "Running setup check.")

        DispatchQueue.global(qos: .userInitiated).async { [setupChecker] in
            let result = setupChecker.run(remoteGitURL: remote)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isRunningSetupCheck = false
                self.setupCheckPassed = result.passed
                self.setupCheckLines = result.lines
                self.lastSetupCheckAt = result.checkedAt
                self.logStore.append(result.passed ? .info : .warn, result.passed ? "Setup check passed." : "Setup check failed.")
                self.persistSetupCheckPassed()
                Analytics.track(.setupCheckRun(passed: result.passed))
            }
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = true
        Analytics.track(.onboardingCompleted)
        Analytics.identify(properties: [
            "has_completed_onboarding": true,
            "auto_sync_enabled": settingsStore.settings.autoSyncEnabled
        ])
    }

    func openLogsFile() {
        let url = SettingsStore.appSupportDirectory().appendingPathComponent("sync.log")
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func checkForUpdate() {
        guard !isCheckingForUpdate else { return }
        isCheckingForUpdate = true
        updateError = nil

        Task { [updateChecker] in
            let info = await updateChecker.checkForUpdate()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isCheckingForUpdate = false
                self.updateAvailable = info
                if let info {
                    self.logStore.append(.info, "Update available: v\(info.version)")
                    Analytics.track(.updateShown(version: info.version))
                }
            }
        }
    }

    func installUpdate() {
        guard let update = updateAvailable else { return }
        guard !isDownloadingUpdate else { return }
        isDownloadingUpdate = true
        updateError = nil
        logStore.append(.info, "Downloading update v\(update.version)...")
        Analytics.track(.updateStarted(version: update.version))

        Task { [updateChecker] in
            do {
                try await updateChecker.downloadAndInstall(from: update.downloadURL)
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.isDownloadingUpdate = false
                    self.updateError = error.localizedDescription
                    self.logStore.append(.error, "Update failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Git Auth Detection

    /// Probes the remote with `git ls-remote`. Returns true if auth works, false if it failed
    /// and a fix was attempted (Terminal opened with gh auth login).
    private func ensureGitAuth(remote: String) -> Bool {
        let runner = CommandRunner()
        let isHTTPS = SetupChecker.isHTTPS(remote)

        var env: [String: String] = [:]
        if !isHTTPS {
            env["GIT_SSH_COMMAND"] = "ssh -o BatchMode=yes"
        }

        let result: CommandResult
        do {
            result = try runner.run(
                command: "/usr/bin/env",
                arguments: ["git", "ls-remote", remote, "HEAD"],
                extraEnvironment: env
            )
        } catch {
            // Could not even run git — let the normal sync flow handle it
            return true
        }

        guard result.exitCode != 0 else { return true }

        let combined = (result.stderr + "\n" + result.stdout).lowercased()
        let isAuthError = combined.contains("could not read username")
            || combined.contains("authentication failed")
            || combined.contains("permission denied")
            || combined.contains("returned error: 401")
            || combined.contains("returned error: 403")
            || combined.contains("no such identity")
            || combined.contains("no identities")

        guard isAuthError else {
            // Not an auth error — let the normal sync flow handle it
            return true
        }

        logStore.append(.warn, "Git auth probe failed. Attempting auto-fix via GitHub CLI.")

        // Determine the fix command
        let fixCommand: String
        do {
            let whichGh = try runner.run(command: "/usr/bin/env", arguments: ["which", "gh"])
            if whichGh.exitCode == 0 {
                fixCommand = "gh auth login --web -p https && gh auth setup-git"
            } else {
                fixCommand = "brew install gh && gh auth login --web -p https && gh auth setup-git"
            }
        } catch {
            fixCommand = "brew install gh && gh auth login --web -p https && gh auth setup-git"
        }

        openTerminalWithCommand(fixCommand)

        isAwaitingAuthSetup = true
        syncStatus = .failed
        lastErrorMessage = "Setting up Git credentials — complete setup in Terminal, then click Sync again."
        logStore.append(.info, "Opened Terminal with: \(fixCommand)")
        return false
    }

    func openTerminalWithCommand(_ command: String) {
        let escaped = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\" to do script \"\(escaped)\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private func configureAutoSyncTimer() {
        autoSyncTimer?.invalidate()

        let settings = settingsStore.settings
        guard settings.autoSyncEnabled else {
            logStore.append(.info, "Auto-sync disabled")
            return
        }

        let minutes = max(5, settings.autoSyncIntervalMinutes)
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: true) { [weak self] _ in
            self?.syncNow(trigger: "auto")
        }

        logStore.append(.info, "Auto-sync enabled every \(minutes) minutes")
    }

    private func configureUpdateCheckTimer() {
        updateCheckTimer?.invalidate()
        // Check for updates every 4 hours
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 4 * 60 * 60, repeats: true) { [weak self] _ in
            self?.checkForUpdate()
        }
    }
}
