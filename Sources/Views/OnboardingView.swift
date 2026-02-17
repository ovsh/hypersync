import SwiftUI

// MARK: - Shared button used across all steps

private struct WizardButton: View {
    let label: String
    var style: Style = .primary
    let action: () -> Void
    @State private var isHovered = false

    enum Style { case primary, secondary }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(style == .primary ? .white : .secondary)
                .frame(width: 220, height: 44)
                .background(
                    Group {
                        if style == .primary {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            isHovered ? Brand.indigoDim : Brand.indigo,
                                            Brand.indigoDim,
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(isHovered ? 0.08 : 0.04))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Root

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Group {
                    switch currentStep {
                    case 0: WelcomeStep { advance() }
                    case 1: GitHubConnectStep { advance() }
                    case 2: ChooseRepoStep { advance() }
                    case 3: FirstSyncStep()
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeInOut(duration: 0.25)),
                    removal: .opacity.animation(.easeInOut(duration: 0.15))
                ))
                .id(currentStep)

                Spacer(minLength: 0)

                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<4) { i in
                        Circle()
                            .fill(i == currentStep ? Brand.indigo : Color.primary.opacity(0.12))
                            .frame(width: 7, height: 7)
                            .scaleEffect(i == currentStep ? 1.0 : 0.85)
                            .animation(.easeOut(duration: 0.2), value: currentStep)
                    }
                }
                .padding(.bottom, 28)
            }

            Button(action: closeOnboarding) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.07))
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("Close onboarding")
            .padding(.top, 14)
            .padding(.trailing, 14)
        }
        .frame(width: 540, height: 500)
        .onAppear {
            appState.beginOnboarding()
            Analytics.track(.onboardingStepViewed(step: 0, stepName: "welcome"))
        }
        .onDisappear {
            appState.deferOnboardingIfNeeded()
        }
    }

    private static let stepNames = ["welcome", "github_connect", "choose_repo", "first_sync"]

    private func advance() {
        withAnimation { currentStep += 1 }
        let nextStep = currentStep
        if nextStep < Self.stepNames.count {
            Analytics.track(.onboardingStepViewed(step: nextStep, stepName: Self.stepNames[nextStep]))
        }
    }

    private func closeOnboarding() {
        Analytics.track(.onboardingSkipped)
        appState.deferOnboardingIfNeeded()
        dismiss()
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppIconView(size: 72)
                .padding(.bottom, 24)

            Text("Welcome to Hypersync")
                .font(.system(size: 26, weight: .bold))
                .padding(.bottom, 8)

            Text("Keep your team's AI tools in sync,\nautomatically.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.bottom, 40)

            WizardButton(label: "Get Started", action: onContinue)
        }
    }
}

// MARK: - Step 2: GitHub Connect

private struct GitHubConnectStep: View {
    let onContinue: () -> Void
    @EnvironmentObject var appState: AppState

    private enum GHState: Equatable {
        case checking, needsInstall, waitingForInstall, needsAuth, waitingForAuth, connected
    }

    @State private var ghState: GHState = .checking
    @State private var username: String?
    @State private var pollTimer: Timer?

    private let ghCLI = GitHubCLI()

    private var isWaiting: Bool {
        ghState == .checking || ghState == .waitingForInstall || ghState == .waitingForAuth
    }

    var body: some View {
        VStack(spacing: 0) {
            // Icon area
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 80, height: 80)

                Group {
                    if isWaiting {
                        ProgressView()
                            .controlSize(.regular)
                    } else if ghState == .connected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: ghState)
            .padding(.bottom, 24)

            // Title
            Text(titleText)
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 8)
                .animation(.none, value: ghState)

