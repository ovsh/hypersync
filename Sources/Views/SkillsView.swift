import MarkdownUI
import SwiftUI

// MARK: - Skill Category

enum SkillCategory: String {
    case team = "Team"
    case local = "Local"
    case playground = "Playground"
}

// MARK: - Team Skill Group

struct TeamSkillGroup: Identifiable {
    let teamName: String
    let displayName: String
    let officialSkills: [SkillInfo]
    let playgroundSkills: [SkillInfo]
    var id: String { teamName }
}

// MARK: - Sidebar Selection

enum SidebarSelection: Hashable {
    case space(String)  // "team", "local"
    case skill(String)  // skill id
}

// MARK: - Skills View

struct SkillsView: View {
    @EnvironmentObject var appState: AppState
    @State private var teamGroups: [TeamSkillGroup] = []
    @State private var localSkills: [SkillInfo] = []
    @State private var legacyPlaygroundSkills: [SkillInfo] = []
    @State private var sortedTeamSkills: [SkillInfo] = []
    @State private var sortedPlaygroundSkills: [SkillInfo] = []
    @State private var selection: SidebarSelection?
    @State private var searchText: String = ""
    @State private var pushMessage: String? = nil
    @State private var syncMessage: String? = nil
    @State private var isSyncing = false
    @State private var enabledPlaygroundSkills: Set<String> = []
    @State private var debounceTask: DispatchWorkItem? = nil
    @State private var skillToDelete: SkillInfo? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var showCreateTeam = false
    @State private var newTeamName = ""
    @State private var isCreatingTeam = false
    @State private var skillToPush: SkillInfo? = nil
    @State private var showNewSkillSheet = false
    @State private var newSkillName = ""
    @State private var isOnboardingPresented = false
    @State private var hasEvaluatedInitialOnboarding = false
    @State private var handledOnboardingRequestID = 0

    // MARK: - Derived State

    private var teamSkillCount: Int {
        teamGroups.reduce(0) { $0 + $1.officialSkills.count + $1.playgroundSkills.count } + legacyPlaygroundSkills.count
    }

    private var subscribedTeams: [TeamInfo] {
        let roots = Set(appState.settingsStore.settings.scanRoots)
        return appState.discoveredTeams.filter { roots.contains($0.folderName) }
    }

