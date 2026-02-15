import SwiftUI

struct SkillsView: View {
    @EnvironmentObject var appState: AppState
    @State private var allSkills: [SkillInfo] = []
    @State private var teamSkillNames: Set<String> = []
    @State private var communitySkills: [SkillInfo] = []
    @State private var selectedTab: SkillTab = .global
    @State private var pushMessage: String? = nil
    @State private var syncMessage: String? = nil
    @State private var isSyncing = false
    @State private var localEnabledCommunitySkills: Set<String> = []
    @State private var debounceTask: DispatchWorkItem? = nil
    @State private var skillToDelete: SkillInfo? = nil

    enum SkillTab: String, CaseIterable {
        case global = "Team"
        case local = "Local"
        case community = "Playground"
    }

    private var displayedSkills: [SkillInfo] {
        switch selectedTab {
        case .global:
            return allSkills.filter { teamSkillNames.contains($0.dirName) }
        case .local:
            return allSkills.filter { !teamSkillNames.contains($0.dirName) }
        case .community:
            return communitySkills
        }
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                tabBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                Divider().opacity(0.5)

                if selectedTab == .community {
                    communitySyncBar
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                }

                if displayedSkills.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(displayedSkills) { skill in
                                switch selectedTab {
                                case .global:
                                    skillCard(skill)
                                case .local:
                                    localSkillCard(skill)
                                case .community:
                                    communitySkillCard(skill)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, selectedTab == .community ? 8 : 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    if let msg = pushMessage {
                        messageBanner(msg, isError: false)
                    }
                    if let msg = syncMessage {
                        messageBanner(msg, isError: false)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: pushMessage)
                .animation(.easeInOut(duration: 0.2), value: syncMessage)
            }
        }
        .frame(width: 480, height: 520)
        .alert(
            "Delete Skill",
            isPresented: Binding(
                get: { skillToDelete != nil },
                set: { if !$0 { skillToDelete = nil } }
            ),
            presenting: skillToDelete
        ) { skill in
            Button("Cancel", role: .cancel) { skillToDelete = nil }
            Button("Delete", role: .destructive) { deleteLocalSkill(skill) }
        } message: { skill in
            Text("Remove \"\(skill.name)\" from all agent tool directories? This can\u{2019}t be undone.")
        }
        .onAppear {
            loadSkills()
            localEnabledCommunitySkills = Set(appState.settingsStore.settings.enabledCommunitySkills)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            AppIconView(size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Skills")
                    .font(.system(size: 16, weight: .semibold))
                Text("Installed skill definitions")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(displayedSkills.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Brand.indigoMid)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Brand.indigo.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SkillTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.primary.opacity(0.06))
        )
    }

