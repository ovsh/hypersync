import Foundation
import XCTest

final class HypersyncXCUITests: XCTestCase {
    private let appName = "Hypersync"

    func testLaunchShowsSkillsWindow() throws {
        try requireEnabled()
        try requireAccessibility()
        let app = try launchApp()
        defer { app.terminate() }

        XCTAssertTrue(waitUntil(timeout: 12) { self.skillsWindowExists() }, "Expected Skills window on launch")
    }

    func testFirstRunShowsOnboarding() throws {
        try requireEnabled()
        try requireAccessibility()
        let app = try launchApp()
        defer { app.terminate() }

        XCTAssertTrue(waitUntil(timeout: 12) { self.onboardingVisible() }, "Expected onboarding to appear on first run")
    }

    func testReopenAfterClosingSkillsWindow() throws {
        try requireEnabled()
        try requireAccessibility()
        let app = try launchApp()
        defer { app.terminate() }

        XCTAssertTrue(waitUntil(timeout: 12) { self.skillsWindowExists() }, "Expected Skills window on launch")
        try closeSkillsWindow()
        XCTAssertTrue(waitUntil(timeout: 8) { !self.skillsWindowExists() }, "Expected Skills window to close")

        try reopenApp(bundleID: app.bundleID)
        XCTAssertTrue(waitUntil(timeout: 12) { self.skillsWindowExists() }, "Expected Skills window to reopen")
    }

    // MARK: - Helpers

    private func requireEnabled() throws {
        if ProcessInfo.processInfo.environment["HYPERSYNC_RUN_XCUITESTS"] != "1" {
            throw XCTSkip("Set HYPERSYNC_RUN_XCUITESTS=1 to run UI e2e tests.")
        }
    }

    private func requireAccessibility() throws {
        let out = try runAppleScript(#"tell application "System Events" to UI elements enabled"#).trimmingCharacters(in: .whitespacesAndNewlines)
        if out != "true" {
            throw XCTSkip("Accessibility permission is required for UI tests.")
        }
    }

    private func launchApp() throws -> ManagedApp {
        let env = ProcessInfo.processInfo.environment
        guard let appExec = env["HYPERSYNC_UI_TEST_APP_EXEC"], !appExec.isEmpty else {
            throw XCTSkip("Set HYPERSYNC_UI_TEST_APP_EXEC to the Hypersync executable path.")
        }
        let bundleID = env["HYPERSYNC_UI_TEST_BUNDLE_ID"] ?? "com.ovsh.hypersync.ui-tests"
        let appSupportDir = URL(fileURLWithPath: env["HYPERSYNC_UI_TEST_APP_SUPPORT_DIR"] ?? NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: appExec)
        process.environment = [
            "HYPERSYNC_APP_SUPPORT_DIR": appSupportDir.path,
            "HYPERSYNC_SKIP_LOGIN_ITEM": "1",
            "HYPERSYNC_DISABLE_ANALYTICS": "1",
            "HYPERSYNC_DISABLE_BACKGROUND_JOBS": "1"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()

        XCTAssertTrue(waitUntil(timeout: 12) { self.processExists() }, "Hypersync process should start")
        return ManagedApp(process: process, appSupportDir: appSupportDir, bundleID: bundleID)
    }

    private func processExists() -> Bool {
        let output = (try? runAppleScript("""
            tell application "System Events"
                return (exists process "\(appName)")
            end tell
            """))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return output == "true"
    }

    private func skillsWindowExists() -> Bool {
        let output = (try? runAppleScript("""
            tell application "System Events"
                if not (exists process "\(appName)") then return false
                tell process "\(appName)"
                    return (exists window "Skills")
                end tell
            end tell
            """))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return output == "true"
    }

    private func onboardingVisible() -> Bool {
        let output = (try? runAppleScript("""
            tell application "System Events"
                if not (exists process "\(appName)") then return false
                tell process "\(appName)"
                    if not (exists window "Skills") then return false
                    if (count of sheets of window "Skills") > 0 then return true
                    if exists static text "Welcome to Hypersync" of window "Skills" then return true
                    return false
                end tell
            end tell
            """))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return output == "true"
    }

    private func closeSkillsWindow() throws {
        _ = try runAppleScript("""
            tell application "System Events"
                tell process "\(appName)"
                    set frontmost to true
                    keystroke "w" using {command down}
                end tell
            end tell
            """)
    }

    private func reopenApp(bundleID: String) throws {
        _ = try runAppleScript(#"tell application id "\#(bundleID)" to reopen"#)
    }

    private func waitUntil(timeout: TimeInterval, predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return predicate()
    }

    @discardableResult
    private func runAppleScript(_ script: String) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let output = Pipe()
        task.standardOutput = output
        task.standardError = output
        try task.run()
        task.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        if task.terminationStatus != 0 {
            throw NSError(domain: "HypersyncXCUITests", code: Int(task.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "AppleScript failed: \(text)"
            ])
        }
        return text
    }
}

private struct ManagedApp {
    let process: Process
    let appSupportDir: URL
    let bundleID: String

    func terminate() {
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        try? FileManager.default.removeItem(at: appSupportDir)
    }
}