    /// Find a skill by ID across all groups, returning the skill + its category + optional team name
    private func findSkill(_ id: String) -> (SkillInfo, SkillCategory, String?)? {
        for group in teamGroups {
            if let s = group.officialSkills.first(where: { $0.id == id }) {
                return (s, .team, group.teamName)
            }
            // Check by bare dirName or qualified "team/dirName" (used by playground tags)
            if let s = group.playgroundSkills.first(where: { $0.id == id }) {
                return (s, .playground, group.teamName)
            }
            if let s = group.playgroundSkills.first(where: { "\(group.teamName)/\($0.dirName)" == id }) {
                return (s, .playground, group.teamName)
            }
        }
        if let s = localSkills.first(where: { $0.id == id }) { return (s, .local, nil) }
        if let s = legacyPlaygroundSkills.first(where: { $0.id == id }) { return (s, .playground, nil) }
        return nil
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SkillsSidebarView(
                selection: $selection,
                searchText: $searchText,
                teamGroups: teamGroups,
                sortedTeamSkills: sortedTeamSkills,
                sortedPlaygroundSkills: sortedPlaygroundSkills,
                localSkills: localSkills,
                legacyPlaygroundSkills: legacyPlaygroundSkills,
                teamSkillCount: teamSkillCount,
                enabledPlaygroundSkills: enabledPlaygroundSkills,
                isSyncing: isSyncing,
                appIsSyncing: appState.isSyncing,
                onSync: syncPlaygroundSkills,
                onSyncNow: handleSyncNowAction,
                onNewSkill: { showNewSkillSheet = true },
                onNewTeam: { showCreateTeam = true }
            )
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 720, idealWidth: 960, minHeight: 480, idealHeight: 640)
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                if let msg = pushMessage {
                    messageBanner(msg)
                }
                if let msg = syncMessage {
                    messageBanner(msg)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: pushMessage)
            .animation(.easeInOut(duration: 0.2), value: syncMessage)
        }
        .alert(
            "Delete Skill",
            isPresented: Binding(
                get: { skillToDelete != nil },
                set: { if !$0 { skillToDelete = nil } }
            ),
            presenting: skillToDelete
        ) { skill in
            Button("Cancel", role: .cancel) { skillToDelete = nil }
            Button("Delete", role: .destructive) {
                deleteLocalSkill(skill)
                if case .skill(let id) = selection, id == skill.id { selection = nil }
            }
        } message: { skill in
            Text("Remove \"\(skill.name)\" from all agent tool directories? This can\u{2019}t be undone.")
        }
        .sheet(isPresented: $showCreateTeam) { createTeamSheet }
        .sheet(isPresented: $showNewSkillSheet) { newSkillSheet }
        .sheet(isPresented: $isOnboardingPresented, onDismiss: {
            appState.deferOnboardingIfNeeded()
        }) {
            OnboardingView()
                .environmentObject(appState)
        }
        .confirmationDialog(
            "Push to which team\u{2019}s playground?",
            isPresented: Binding(
                get: { skillToPush != nil },
                set: { if !$0 { skillToPush = nil } }
            ),
            presenting: skillToPush
        ) { skill in
            ForEach(subscribedTeams) { team in
                Button(team.displayName) {
                    pushToPlayground(skill: skill, teamFolder: team.folderName)
                }
            }
            Button("Cancel", role: .cancel) { skillToPush = nil }
        }
        .onAppear {
            loadSkills()
            enabledPlaygroundSkills = Set(appState.settingsStore.settings.enabledCommunitySkills)

            handleOnboardingPresentationRequest()

            if !hasEvaluatedInitialOnboarding {
                hasEvaluatedInitialOnboarding = true
                presentOnboardingIfNeeded()
            }
        }
        .onChange(of: appState.onboardingPresentationRequestID) { _, _ in
            handleOnboardingPresentationRequest()
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .skill(let id):
            if let (skill, category, teamName) = findSkill(id) {
                SkillDetailView(
                    skill: skill,
                    category: category,
                    teamName: teamName,
                    isSyncing: isSyncing,
                    columnVisibility: columnVisibility,
                    enabledPlaygroundSkills: $enabledPlaygroundSkills,
                    onDelete: { skillToDelete = $0 },
                    onPush: { beginPushToPlayground(skill: $0) },
                    onSync: syncPlaygroundSkills,
                    onTogglePlayground: togglePlaygroundSkill,
                    onReload: loadSkills
                )
            } else {
                placeholder
            }
        case .space(let name):
            spaceDetailView(name)
        case nil:
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 32) {
            // App branding
            VStack(spacing: 8) {
                AppIconView(size: 56)
                Text("Hypersync")
                    .font(.system(size: 18, weight: .semibold))
                Text("Choose a space to explore")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            // Big navigation cards
            HStack(spacing: 16) {
                // Team card
                Button {
                    selection = .space("team")
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Brand.indigo)
                        Text("Team")
                            .font(.system(size: 15, weight: .semibold))
                        Text("\(teamSkillCount) skills")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 140, height: 130)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.quaternary.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.quaternary.opacity(0.6), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Local card
                Button {
                    selection = .space("local")
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 24))
                            .foregroundStyle(Brand.indigo)
                        Text("Local")
                            .font(.system(size: 15, weight: .semibold))
                        Text("\(localSkills.count) skills")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 140, height: 130)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.quaternary.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.quaternary.opacity(0.6), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Surface.content)
        .toolbarBackground(.hidden, for: .automatic)
        .ignoresSafeArea(.container, edges: .top)
    }

    // MARK: - Space Detail (skill list for a space)

    @ViewBuilder
    private func spaceDetailView(_ spaceName: String) -> some View {
        let isTeam = spaceName == "team"
        let skills = isTeam ? sortedTeamSkills : localSkills
        let playgroundSkills = isTeam ? sortedPlaygroundSkills : []

        Group {
            if skills.isEmpty && playgroundSkills.isEmpty {
                // Hero empty state — centered in full pane
                VStack(spacing: Space.xl) {
                    Image(systemName: isTeam ? "person.3" : "laptopcomputer")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)

                    VStack(spacing: Space.sm) {
                        Text(isTeam ? "Team Skills" : "Local Skills")
                            .font(.system(size: 20, weight: .semibold))
                        Text(isTeam
                             ? "Your team skills will appear here after syncing."
                             : "Create a skill to get started.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        if isTeam {
                            handleSyncNowAction()
                        } else {
                            showNewSkillSheet = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isTeam ? "arrow.triangle.2.circlepath" : "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text(isTeam ? "Sync Team" : "Create Skill")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .fill(
                                    LinearGradient(
                                        colors: [Brand.indigo, Brand.indigoDim],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Skill list with header
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text(isTeam ? "Team Skills" : "Local Skills")
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                                let count = isTeam ? teamSkillCount : localSkills.count
                                Text("\(count)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.quaternary.opacity(0.5))
                                    .clipShape(Capsule())
                            }

                            VStack(spacing: 2) {
                                ForEach(skills) { skill in
                                    spaceDetailSkillCard(skill)
                                }
                            }

                            if !playgroundSkills.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("PLAYGROUND")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                        .tracking(0.5)

                                    VStack(spacing: 2) {
                                        ForEach(playgroundSkills) { skill in
                                            spaceDetailSkillCard(skill)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.leading, columnVisibility == .detailOnly ? 80 : 24)
                        .padding(.trailing, 24)
                        .padding(.vertical, 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(Surface.content)
        .toolbarBackground(.hidden, for: .automatic)
        .ignoresSafeArea(.container, edges: .top)
    }

    private func spaceDetailSkillCard(_ skill: SkillInfo) -> some View {
        Button {
            selection = .skill(skill.id)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.system(size: 13, weight: .medium))
                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }

    private func presentOnboardingIfNeeded() {
        guard appState.requiresOnboarding else { return }
        appState.requestOnboardingPresentation()
        handleOnboardingPresentationRequest()
    }

    private func handleSyncNowAction() {
        switch appState.manualSyncAction {
        case .onboarding:
            appState.requestOnboardingPresentation()
            handleOnboardingPresentationRequest()
        case .settings:
            WindowCoordinator.shared.showSettingsWindow()
        case .sync:
            appState.syncNow(trigger: "manual")
        }
    }

    private func handleOnboardingPresentationRequest() {
        let requestID = appState.onboardingPresentationRequestID
        guard requestID > handledOnboardingRequestID else { return }
        handledOnboardingRequestID = requestID
        isOnboardingPresented = true
    }

    // MARK: - Message Banner

    private func messageBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Brand.indigo, Brand.indigoDim],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Create Team Sheet

    private var createTeamSheet: some View {
        VStack(spacing: 16) {
            Text("Create Team")
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Team name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("e.g. engineering", text: $newTeamName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                Text("Lowercase letters, numbers, and hyphens only")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                Button("Cancel") {
                    newTeamName = ""
                    showCreateTeam = false
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(action: createTeam) {
                    HStack(spacing: 5) {
                        if isCreatingTeam {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.6)
                        }
                        Text(isCreatingTeam ? "Creating\u{2026}" : "Create")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Brand.indigo, Brand.indigoDim],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .disabled(isCreatingTeam || !isValidTeamName(newTeamName))
                .opacity(isCreatingTeam || !isValidTeamName(newTeamName) ? 0.5 : 1)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    // MARK: - Playground Skill Toggle

    private func togglePlaygroundSkill(_ qualifiedName: String) {
        let enabling = !enabledPlaygroundSkills.contains(qualifiedName)
        if enabling {
            enabledPlaygroundSkills.insert(qualifiedName)
        } else {
            enabledPlaygroundSkills.remove(qualifiedName)
        }
        Analytics.track(.communitySkillToggled(skill: qualifiedName, enabled: enabling))
        debounceSavePlaygroundSkills()
    }

    private func debounceSavePlaygroundSkills() {
        debounceTask?.cancel()
        let snapshot = enabledPlaygroundSkills
        let task = DispatchWorkItem { [snapshot] in
            var updated = appState.settingsStore.settings
            updated.enabledCommunitySkills = Array(snapshot)
            appState.settingsStore.replace(with: updated)
        }
        debounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    // MARK: - New Skill Sheet

    private var newSkillSheet: some View {
        VStack(spacing: 16) {
            Text("New Skill")
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Skill name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("e.g. code-review", text: $newSkillName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                Text("Lowercase letters, numbers, and hyphens only")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                Button("Cancel") {
                    newSkillName = ""
                    showNewSkillSheet = false
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button {
                    let name = newSkillName.trimmingCharacters(in: .whitespaces)
                    createLocalSkillWithName(name)
                    newSkillName = ""
                    showNewSkillSheet = false
                } label: {
                    Text("Create")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Brand.indigo, Brand.indigoDim],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .disabled(!isValidTeamName(newSkillName))
                .opacity(!isValidTeamName(newSkillName) ? 0.5 : 1)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    // MARK: - Create Starter / Local Skill

    private func createStarterSkill() {
        createLocalSkillWithName("my-first-skill")
    }

    private func createLocalSkillWithName(_ name: String) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let skillDir = "\(home)/.claude/skills/\(name)"
        let fm = FileManager.default

        // Don't overwrite existing
        guard !fm.fileExists(atPath: skillDir) else {
            loadSkills()
            selection = .skill(name)
            return
        }

        try? fm.createDirectory(atPath: skillDir, withIntermediateDirectories: true)

        let displayName = name.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
        let template = """
        ---
        name: "\(displayName)"
        description: "Describe what this skill does"
        ---

        # \(displayName)

        Instructions for your AI assistant go here.

        You can describe:
        - What the skill does
        - When to use it
        - Any rules or constraints
        """

        try? template.write(toFile: "\(skillDir)/SKILL.md", atomically: true, encoding: .utf8)

        // Sync to all destinations
        for dest in ManifestLoader.skillDestinations {
            let destDir = "\(home)/\(dest)/\(name)"
            if dest != ".claude/skills" {
                Self.mergeDirectoryContents(from: skillDir, to: destDir)
            }
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            loadSkills()
        }
        selection = .skill(name)
    }

    // MARK: - Helpers

    private func isValidTeamName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let allowed = CharacterSet.lowercaseLetters.union(.decimalDigits).union(CharacterSet(charactersIn: "-"))
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    // MARK: - Push to Playground

    private func beginPushToPlayground(skill: SkillInfo) {
        let teams = subscribedTeams
        if teams.count == 1 {
            pushToPlayground(skill: skill, teamFolder: teams[0].folderName)
        } else if teams.count > 1 {
            skillToPush = skill
        } else {
            pushMessage = "No teams found. Run sync first."
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { pushMessage = nil }
        }
    }

    private func pushToPlayground(skill: SkillInfo, teamFolder: String) {
        let settings = appState.settingsStore.settings
        let checkoutPath = settings.checkoutPath.expandingTildePath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let sourcePath = "\(home)/.claude/skills/\(skill.dirName)"
        let playgroundDest = "\(checkoutPath)/\(teamFolder)/playground/skills/\(skill.dirName)"

        let fm = FileManager.default
        let isUpdate = fm.fileExists(atPath: playgroundDest)
        let verb = isUpdate ? "Update" : "Add"
        let branchName = "playground/\(teamFolder)/\(skill.dirName)"

        DispatchQueue.global(qos: .userInitiated).async {
            let _ = Self.runGit(["checkout", branchName], in: checkoutPath)
            if !FileManager.default.fileExists(atPath: "\(checkoutPath)/.git/refs/heads/\(branchName)") {
                let _ = Self.runGit(["checkout", "-b", branchName], in: checkoutPath)
            }

            // Ensure parent directory exists
            let parentDir = "\(checkoutPath)/\(teamFolder)/playground/skills"
            try? FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)

            Self.mergeDirectoryContents(from: sourcePath, to: playgroundDest)

            let _ = Self.runGit(["add", "\(teamFolder)/playground/skills/\(skill.dirName)/"], in: checkoutPath)
            let _ = Self.runGit(["commit", "-m", "\(verb) \(skill.dirName) in \(teamFolder) playground"], in: checkoutPath)
            let pushResult = Self.runGit(["push", "-u", "origin", branchName], in: checkoutPath)

            let _ = Self.runGit(["checkout", "main"], in: checkoutPath)

            DispatchQueue.main.async {
                if pushResult.success {
                    Analytics.track(.skillPushedToCommunity(skill: skill.dirName, isUpdate: isUpdate))
                    pushMessage = "\(verb)d \(skill.dirName) in \(teamFolder) playground"
                } else {
                    pushMessage = "Push failed: \(pushResult.output.prefix(120))"
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    pushMessage = nil
                }
            }
        }
    }

    // MARK: - Sync Playground Skills

    private func syncPlaygroundSkills() {
        guard !isSyncing else { return }
        isSyncing = true

        let settings = appState.settingsStore.settings
        let checkoutPath = settings.checkoutPath.expandingTildePath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let enabled = Array(enabledPlaygroundSkills)

        DispatchQueue.global(qos: .userInitiated).async {
            var synced = 0
            for qualifiedName in enabled {
                let source: String
                let skillName: String

                if qualifiedName.contains("/") {
                    // Per-team playground: "engineering/my-skill"
                    let parts = qualifiedName.split(separator: "/", maxSplits: 1)
                    let team = String(parts[0])
                    skillName = String(parts[1])
                    source = "\(checkoutPath)/\(team)/playground/skills/\(skillName)"
                } else {
                    // Legacy community-playground
                    skillName = qualifiedName
                    source = "\(checkoutPath)/community-playground/\(qualifiedName)"
                }

                guard FileManager.default.fileExists(atPath: source) else { continue }

                for destPrefix in ManifestLoader.skillDestinations {
                    let dest = "\(home)/\(destPrefix)/\(skillName)"
                    Self.mergeDirectoryContents(from: source, to: dest)
                }
                synced += 1
            }

            DispatchQueue.main.async {
                isSyncing = false
                syncMessage = "Synced \(synced) playground skill\(synced == 1 ? "" : "s")"
                Analytics.track(.communitySkillsSynced(count: synced))
                loadSkills()

                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    syncMessage = nil
                }
            }
        }
    }

    // MARK: - Create Team

    private func createTeam() {
        let name = newTeamName.trimmingCharacters(in: .whitespaces)
        guard isValidTeamName(name) else { return }
        isCreatingTeam = true

        let settings = appState.settingsStore.settings
        let checkoutPath = settings.checkoutPath.expandingTildePath
        let branchName = "team/\(name)"

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default

            let skillsDir = "\(checkoutPath)/\(name)/skills"
            let rulesDir = "\(checkoutPath)/\(name)/rules"
            let playgroundDir = "\(checkoutPath)/\(name)/playground/skills"

            try? fm.createDirectory(atPath: skillsDir, withIntermediateDirectories: true)
            try? fm.createDirectory(atPath: rulesDir, withIntermediateDirectories: true)
            try? fm.createDirectory(atPath: playgroundDir, withIntermediateDirectories: true)

            let readmeContent = "# \(name.capitalized) Skills\n\nAdd your team\u{2019}s shared agent skills here.\n"
            try? readmeContent.write(toFile: "\(skillsDir)/README.md", atomically: true, encoding: .utf8)
            try? "".write(toFile: "\(rulesDir)/.gitkeep", atomically: true, encoding: .utf8)
            try? "".write(toFile: "\(playgroundDir)/.gitkeep", atomically: true, encoding: .utf8)

            let _ = Self.runGit(["checkout", "-b", branchName], in: checkoutPath)
            let _ = Self.runGit(["add", "\(name)/"], in: checkoutPath)
            let _ = Self.runGit(["commit", "-m", "Add \(name) team"], in: checkoutPath)
            let pushResult = Self.runGit(["push", "-u", "origin", branchName], in: checkoutPath)
            let _ = Self.runGit(["checkout", "main"], in: checkoutPath)

            DispatchQueue.main.async {
                isCreatingTeam = false
                showCreateTeam = false

                if pushResult.success {
                    var updated = appState.settingsStore.settings
                    if !updated.scanRoots.contains(name) {
                        updated.scanRoots.append(name)
                        appState.settingsStore.replace(with: updated)
                    }
                    appState.discoverTeams()
                    loadSkills()
                    pushMessage = "Created \(name) team (pushed to branch \(branchName))"
                } else {
                    pushMessage = "Create failed: \(pushResult.output.prefix(120))"
                }

                newTeamName = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    pushMessage = nil
                }
            }
        }
    }

    // MARK: - Delete Local Skill

    private func deleteLocalSkill(_ skill: SkillInfo) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        for destPrefix in ManifestLoader.skillDestinations {
            let skillPath = "\(home)/\(destPrefix)/\(skill.dirName)"
            try? fm.removeItem(atPath: skillPath)
        }

        Analytics.track(.localSkillDeleted(skill: skill.dirName))

        withAnimation(.easeInOut(duration: 0.2)) {
            loadSkills()
        }

        pushMessage = "Deleted \(skill.name)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            pushMessage = nil
        }
    }

    // MARK: - Skill Discovery

    private func loadSkills() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let settings = appState.settingsStore.settings
        let checkoutPath = settings.checkoutPath.expandingTildePath

        // 1. Build skill-to-team mapping and per-team playground skills from registry
        var skillToTeam: [String: String] = [:]
        var teamPlayground: [String: [SkillInfo]] = [:]

        let teams = subscribedTeams

        for team in teams {
            // Official skills
            let skillsDir = "\(checkoutPath)/\(team.folderName)/skills"
            if let entries = try? fm.contentsOfDirectory(atPath: skillsDir) {
                for entry in entries {
                    if entry.hasPrefix(".") { continue }
                    let path = "\(skillsDir)/\(entry)"
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                        if skillToTeam[entry] == nil {
                            skillToTeam[entry] = team.folderName
                        }
                    }
                }
            }

            // Playground skills
            let pgDir = "\(checkoutPath)/\(team.folderName)/playground/skills"
            var pgSkills: [SkillInfo] = []
            if let entries = try? fm.contentsOfDirectory(atPath: pgDir) {
                for entry in entries {
                    if entry.hasPrefix(".") { continue }
                    let path = "\(pgDir)/\(entry)"
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
                    let skillFile = "\(path)/SKILL.md"
                    if let content = try? String(contentsOfFile: skillFile, encoding: .utf8) {
                        pgSkills.append(parseSkillFrontmatter(content, fallbackName: entry, dirName: entry))
                    }
                }
            }
            teamPlayground[team.folderName] = pgSkills.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        // 2. Scan locally installed skills
        let searchDirs = ManifestLoader.skillDestinations.map { "\(home)/\($0)" }
        var seen = Set<String>()
        var allInstalled: [SkillInfo] = []

        for dir in searchDirs {
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries {
                let skillDir = "\(dir)/\(entry)"
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: skillDir, isDirectory: &isDir), isDir.boolValue else { continue }

                let skillFile = "\(skillDir)/SKILL.md"
                guard let content = try? String(contentsOfFile: skillFile, encoding: .utf8) else { continue }

                let info = parseSkillFrontmatter(content, fallbackName: entry, dirName: entry)
                if seen.insert(info.dirName).inserted {
                    allInstalled.append(info)
                }
            }
        }

        // 3. Group into team sections — always include "everyone" even if empty
        var groups: [TeamSkillGroup] = []
        let allTeamSkillNames = Set(skillToTeam.keys)

        // Ensure "everyone" is always first, even if not discovered
        var includedTeamNames = Set<String>()
        for team in teams {
            let official = allInstalled
                .filter { skillToTeam[$0.dirName] == team.folderName }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let playground = teamPlayground[team.folderName] ?? []

            groups.append(TeamSkillGroup(
                teamName: team.folderName,
                displayName: team.displayName,
                officialSkills: official,
                playgroundSkills: playground
            ))
            includedTeamNames.insert(team.folderName)
        }

        // Always show "Everyone" section as a structural default
        if !includedTeamNames.contains("everyone") {
            groups.insert(TeamSkillGroup(
                teamName: "everyone",
                displayName: "Everyone",
                officialSkills: [],
                playgroundSkills: []
            ), at: 0)
        }

        teamGroups = groups

        // 4. Local skills = installed but not in any team
        localSkills = allInstalled
            .filter { !allTeamSkillNames.contains($0.dirName) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // 5. Legacy community-playground support
        let communityDir = "\(checkoutPath)/community-playground"
        var legacyResult: [SkillInfo] = []
        var legacySeen = Set<String>()

        if let topEntries = try? fm.contentsOfDirectory(atPath: communityDir) {
            for topEntry in topEntries {
                if topEntry.hasPrefix(".") { continue }
                let topPath = "\(communityDir)/\(topEntry)"
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: topPath, isDirectory: &isDir), isDir.boolValue else { continue }

                let directSkillFile = "\(topPath)/SKILL.md"
                if let content = try? String(contentsOfFile: directSkillFile, encoding: .utf8) {
                    let info = parseSkillFrontmatter(content, fallbackName: topEntry, dirName: topEntry)
                    if legacySeen.insert(info.dirName).inserted {
                        legacyResult.append(info)
                    }
                    continue
                }

                guard let subEntries = try? fm.contentsOfDirectory(atPath: topPath) else { continue }
                for subEntry in subEntries {
                    if subEntry.hasPrefix(".") { continue }
                    let subPath = "\(topPath)/\(subEntry)"
                    var subIsDir: ObjCBool = false
                    guard fm.fileExists(atPath: subPath, isDirectory: &subIsDir), subIsDir.boolValue else { continue }

                    let dirName = "\(topEntry)/\(subEntry)"
                    if let skillContent = findFirstSkillMD(in: subPath) {
                        let info = parseSkillFrontmatter(skillContent, fallbackName: subEntry, dirName: dirName)
                        if legacySeen.insert(info.dirName).inserted {
                            legacyResult.append(info)
                        }
                    }
                }
            }
        }

        legacyPlaygroundSkills = legacyResult.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        // 6. Cache sorted arrays for sidebar (avoids re-sorting on every render)
        sortedTeamSkills = teamGroups.flatMap { $0.officialSkills }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        sortedPlaygroundSkills = (teamGroups.flatMap { $0.playgroundSkills } + legacyPlaygroundSkills)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Skill File Helpers

    private func findFirstSkillMD(in path: String) -> String? {
        let fm = FileManager.default
        let skillFile = "\(path)/SKILL.md"
        if let content = try? String(contentsOfFile: skillFile, encoding: .utf8) {
            return content
        }

        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return nil }
        for entry in entries {
            if entry.hasPrefix(".") { continue }
            let childPath = "\(path)/\(entry)"
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: childPath, isDirectory: &isDir), isDir.boolValue {
                if let found = findFirstSkillMD(in: childPath) {
                    return found
                }
            }
        }
        return nil
    }

    private func parseSkillFrontmatter(_ content: String, fallbackName: String, dirName: String) -> SkillInfo {
        var name = fallbackName
        var description = ""

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else {
            return SkillInfo(name: name, description: description, dirName: dirName)
        }

        let afterOpening = trimmed.dropFirst(3)
        guard let closingRange = afterOpening.range(of: "\n---") else {
            return SkillInfo(name: name, description: description, dirName: dirName)
        }

        let frontmatter = afterOpening[afterOpening.startIndex..<closingRange.lowerBound]

        for line in frontmatter.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var value = parts[1].trimmingCharacters(in: .whitespaces)

            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            switch key {
            case "name":
                name = value
            case "description":
                description = value
            default:
                break
            }
        }

        return SkillInfo(name: name, description: description, dirName: dirName)
    }

    // MARK: - Git Helper

    private nonisolated static func runGit(_ args: [String], in directory: String) -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus == 0, output)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Directory Merge Helper

    private nonisolated static func mergeDirectoryContents(from source: String, to destination: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: destination) {
            try? fm.createDirectory(atPath: destination, withIntermediateDirectories: true)
        }
        guard let children = try? fm.contentsOfDirectory(atPath: source) else { return }
        for child in children {
            if child.hasPrefix(".") { continue }
            let srcPath = "\(source)/\(child)"
            let dstPath = "\(destination)/\(child)"
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: srcPath, isDirectory: &isDir), isDir.boolValue {
                Self.mergeDirectoryContents(from: srcPath, to: dstPath)
            } else {
                try? fm.removeItem(atPath: dstPath)
                try? fm.copyItem(atPath: srcPath, toPath: dstPath)
            }
        }
    }
}