    private func tabButton(_ tab: SkillTab) -> some View {
        let isSelected = selectedTab == tab
        let count: Int = {
            switch tab {
            case .global:
                return allSkills.filter { teamSkillNames.contains($0.dirName) }.count
            case .local:
                return allSkills.filter { !teamSkillNames.contains($0.dirName) }.count
            case .community:
                return communitySkills.count
            }
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 5) {
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? Brand.indigoMid : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Brand.indigo.opacity(0.12) : .clear)
            )
            .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: emptyStateIcon)
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(emptyStateTitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(emptyStateSubtitle)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyStateIcon: String {
        switch selectedTab {
        case .global: return "person.2"
        case .local: return "tray"
        case .community: return "flask"
        }
    }

    private var emptyStateTitle: String {
        switch selectedTab {
        case .global: return "No team skills synced"
        case .local: return "No local skills"
        case .community: return "No playground skills found"
        }
    }

    private var emptyStateSubtitle: String {
        switch selectedTab {
        case .global: return "Run a sync to pull team skills"
        case .local: return "Skills in ~/.claude/skills/ not from team"
        case .community: return "Playground skills appear after syncing the registry"
        }
    }

    // MARK: - Message Banner

    private func messageBanner(_ text: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            isError
                ? AnyShapeStyle(Color(red: 0.72, green: 0.22, blue: 0.30))  // warm rose — on-brand error
                : AnyShapeStyle(
                    LinearGradient(
                        colors: [Brand.indigo, Brand.indigoDim],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Skill Card (Team)

    private func skillCard(_ skill: SkillInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(skill.name)
                .font(.system(size: 13, weight: .semibold))

            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background.opacity(0.55))
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Skill Card (Local)

    private func localSkillCard(_ skill: SkillInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(skill.name)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button {
                    pushToCommunity(skill: skill)
                } label: {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(Brand.indigoMid)
                }
                .buttonStyle(.plain)
                .help("Push to Playground")

                LocalSkillDeleteButton { skillToDelete = skill }
            }

            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background.opacity(0.55))
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Skill Card (Playground)

    private func communitySkillCard(_ skill: SkillInfo) -> some View {
        let isEnabled = localEnabledCommunitySkills.contains(skill.dirName)
        let isSynced = isSkillSyncedLocally(skill.dirName)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundStyle(isEnabled ? Brand.indigoMid : Color.secondary.opacity(0.5))

                Text(skill.name)
                    .font(.system(size: 13, weight: .semibold))

                if isSynced {
                    Text("Synced")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Brand.indigoMid)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Brand.indigo.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.leading, 28)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleCommunitySkill(skill.dirName)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background.opacity(0.55))
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func toggleCommunitySkill(_ dirName: String) {
        let enabling = !localEnabledCommunitySkills.contains(dirName)
        if enabling {
            localEnabledCommunitySkills.insert(dirName)
        } else {
            localEnabledCommunitySkills.remove(dirName)
        }
        Analytics.track(.communitySkillToggled(skill: dirName, enabled: enabling))
        debounceSaveCommunitySkills()
    }

    private func debounceSaveCommunitySkills() {
        debounceTask?.cancel()
        let snapshot = localEnabledCommunitySkills
        let task = DispatchWorkItem { [snapshot] in
            var updated = appState.settingsStore.settings
            updated.enabledCommunitySkills = Array(snapshot)
            appState.settingsStore.replace(with: updated)
        }
        debounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    // MARK: - Playground Sync Bar (Sticky)

    private var hasSelectedCommunitySkills: Bool {
        !localEnabledCommunitySkills.isEmpty
    }

    private var communitySyncBar: some View {
        Button {
            syncCommunitySkills()
        } label: {
            HStack(spacing: 6) {
                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(isSyncing ? "Syncing..." : "Sync Selected")
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        hasSelectedCommunitySkills
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Brand.indigo, Brand.indigoDim],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                              )
                            : AnyShapeStyle(Color.primary.opacity(0.06))
                    )
            )
            .foregroundStyle(hasSelectedCommunitySkills ? .white : Color.secondary.opacity(0.4))
        }
        .buttonStyle(.plain)
        .disabled(!hasSelectedCommunitySkills || isSyncing)
        .opacity(hasSelectedCommunitySkills ? 1.0 : 0.6)
    }

    // MARK: - Helpers

    private func isSkillSyncedLocally(_ dirName: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return FileManager.default.fileExists(atPath: "\(home)/.claude/skills/\(dirName)")
    }

    // MARK: - Push to Playground

    private func pushToCommunity(skill: SkillInfo) {
        let settings = appState.settingsStore.settings
        let checkoutPath = settings.checkoutPath.expandingTildePath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let sourcePath = "\(home)/.claude/skills/\(skill.dirName)"
        let communityDest = "\(checkoutPath)/community-playground/\(skill.dirName)"

        let fm = FileManager.default
        let isUpdate = fm.fileExists(atPath: communityDest)
        let verb = isUpdate ? "Update" : "Add"
        let branchName = "community/\(skill.dirName)"

        DispatchQueue.global(qos: .userInitiated).async {
            // Checkout or create branch
            let _ = Self.runGit(["checkout", branchName], in: checkoutPath)
            if !FileManager.default.fileExists(atPath: "\(checkoutPath)/.git/refs/heads/\(branchName)") {
                let _ = Self.runGit(["checkout", "-b", branchName], in: checkoutPath)
            }

            // Copy skill to community-playground
            Self.mergeDirectoryContents(from: sourcePath, to: communityDest)

            // Stage, commit, push
            let _ = Self.runGit(["add", "community-playground/\(skill.dirName)/"], in: checkoutPath)
            let _ = Self.runGit(["commit", "-m", "\(verb) \(skill.dirName) community skill"], in: checkoutPath)
            let pushResult = Self.runGit(["push", "-u", "origin", branchName], in: checkoutPath)

            // Return to main
            let _ = Self.runGit(["checkout", "main"], in: checkoutPath)

            DispatchQueue.main.async {
                if pushResult.success {
                    Analytics.track(.skillPushedToCommunity(skill: skill.dirName, isUpdate: isUpdate))
                    pushMessage = "\(verb)d \(skill.dirName) on branch \(branchName)"
                } else {
                    pushMessage = "Push failed: \(pushResult.output.prefix(120))"
                }

                // Clear after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    pushMessage = nil
                }
            }
        }
    }

    // MARK: - Sync Playground Skills

    private func syncCommunitySkills() {
        guard !isSyncing else { return }
        isSyncing = true

        let settings = appState.settingsStore.settings
        let checkoutPath = settings.checkoutPath.expandingTildePath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let enabled = settings.enabledCommunitySkills

        DispatchQueue.global(qos: .userInitiated).async {
            var synced = 0
            for dirName in enabled {
                let source = "\(checkoutPath)/community-playground/\(dirName)"
                guard FileManager.default.fileExists(atPath: source) else { continue }

                for destPrefix in ManifestLoader.skillDestinations {
                    let dest = "\(home)/\(destPrefix)/\(dirName)"
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

        // Discover team skills from registry checkout
        let settings = appState.settingsStore.settings
        let checkoutPath = settings.checkoutPath.expandingTildePath
        var teamNames = Set<String>()

        for scanRoot in settings.scanRoots {
            let rootDir = "\(checkoutPath)/\(scanRoot)"
            for skillsDir in Self.findSkillsDirs(under: rootDir, fm: fm) {
                if let entries = try? fm.contentsOfDirectory(atPath: skillsDir) {
                    for entry in entries {
                        let path = "\(skillsDir)/\(entry)"
                        var isDir: ObjCBool = false
                        if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                            teamNames.insert(entry)
                        }
                    }
                }
            }
        }
        teamSkillNames = teamNames

        // Discover all installed skills
        let searchDirs = ManifestLoader.skillDestinations.map { "\(home)/\($0)" }

        var seen = Set<String>()
        var result: [SkillInfo] = []

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
                    result.append(info)
                }
            }
        }

        allSkills = result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Discover community skills
        let communityDir = "\(checkoutPath)/community-playground"
        var communityResult: [SkillInfo] = []
        var communitySeen = Set<String>()

        guard let topEntries = try? fm.contentsOfDirectory(atPath: communityDir) else {
            communitySkills = []
            return
        }

        for topEntry in topEntries {
            if topEntry.hasPrefix(".") { continue }
            let topPath = "\(communityDir)/\(topEntry)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: topPath, isDirectory: &isDir), isDir.boolValue else { continue }

            // Check for direct SKILL.md
            let directSkillFile = "\(topPath)/SKILL.md"
            if let content = try? String(contentsOfFile: directSkillFile, encoding: .utf8) {
                let info = parseSkillFrontmatter(content, fallbackName: topEntry, dirName: topEntry)
                if communitySeen.insert(info.dirName).inserted {
                    communityResult.append(info)
                }
                continue
            }

            // Check subdirectories for nested skills (e.g. user/project structure)
            guard let subEntries = try? fm.contentsOfDirectory(atPath: topPath) else { continue }
            for subEntry in subEntries {
                if subEntry.hasPrefix(".") { continue }
                let subPath = "\(topPath)/\(subEntry)"
                var subIsDir: ObjCBool = false
                guard fm.fileExists(atPath: subPath, isDirectory: &subIsDir), subIsDir.boolValue else { continue }

                let dirName = "\(topEntry)/\(subEntry)"

                if let skillContent = findFirstSkillMD(in: subPath) {
                    let info = parseSkillFrontmatter(skillContent, fallbackName: subEntry, dirName: dirName)
                    if communitySeen.insert(info.dirName).inserted {
                        communityResult.append(info)
                    }
                }
            }
        }

        communitySkills = communityResult.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Recursively find the first SKILL.md in a directory tree
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

    /// Recursively find all directories named "skills" under a root path,
    /// matching the same traversal logic as ManifestLoader.scanForContent.
    private static func findSkillsDirs(under path: String, fm: FileManager) -> [String] {
        var results: [String] = []
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return results }
        for entry in entries {
            if entry.hasPrefix(".") { continue }
            let childPath = "\(path)/\(entry)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: childPath, isDirectory: &isDir), isDir.boolValue else { continue }
            if entry == "skills" {
                results.append(childPath)
            } else if entry != "rules" {
                results.append(contentsOf: findSkillsDirs(under: childPath, fm: fm))
            }
        }
        return results
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

// MARK: - Delete Button (hover-reveal, subtle)

private struct LocalSkillDeleteButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(isHovered ? Color.red : Color.secondary.opacity(0.35))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .help("Delete skill")
    }
}

// MARK: - Skill Info Model

struct SkillInfo: Identifiable {
    let name: String
    let description: String
    let dirName: String
    var id: String { dirName }
}