            // Subtitle
            Text(subtitleText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(width: 360)
                .padding(.bottom, 36)
                .animation(.none, value: ghState)

            // Action
            Group {
                switch ghState {
                case .checking:
                    EmptyView()
                case .needsInstall:
                    WizardButton(label: "Install GitHub CLI") {
                        Analytics.track(.onboardingGHInstallStarted)
                        ghState = .waitingForInstall
                        appState.openTerminalWithCommand("brew install gh")
                        startPolling()
                    }
                case .waitingForInstall:
                    terminalHint
                case .needsAuth:
                    WizardButton(label: "Sign in to GitHub") {
                        Analytics.track(.onboardingGHAuthStarted)
                        ghState = .waitingForAuth
                        appState.openTerminalWithCommand("gh auth login --web -p https && gh auth setup-git")
                        startPolling()
                    }
                case .waitingForAuth:
                    terminalHint
                case .connected:
                    WizardButton(label: "Continue", action: onContinue)
                }
            }
        }
        .onAppear(perform: checkStatus)
        .onDisappear { pollTimer?.invalidate() }
    }

    /// Hint shown while waiting for the user to complete an action in Terminal
    private var terminalHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Switched to Terminal \u{2014} come back when it\u{2019}s done")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Display

    private var iconBackground: Color {
        switch ghState {
        case .connected: return .green
        case .waitingForInstall, .waitingForAuth: return Brand.indigo.opacity(0.12)
        default: return Color.primary.opacity(0.05)
        }
    }

    private var titleText: String {
        switch ghState {
        case .checking: return "Checking\u{2026}"
        case .needsInstall: return "One Quick Install"
        case .waitingForInstall: return "Installing\u{2026}"
        case .needsAuth: return "Sign in to GitHub"
        case .waitingForAuth: return "Waiting for Sign-in\u{2026}"
        case .connected:
            if let username { return "Hi, @\(username)" }
            return "Connected"
        }
    }

    private var subtitleText: String {
        switch ghState {
        case .checking:
            return "Checking your GitHub setup"
        case .needsInstall:
            return "Hypersync uses the GitHub CLI to sync your team\u{2019}s config. This will open Terminal to install it."
        case .waitingForInstall:
            return "Installing GitHub CLI in Terminal. This window will update automatically when it\u{2019}s done."
        case .needsAuth:
            return "This will open Terminal to securely connect your GitHub account."
        case .waitingForAuth:
            return "Complete the sign-in in Terminal. This window will update automatically."
        case .connected:
            return "Your GitHub account is connected and ready to go."
        }
    }

    // MARK: - Logic

    private func checkStatus() {
        DispatchQueue.global(qos: .userInitiated).async {
            let installed = ghCLI.isInstalled()
            let authed = installed ? ghCLI.isAuthenticated() : false
            let user = authed ? ghCLI.currentUser() : nil

            DispatchQueue.main.async {
                username = user
                if !installed {
                    ghState = .needsInstall
                } else if !authed {
                    ghState = .needsAuth
                } else {
                    ghState = .connected
                }
            }
        }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            DispatchQueue.global(qos: .userInitiated).async {
                let installed = ghCLI.isInstalled()
                guard installed else { return }
                let authed = ghCLI.isAuthenticated()
                guard authed else {
                    DispatchQueue.main.async {
                        if ghState == .needsInstall || ghState == .waitingForInstall {
                            Analytics.track(.onboardingGHInstallCompleted)
                            ghState = .needsAuth
                        }
                    }
                    return
                }
                let user = ghCLI.currentUser()
                DispatchQueue.main.async {
                    Analytics.track(.onboardingGHAuthCompleted(hasUsername: user != nil))
                    username = user
                    ghState = .connected
                    pollTimer?.invalidate()
                    pollTimer = nil
                }
            }
        }
    }
}

// MARK: - Step 3: Choose Repo

private struct ChooseRepoStep: View {
    let onContinue: () -> Void
    @EnvironmentObject var appState: AppState

    @State private var showExisting = false
    @State private var repoName = "ai-config"
    @State private var existingURL = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var repoAlreadyExists = false

    @State private var selectedOwner = ""
    @State private var owners: [String] = []

    private let ghCLI = GitHubCLI()

    var body: some View {
        VStack(spacing: 0) {
            if showExisting {
                existingFlow
            } else {
                createFlow
            }
        }
        .onAppear(perform: loadOwners)
    }

