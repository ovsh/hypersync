import ServiceManagement
import SwiftUI

// MARK: - Brand Colors

enum Brand {
    static let indigo = Color(red: 0.29, green: 0.29, blue: 0.96)       // #4A4AF4
    static let indigoDim = Color(red: 0.18, green: 0.18, blue: 0.76)    // #2F2FC1
    static let indigoMid = Color(red: 0.66, green: 0.66, blue: 0.99)    // #A8A9FC
    static let indigoLight = Color(red: 0.90, green: 0.90, blue: 0.99)  // #E6E6FC
    static let darkBg = Color(red: 0.075, green: 0.075, blue: 0.12)     // #13131F
    static let darkBgAlt = Color(red: 0.106, green: 0.106, blue: 0.19)  // #1B1B30
}

// MARK: - Visual Effect Bridge

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var draft = AppSettings.defaults()
    @State private var scanRootsText = AppSettings.defaultScanRoots.joined(separator: ", ")
    @State private var feedbackMessage = ""
    @State private var isError = false
    @State private var feedbackOpacity = 0.0

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.bottom, 20)

                        setupCard
                            .padding(.bottom, 12)

                        registryCard
                            .padding(.bottom, 12)

                        syncCard
                            .padding(.bottom, 12)

                        destinationsCard
                    }
                    .padding(24)
                }

                Divider().opacity(0.5)

                actionBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
            }
        }
        .frame(width: 520, height: 660)
        .onAppear(perform: loadFromStore)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            AppIconView(size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Hypersync")
                    .font(.system(size: 16, weight: .semibold, design: .default))

                Text("Configuration")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (label, color) = statusInfo
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var statusInfo: (String, Color) {
        switch appState.syncStatus {
        case .idle: return ("Idle", .secondary)
        case .syncing: return ("Syncing", Brand.indigo)
        case .succeeded: return ("Synced", .green)
        case .failed: return ("Failed", .red)
        }
    }

    // MARK: - Setup

    private var setupCard: some View {
        HyperCard {
            CardHeader(icon: .setup, title: "Setup")

            VStack(alignment: .leading, spacing: 5) {
                instructionRow(number: "1", text: "Enter your GitHub repo URL (HTTPS or SSH)")
                instructionRow(number: "2", text: "Ensure git credentials are configured")
                instructionRow(number: "3", text: "Run the setup check below")
            }
            .padding(.bottom, 4)

            HStack(spacing: 10) {
                Button(action: {
                    saveSettings()
                    appState.runSetupCheck()
                }) {
                    HStack(spacing: 6) {
                        if appState.isRunningSetupCheck {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.6)
                        } else {
                            HyperIconView(icon: .check, size: 12, color: .primary)
                        }
                        Text(appState.isRunningSetupCheck ? "Checking\u{2026}" : "Run Setup Check")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .disabled(appState.isRunningSetupCheck)

                if let passed = appState.setupCheckPassed {
                    HStack(spacing: 4) {
                        HyperIconView(icon: passed ? .passed : .failed, size: 14, color: passed ? .green : .red)
                        Text(passed ? "Passed" : "Failed")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(passed ? .green : .red)
                }

                Spacer()

                if let checkedAt = appState.lastSetupCheckAt {
                    Text(checkedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            if !appState.setupCheckLines.isEmpty {
                diagnosticOutput
            }
        }
    }

    private var diagnosticOutput: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(appState.setupCheckLines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\u{2022}")
                        .foregroundStyle(.tertiary)
                    Text(line)
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Registry

    private var registryCard: some View {
        HyperCard {
            CardHeader(icon: .registry, title: "Registry")

            FieldLabel("Repository URL") {
                TextField("git@github.com:org/repo.git", text: $draft.remoteGitURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            HStack(spacing: 32) {
                FieldLabel("Auth method") {
                    Text(SetupChecker.isHTTPS(draft.remoteGitURL) ? "HTTPS" : "SSH Agent")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                FieldLabel("Branch") {
                    Text("main")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Sync

    private var syncCard: some View {
        HyperCard {
            CardHeader(icon: .sync, title: "Sync")

            FieldLabel("Teams") {
                if appState.discoveredTeams.isEmpty {
                    TextField("everyone", text: $scanRootsText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    Text("Comma-separated team folders to sync")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(appState.discoveredTeams) { team in
                            let isSubscribed = scanRootsSet.contains(team.folderName)
                            let isEveryone = team.folderName == "everyone"
                            HStack(spacing: 8) {
                                Image(systemName: isSubscribed ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 13))
                                    .foregroundStyle(isSubscribed ? Brand.indigoMid : Color.secondary.opacity(0.4))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(team.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                    if !team.description.isEmpty {
                                        Text(team.description)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                if isEveryone {
                                    Text("Always synced")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard !isEveryone else { return }
                                toggleTeamSubscription(team.folderName)
                            }
                            .opacity(isEveryone ? 0.7 : 1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            FieldLabel("Local checkout") {
                TextField("~/Library/Application Support/HyperSync/registry", text: $draft.checkoutPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            Divider().opacity(0.3)

            HStack {
                Toggle(isOn: $draft.autoSyncEnabled) {
                    Text("Auto sync")
                        .font(.system(size: 12, weight: .medium))
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                Spacer()

                if draft.autoSyncEnabled {
                    HStack(spacing: 6) {
                        Text("every")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        TextField("", value: $draft.autoSyncIntervalMinutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 48)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 12, design: .monospaced))
                        Stepper("", value: $draft.autoSyncIntervalMinutes, in: 5...1440)
                            .labelsHidden()
                        Text("min")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Toggle(isOn: launchAtLoginBinding) {
                    Text("Launch at login")
                        .font(.system(size: 12, weight: .medium))
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                Spacer()
            }
        }
    }

    // MARK: - Destinations

    private var destinationsCard: some View {
        HyperCard {
            CardHeader(icon: .destinations, title: "Destinations")

            Text("Discovered skills/ and rules/ directories are merged into:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                destinationColumn(
                    header: "Skills",
                    paths: ManifestLoader.skillDestinations.map { "~/\($0)" }
                )
                destinationColumn(
                    header: "Rules",
                    paths: ManifestLoader.rulesDestinations.map { "~/\($0)" }
                )
                Spacer()
            }
        }
    }

    private func destinationColumn(header: String, paths: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(header)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.bottom, 2)

            ForEach(paths, id: \.self) { path in
                Text(path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(action: {
                saveSettings()
                appState.syncNow(trigger: "manual-settings")
            }) {
                HStack(spacing: 5) {
                    HyperIconView(icon: .refresh, size: 12, color: .white)
                    Text("Sync Now")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Brand.indigo, Brand.indigoDim],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .disabled(appState.isSyncing)
            .opacity(appState.isSyncing ? 0.6 : 1)
            .keyboardShortcut(.return, modifiers: .command)

            Button(action: saveSettings) {
                Text("Save")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            if !feedbackMessage.isEmpty {
                Text(feedbackMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isError ? .red : .green)
                    .opacity(feedbackOpacity)
            }
        }
    }

    // MARK: - Helpers

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(number)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.8))
        }
    }

    private var scanRootsSet: Set<String> {
        Set(scanRootsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    private func toggleTeamSubscription(_ folderName: String) {
        var roots = scanRootsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let idx = roots.firstIndex(of: folderName) {
            roots.remove(at: idx)
        } else {
            roots.append(folderName)
        }
        scanRootsText = roots.joined(separator: ", ")
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // Silently ignore — user can retry
                }
            }
        )
    }

    private func loadFromStore() {
        draft = appState.settingsStore.settings
        scanRootsText = draft.scanRoots.joined(separator: ", ")
        feedbackMessage = ""
        isError = false
    }

    private func saveSettings() {
        var next = draft
        next.remoteGitURL = draft.remoteGitURL.trimmed
        next.scanRoots = scanRootsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if next.scanRoots.isEmpty {
            next.scanRoots = AppSettings.defaultScanRoots
        }
        next.checkoutPath = draft.checkoutPath.trimmed

        appState.saveSettings(next)
        feedbackMessage = "Saved"
        isError = false

        withAnimation(.easeIn(duration: 0.2)) { feedbackOpacity = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.4)) { feedbackOpacity = 0.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { feedbackMessage = "" }
        }
    }
}

// MARK: - App Icon View (in-app rendering)

struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Dark base with subtle indigo sweep
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Brand.darkBgAlt, Brand.darkBg],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Indigo ambient glow at bottom
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Brand.indigo.opacity(0.18), .clear],
                        center: .bottom,
                        startRadius: size * 0.05,
                        endRadius: size * 0.6
                    )
                )

            // Inner border with indigo tint
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Brand.indigoMid.opacity(0.35), Brand.indigo.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size * 0.02
                )

            // Sync glyph
            HyperIconView(
                icon: .sync,
                size: size * 0.52,
                color: Brand.indigoMid
            )
            .shadow(color: Brand.indigo.opacity(0.7), radius: size * 0.08)
        }
        .frame(width: size, height: size)
    }
}
