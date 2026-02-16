import AppKit
import SwiftUI

struct MenuView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header + status
            HStack(spacing: 8) {
                AppIconView(size: 20)
                Text("Hypersync")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                HStack(spacing: 5) {
                    statusIcon
                    if appState.syncStatus == .syncing {
                        Text("Syncing\u{2026}")
                    } else if let lastSyncAt = appState.lastSyncAt {
                        Text("Last synced \(lastSyncAt.formatted(date: .omitted, time: .shortened))")
                    } else {
                        Text("Never synced")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 14)

            // Error (conditional, hidden during auth setup since button subtitle handles it)
            if let error = appState.lastErrorMessage, !appState.isAwaitingAuthSetup {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                } label: {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 10)
            }

            // Setup notice (subtle, only when check actually failed — not during transient states)
            if appState.setupCheckPassed == false && !appState.isAwaitingAuthSetup {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 10))
                        Text(setupNoticeText)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.04))
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 10)
            }

            // Update banner (conditional)
            if let update = appState.updateAvailable {
                UpdateBanner(
                    version: update.version,
                    isDownloading: appState.isDownloadingUpdate,
                    error: appState.updateError
                ) {
                    appState.installUpdate()
                }
                .padding(.bottom, 10)
            }

            // Primary action — label adapts to what the user needs to do next
            SyncNowButton(
                isSyncing: appState.isSyncing,
                isAwaitingAuth: appState.isAwaitingAuthSetup,
                setupCheckFailed: appState.setupCheckPassed == false,
                hasRepo: !appState.settingsStore.settings.remoteGitURL.trimmed.isEmpty
            ) {
                if appState.settingsStore.settings.remoteGitURL.trimmed.isEmpty {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                } else {
                    appState.syncNow(trigger: "manual")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 14)

            Divider()
                .opacity(0.4)
                .padding(.bottom, 10)

            // Secondary actions
            HStack(spacing: 0) {
                SecondaryMenuButton(label: "Settings") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }
                SecondaryMenuButton(label: "Skills") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "skills")
                }
                Spacer()
                SecondaryMenuButton(label: "Quit", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: 280)
        // Onboarding trigger moved to SkillsView (the primary window)
    }

    private var setupNoticeText: String {
        "Setup issue detected \u{2014} open Settings for details"
    }

    private var statusIcon: some View {
        Group {
            switch appState.syncStatus {
            case .idle:
                Image(systemName: "clock")
                    .foregroundStyle(.tertiary)
            case .syncing:
                ProgressView()
                    .controlSize(.mini)
            case .succeeded:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.system(size: 10))
        .frame(width: 12, height: 12)
    }
}

// MARK: - Secondary Button

private struct SecondaryMenuButton: View {
    let label: String
    var role: ButtonRole?
    let action: () -> Void
    @State private var isHovered = false

    enum ButtonRole {
        case destructive
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(foregroundColor)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovered ? Color.primary.opacity(0.08) : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var foregroundColor: Color {
        if isHovered && role == .destructive {
            return .red
        }
        return .secondary
    }
}

// MARK: - Update Banner

private struct UpdateBanner: View {
    let version: String
    let isDownloading: Bool
    let error: String?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isDownloading {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Updating\u{2026}")
                        .font(.system(size: 11, weight: .medium))
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11))
                    Text("v\(version) available")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("Update")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(isHovered ? 0.25 : 0.15))
                        )
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                isHovered ? Color.teal : Color.teal.opacity(0.85),
                                Color.teal.opacity(0.7),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
        .onHover { hovering in isHovered = hovering }

        if let error {
            Text(error)
                .font(.system(size: 10))
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }
}