// MARK: - Skill Detail View

struct SkillDetailView: View {
    let skill: SkillInfo
    let category: SkillCategory
    let teamName: String?
    let isSyncing: Bool
    let columnVisibility: NavigationSplitViewVisibility
    @Binding var enabledPlaygroundSkills: Set<String>
    let onDelete: (SkillInfo) -> Void
    let onPush: (SkillInfo) -> Void
    let onSync: () -> Void
    let onTogglePlayground: (String) -> Void
    let onReload: () -> Void

    @EnvironmentObject var appState: AppState
    @State private var skillContent: String = ""
    @State private var markdownBody: String?
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Zone 1: Header toolbar — title left, chunky action buttons right
            HStack(alignment: .top, spacing: 8) {
                Text(skill.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .padding(.top, 4)

                Spacer()

                // Primary action: Push to Playground (local) or Sync (playground)
                if category == .local {
                    Button {
                        onPush(skill)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 11))
                            Text("Push")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(
                                LinearGradient(
                                    colors: [Brand.indigo, Brand.indigoDim],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                }

                if category == .playground {
                    Button {
                        onSync()
                    } label: {
                        HStack(spacing: 5) {
                            if isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                            }
                            Text(isSyncing ? "Syncing\u{2026}" : "Sync")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(
                                LinearGradient(
                                    colors: [Brand.indigo, Brand.indigoDim],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .disabled(enabledPlaygroundSkills.isEmpty || isSyncing)
                    .opacity(enabledPlaygroundSkills.isEmpty ? 0.5 : 1)
                }

                // Edit / Done button
                if !skillContent.isEmpty {
                    Button {
                        if isEditing {
                            saveContent()
                        }
                        isEditing.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isEditing ? "checkmark" : "pencil")
                                .font(.system(size: 10, weight: .semibold))
                            Text(isEditing ? "Done" : "Edit")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isEditing ? .white : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(isEditing ? AnyShapeStyle(Color.green) : AnyShapeStyle(.quaternary.opacity(0.6)))
                    )
                    .help(isEditing ? "Save changes" : "Edit skill")
                }

                // Delete button
                if category == .local {
                    Button {
                        onDelete(skill)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(.quaternary.opacity(0.6))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Delete skill")
                }
            }
            .padding(.leading, columnVisibility == .detailOnly ? 80 : 20)
            .padding(.trailing, 20)
            .padding(.vertical, 12)
            .background(Surface.header)

            Divider().opacity(0.3)

            // Zone 2: Scrolling content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Description
                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    // Editing note for team skills
                    if isEditing && category == .team {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                            Text("Editing local copy only")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.orange)
                    }

                    // Skill content — edit mode or rendered markdown
                    if isEditing {
                        TextEditor(text: $skillContent)
                            .font(.system(size: 12, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.quaternary.opacity(0.3))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Brand.indigoMid.opacity(0.3), lineWidth: 1)
                            )
                            .frame(minHeight: 200, maxHeight: 500)
                    } else if let body = markdownBody, !body.isEmpty {
                        Markdown(body)
                            .markdownTextStyle {
                                FontSize(14)
                            }
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 20))
                                .foregroundStyle(.tertiary)
                            Text("No content yet")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }

                    Divider().opacity(0.15)

                    // Synced destinations
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SYNCED TO")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .tracking(0.5)

                        ForEach(ManifestLoader.skillDestinations, id: \.self) { dest in
                            Text("~/\(dest)/\(skill.dirName)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    }

                    // Playground toggle
                    if category == .playground {
                        Divider().opacity(0.15)

                        let qualifiedName = teamName != nil ? "\(teamName!)/\(skill.dirName)" : skill.dirName
                        let isEnabled = enabledPlaygroundSkills.contains(qualifiedName)
                        Toggle(isOn: Binding(
                            get: { isEnabled },
                            set: { _ in onTogglePlayground(qualifiedName) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enabled for sync")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Include this skill when syncing playground selections")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        if isSkillSyncedLocally(skill.dirName) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.green)
                                Text("Synced locally")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Surface.content)
        .toolbarBackground(.hidden, for: .automatic)
        .ignoresSafeArea(.container, edges: .top)
        .onAppear { loadContent() }
        .onChange(of: skill.id) {
            isEditing = false
            loadContent()
        }
    }

    // MARK: - Content Loading

    private func loadContent() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let settings = appState.settingsStore.settings
        let checkoutPath = settings.checkoutPath.expandingTildePath
        let skillName = skill.dirName.contains("/") ? String(skill.dirName.split(separator: "/").last!) : skill.dirName
        let destinations = ManifestLoader.skillDestinations
        let cat = category
        let team = teamName

        Task.detached(priority: .userInitiated) {
            var result: String = ""

            // Try checkout path first for team/playground skills
            if let team {
                let path: String
                if cat == .playground {
                    path = "\(checkoutPath)/\(team)/playground/skills/\(skillName)/SKILL.md"
                } else {
                    path = "\(checkoutPath)/\(team)/skills/\(skillName)/SKILL.md"
                }
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    result = content
                }
            }

            // Fall back to local destinations
            if result.isEmpty {
                for dest in destinations {
                    let path = "\(home)/\(dest)/\(skillName)/SKILL.md"
                    if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                        result = content
                        break
                    }
                }
            }

            let body = Self.stripFrontmatter(result)

            await MainActor.run {
                skillContent = result
                markdownBody = body.isEmpty ? nil : body
            }
        }
    }

