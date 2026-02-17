import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Stored reference to SwiftUI's openWindow action, captured from the
    /// MenuBarExtra label (which is rendered at app launch).
    @MainActor static var openWindow: OpenWindowAction?

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

        // Skills window opening is handled by MenuBarLabel.onAppear,
        // which fires once SwiftUI has set up the scene and the
        // openWindow environment action is available.
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.showSkillsWindow()
        return true
    }

    @MainActor static func showSkillsWindow() {
        NSApp.activate(ignoringOtherApps: true)

        // 1. If the window already exists (opened before), just bring it to front.
        for window in NSApp.windows where !window.isMiniaturized {
            let id = window.identifier?.rawValue ?? ""
            if id.contains("skills") || window.title == "Skills" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }

        // 2. Window hasn't been created yet (or was fully closed) — ask SwiftUI
        //    to open it via the stored action captured from MenuBarLabel.
        openWindow?(id: "skills")
    }
}

// MARK: - Menu Bar Label

/// The MenuBarExtra label view. It is rendered immediately at app launch
/// (unlike the popover content), so its `onAppear` reliably fires during
/// startup. We use this to capture SwiftUI's `openWindow` action and to
/// trigger the initial Skills window presentation.
private struct MenuBarLabel: View {
    let iconName: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: iconName)
            .onAppear {
                AppDelegate.openWindow = openWindow
                // Open the Skills window on initial app launch.
                DispatchQueue.main.async {
                    AppDelegate.showSkillsWindow()
                }
            }
    }
}

// MARK: - App

struct HypersyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(appState)
        } label: {
            MenuBarLabel(iconName: appState.menuIconName)
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
