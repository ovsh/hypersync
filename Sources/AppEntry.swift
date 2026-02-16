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

        // Set dock icon from bundled PNG
        if let iconData = IconGenerator.renderAppIconPNG(),
           let iconImage = NSImage(data: iconData) {
            NSApp.applicationIconImage = iconImage
        }

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
        Self.showSkillsWindow()
        return true
    }

    @MainActor static func showSkillsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Let SwiftUI handle window lifecycle via openWindow(id:) in MenuView
        NotificationCenter.default.post(name: .openSkillsWindow, object: nil)
    }
}

struct HypersyncApp: App {
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
        .defaultSize(width: 960, height: 640)
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