    private func saveContent() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let skillName = skill.dirName.contains("/") ? String(skill.dirName.split(separator: "/").last!) : skill.dirName

        // Write to all local destinations where the skill dir exists
        for dest in ManifestLoader.skillDestinations {
            let skillDir = "\(home)/\(dest)/\(skillName)"
            let skillFile = "\(skillDir)/SKILL.md"
            if fm.fileExists(atPath: skillDir) {
                try? skillContent.write(toFile: skillFile, atomically: true, encoding: .utf8)
            }
        }

        // Update the markdown body so the view shows the edited content
        let body = Self.stripFrontmatter(skillContent)
        markdownBody = body.isEmpty ? nil : body

        onReload()
    }

    /// Strip YAML frontmatter — nonisolated static so it can run off main thread
    nonisolated private static func stripFrontmatter(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return raw }
        let afterOpening = trimmed.dropFirst(3)
        guard let closingRange = afterOpening.range(of: "\n---") else { return raw }
        return String(afterOpening[closingRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isSkillSyncedLocally(_ dirName: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let skillName = dirName.contains("/") ? String(dirName.split(separator: "/").last!) : dirName
        return FileManager.default.fileExists(atPath: "\(home)/.claude/skills/\(skillName)")
    }
}

// MARK: - Skills Sidebar View

struct SkillsSidebarView: View {
    @Binding var selection: SidebarSelection?
    @Binding var searchText: String
    let teamGroups: [TeamSkillGroup]
    let sortedTeamSkills: [SkillInfo]
    let sortedPlaygroundSkills: [SkillInfo]
    let localSkills: [SkillInfo]
    let legacyPlaygroundSkills: [SkillInfo]
    let teamSkillCount: Int
    let enabledPlaygroundSkills: Set<String>
    let isSyncing: Bool
    let appIsSyncing: Bool
    let onSync: () -> Void
    let onSyncNow: () -> Void
    let onNewSkill: () -> Void
    let onNewTeam: () -> Void

    // MARK: - Sidebar Derived State

    private var expandedSpace: String? {
        guard let selection else { return nil }
        switch selection {
        case .space(let name):
            return name
        case .skill(let id):
            for group in teamGroups {
                if group.officialSkills.contains(where: { $0.id == id }) ||
                   group.playgroundSkills.contains(where: { $0.id == id }) {
                    return "team"
                }
            }
            if legacyPlaygroundSkills.contains(where: { $0.id == id }) { return "team" }
            if localSkills.contains(where: { $0.id == id }) { return "local" }
            return nil
        }
    }

    private var filteredSkills: [SkillInfo] {
        let query = searchText.lowercased()
        let all = teamGroups.flatMap { $0.officialSkills + $0.playgroundSkills } + localSkills + legacyPlaygroundSkills
        return all.filter { $0.name.lowercased().contains(query) || $0.description.lowercased().contains(query) }
    }

    var body: some View {
        sidebarList
            .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 300)
            .safeAreaInset(edge: .top, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Skills")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()

                    // Sync button
                    Button(action: onSyncNow) {
                        HStack(spacing: 3) {
                            if appIsSyncing {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            Text(appIsSyncing ? "Syncing" : "Sync")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(
                                    LinearGradient(
                                        colors: [Brand.indigo, Brand.indigoDim],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(appIsSyncing)

                    Menu {
                        Button {
                            onNewSkill()
                        } label: {
                            Label("New Skill", systemImage: "doc.badge.plus")
                        }
                        Divider()
                        Button {
                            onNewTeam()
                        } label: {
                            Label("New Team", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("New")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Brand.indigoMid)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Brand.indigo.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !enabledPlaygroundSkills.isEmpty {
                    syncBar
                        .padding(12)
                }
            }
    }

    private var sidebarList: some View {
        List(selection: $selection) {
            if !searchText.isEmpty {
                // Flat filtered results when searching
                ForEach(filteredSkills) { skill in
                    sidebarSkillRow(skill)
                        .tag(SidebarSelection.skill(skill.id))
                }
                if filteredSkills.isEmpty {
                    Text("No results")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            } else {
                // Team space
                sidebarSpaceRow("Team", count: teamSkillCount)
                    .tag(SidebarSelection.space("team"))

                if expandedSpace == "team" {
                    ForEach(sortedTeamSkills) { skill in
                        sidebarSkillRow(skill)
                            .tag(SidebarSelection.skill(skill.id))
                    }
                    if !sortedPlaygroundSkills.isEmpty {
                        sidebarSectionLabel("Playground")
                        ForEach(sortedPlaygroundSkills) { skill in
                            sidebarSkillRow(skill)
                                .tag(SidebarSelection.skill(skill.id))
                        }
                    }
                }

                // Local space
                sidebarSpaceRow("Local", count: localSkills.count)
                    .tag(SidebarSelection.space("local"))

                if expandedSpace == "local" {
                    ForEach(localSkills) { skill in
                        sidebarSkillRow(skill)
                            .tag(SidebarSelection.skill(skill.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaPadding(.top, 8)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search skills")
    }

    // MARK: - Sidebar Row Helpers

    private func sidebarSpaceRow(_ name: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(Capsule())
            }
        }
    }

    private func sidebarSkillRow(_ skill: SkillInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(skill.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func sidebarSectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.top, 8)
    }

    // MARK: - Sync Bar

    private var syncBar: some View {
        Button {
            onSync()
        } label: {
            HStack(spacing: 6) {
                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .medium))
                }
                Text(isSyncing ? "Syncing\u{2026}" : "Sync Selected")
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Brand.indigo, Brand.indigoDim],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(isSyncing)
        .opacity(isSyncing ? 0.6 : 1)
    }
}

// MARK: - Skill Info Model

struct SkillInfo: Identifiable {
    let name: String
    let description: String
    let dirName: String
    var id: String { dirName }
}
