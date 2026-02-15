import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Kill any already-running instance before setting up
        let dominated = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != NSRunningApplication.current }
        for old in dominated {
            old.terminate()
        }

        NSApp.setActivationPolicy(.accessory)

        // Enable launch at login by default on first run
        let launchKey = "hasRegisteredLoginItem"
        if !UserDefaults.standard.bool(forKey: launchKey) {
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: launchKey)
        }

        Analytics.setup()
    }
}

struct HyperSyncMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Hypersync", systemImage: appState.menuIconName) {
            MenuView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Window("Hypersync Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)

        Window("Skills", id: "skills") {
            SkillsView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)

        Window("Hypersync Setup", id: "onboarding") {
            OnboardingView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}
