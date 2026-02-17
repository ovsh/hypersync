import AppKit
import SwiftUI

@MainActor
final class WindowCoordinator {
    static let shared = WindowCoordinator()

    enum AppWindow: String, CaseIterable {
        case skills
        case settings

        var title: String {
            switch self {
            case .skills:
                return "Skills"
            case .settings:
                return "Hypersync Settings"
            }
        }
    }

    private var openWindowAction: OpenWindowAction?
    private var pendingWindows: Set<AppWindow> = []
    private var didRequestInitialSkillsPresentation = false

    private init() {}

    func register(openWindow action: OpenWindowAction) {
        openWindowAction = action
        flushPendingWindows()
    }

    func requestInitialSkillsPresentation() {
        guard !didRequestInitialSkillsPresentation else { return }
        didRequestInitialSkillsPresentation = true
        showSkillsWindow()
    }

    func handleDockReopen(hasVisibleWindows: Bool) {
        guard !hasVisibleWindows else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        showSkillsWindow()
    }

    func showSkillsWindow() {
        show(.skills, activate: true)
    }

    func showSettingsWindow() {
        show(.settings, activate: true)
    }

    private func show(_ target: AppWindow, activate: Bool) {
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }

        if let existingWindow = existingWindow(for: target) {
            if existingWindow.isMiniaturized {
                existingWindow.deminiaturize(nil)
            }
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        guard let openWindowAction else {
            pendingWindows.insert(target)
            return
        }

        openWindowAction(id: target.rawValue)
    }

    private func flushPendingWindows() {
        guard let openWindowAction else { return }
        let queued = pendingWindows
        pendingWindows.removeAll()

        for target in AppWindow.allCases where queued.contains(target) {
            openWindowAction(id: target.rawValue)
        }
    }

    private func existingWindow(for target: AppWindow) -> NSWindow? {
        for window in NSApp.windows {
            let identifier = window.identifier?.rawValue ?? ""
            if identifier.contains(target.rawValue) || window.title == target.title {
                return window
            }
        }
        return nil
    }
}
