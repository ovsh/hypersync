import AppKit
import ServiceManagement
import SwiftUI

extension Notification.Name {
    static let openSkillsWindow = Notification.Name("openSkillsWindow")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Kill any already-running instance before setting up
        let dominated = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != NSRunningApplication.current }
        for old in dominated {
            old.terminate()
        }

        NSApp.setActivationPolicy(.regular)

        // Enable launch at login by default on first run
        let launchKey = "hasRegisteredLoginItem"
        if !UserDefaults.standard.bool(forKey: launchKey) {
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: launchKey)
        }

        Analytics.setup()

        // Open Skills window on launch
        DispatchQueue.main.async {
            Self.showSkillsWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Self.showSkillsWindow()
        }
        return true
    }

    @MainActor static func showSkillsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // SwiftUI Window scenes keep their NSWindow around even when closed
        if let win = NSApp.windows.first(where: { $0.title == "Skills" }) {
            win.makeKeyAndOrderFront(nil)
        } else {
            // Fallback: post notification for SwiftUI layer to call openWindow
            NotificationCenter.default.post(name: .openSkillsWindow, object: nil)
        }
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

        Window("Skills", id: "skills") {
            SkillsView()
                .environmentObject(appState)
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)

        Window("Hypersync Settings", id: "settings") {
            SettingsView()
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