    // MARK: - Primary path: Create

    private var createFlow: some View {
        VStack(spacing: 0) {
            HyperIconView(icon: .registry, size: 34, color: Brand.indigo)
                .padding(.bottom, 20)

            Text("Create Your AI Config")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 8)

            Text("We\u{2019}ll set up a shared space on GitHub\nwith starter rules and skills for your team.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.bottom, 32)

            // Name input
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.3)

                HStack(spacing: 8) {
                    if owners.count > 1 {
                        Picker("", selection: $selectedOwner) {
                            ForEach(owners, id: \.self) { org in
                                Text(org).tag(org)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)

                        Text("/")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }

                    TextField("ai-config", text: $repoName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 24)

            if repoAlreadyExists {
                // Repo exists — offer to use it instead of dead-ending
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                        Text("\(selectedOwner)/\(repoName.trimmed) already exists")
                            .font(.system(size: 13, weight: .medium))
                    }

                    WizardButton(label: "Use It") {
                        let url = "https://github.com/\(selectedOwner)/\(repoName.trimmed).git"
                        saveAndContinue(url: url)
                    }
                    .padding(.bottom, 4)

                    Button(action: {
                        repoAlreadyExists = false
                        repoName = ""
                    }) {
                        Text("Try a different name")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(width: 340)
                        .padding(.bottom, 12)
                }

                WizardButton(
                    label: isWorking ? "Setting up\u{2026}" : "Continue"
                ) { createRepo() }
                .disabled(isWorking || repoName.trimmed.isEmpty)
                .opacity(isWorking || repoName.trimmed.isEmpty ? 0.5 : 1)
                .padding(.bottom, 20)

                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showExisting = true
                        errorMessage = nil
                    }
                }) {
                    Text("My team already set one up")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Secondary path: Existing

    private var existingFlow: some View {
        VStack(spacing: 0) {
            Image(systemName: "link")
                .font(.system(size: 32))
                .foregroundStyle(Brand.indigo)
                .padding(.bottom, 20)

            Text("Connect Your Team\u{2019}s Config")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 8)

            Text("Paste the GitHub link your team shared with you.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 6) {
                Text("GitHub link")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.3)

                TextField("https://github.com/your-team/ai-config", text: $existingURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 24)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(width: 340)
                    .padding(.bottom, 12)
            }

            WizardButton(
                label: isWorking ? "Connecting\u{2026}" : "Continue"
            ) { validateExisting() }
            .disabled(isWorking || existingURL.trimmed.isEmpty)
            .opacity(isWorking || existingURL.trimmed.isEmpty ? 0.5 : 1)
            .padding(.bottom, 20)

            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) {
                    showExisting = false
                    errorMessage = nil
                }
            }) {
                Text("Start fresh instead")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func loadOwners() {
        DispatchQueue.global(qos: .userInitiated).async {
            let user = ghCLI.currentUser() ?? ""
            let orgs = ghCLI.userOrgs()
            DispatchQueue.main.async {
                var all = [String]()
                if !user.isEmpty { all.append(user) }
                all.append(contentsOf: orgs.filter { $0 != user })
                owners = all
                if selectedOwner.isEmpty { selectedOwner = all.first ?? "" }
            }
        }
    }

    private func createRepo() {
        isWorking = true
        errorMessage = nil
        repoAlreadyExists = false
        let owner = selectedOwner
        let name = repoName.trimmed

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = try ghCLI.createRepoFromTemplate(
                    owner: owner, name: name,
                    template: "ovsh/hypersync-template",
                    isPrivate: true
                )
                DispatchQueue.main.async {
                    isWorking = false
                    Analytics.track(.onboardingRepoCreated)
                    saveAndContinue(url: url)
                }
            } catch let error as GitHubCLIError {
                DispatchQueue.main.async {
                    isWorking = false
                    let msg = error.localizedDescription
                    if msg.contains("already exists") {
                        repoAlreadyExists = true
                    } else {
                        errorMessage = msg
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isWorking = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func validateExisting() {
        isWorking = true
        errorMessage = nil
        let url = existingURL.trimmed

        DispatchQueue.global(qos: .userInitiated).async {
            let result = SetupChecker().run(remoteGitURL: url)
            DispatchQueue.main.async {
                isWorking = false
                if result.passed {
                    Analytics.track(.onboardingRepoConnected)
                    saveAndContinue(url: url)
                } else {
                    let summary = result.lines.last ?? "Couldn\u{2019}t connect. Check the link and try again."
                    errorMessage = summary
                }
            }
        }
    }

    private func saveAndContinue(url: String) {
        var settings = appState.settingsStore.settings
        settings.remoteGitURL = url
        appState.saveSettings(settings)
        onContinue()
    }
}

// MARK: - Step 4: First Sync

private struct FirstSyncStep: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var didSync = false

    private var succeeded: Bool { appState.syncStatus == .succeeded && didSync }

    var body: some View {
        VStack(spacing: 0) {
            // Hero icon
            ZStack {
                Circle()
                    .fill(succeeded ? Color.green : Brand.indigo.opacity(0.1))
                    .frame(width: 80, height: 80)

                if appState.isSyncing {
                    ProgressView()
                        .controlSize(.regular)
                } else if succeeded {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white)
                } else {
                    HyperIconView(icon: .sync, size: 34, color: Brand.indigo)
                }
            }
            .padding(.bottom, 24)

            Text(succeeded ? "You\u{2019}re all set!" : appState.isSyncing ? "Syncing\u{2026}" : "Ready to Sync")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 8)

            Text(subtitleText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(width: 340)
                .padding(.bottom, 20)

            // Destinations — show where skills/rules will land
            if !succeeded {
                destinationsList
                    .padding(.bottom, 24)
            }

            if appState.syncStatus == .failed && didSync {
                if let error = appState.lastErrorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(width: 340)
                        .padding(.bottom, 16)
                }

                WizardButton(label: "Try Again") {
                    appState.syncNow(trigger: "onboarding")
                }
            } else if succeeded {
                WizardButton(label: "Done", action: finish)
            } else if !appState.isSyncing {
                VStack(spacing: 12) {
                    WizardButton(label: "Sync Now") {
                        didSync = true
                        appState.syncNow(trigger: "onboarding")
                    }

                    Button(action: {
                        Analytics.track(.onboardingSkipped)
                        finish()
                    }) {
                        Text("I\u{2019}ll do this later")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var destinationsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Installs to")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(destinations, id: \.self) { path in
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 300, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private var destinations: [String] {
        // Collect tool prefixes and what they receive
        var toolContent: [(prefix: String, label: String)] = []
        let skillPrefixes = Set(ManifestLoader.skillDestinations.map { $0.components(separatedBy: "/").first! })
        let rulesPrefixes = Set(ManifestLoader.rulesDestinations.map { $0.components(separatedBy: "/").first! })
        let allPrefixes = Array(skillPrefixes.union(rulesPrefixes)).sorted()

        for prefix in allPrefixes {
            let hasSkills = skillPrefixes.contains(prefix)
            let hasRules = rulesPrefixes.contains(prefix)
            let suffix = hasSkills && hasRules ? "skills & rules"
                       : hasSkills ? "skills"
                       : "rules"
            toolContent.append((prefix, "~/\(prefix)/\(suffix)"))
        }
        return toolContent.map(\.label)
    }

    private var subtitleText: String {
        if succeeded {
            return "Your AI tools are configured and syncing. Hypersync will keep everything up to date."
        }
        if appState.isSyncing {
            return "Setting up your rules and skills\u{2026}"
        }
        if appState.syncStatus == .failed && didSync {
            return "Something went wrong, but you can try again."
        }
        return "Hypersync will pull your team\u{2019}s shared rules and skills and install them for Cursor, Claude, Codex, and more."
    }

    private func finish() {
        appState.completeOnboarding()
        dismiss()
    }
}
