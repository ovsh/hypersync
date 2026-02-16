import Foundation

enum SyncStatus {
    case idle
    case syncing
    case succeeded
    case failed
}

enum MappingKind: String, Codable {
    case file
    case directory
}

enum MappingStrategy: String, Codable {
    case replace
    case merge
}

struct MappingItem: Codable, Hashable {
    var source: String
    var destination: String
    var kind: MappingKind
    var strategy: MappingStrategy
}

struct Manifest: Codable {
    var version: Int
    var mappings: [MappingItem]
}

struct AppSettings: Codable {
    var remoteGitURL: String
    var scanRoots: [String]
    var checkoutPath: String
    var autoSyncEnabled: Bool
    var autoSyncIntervalMinutes: Int
    var enabledCommunitySkills: [String]

    enum CodingKeys: String, CodingKey {
        case remoteGitURL
        case scanRoots = "scan_roots"
        case checkoutPath
        case autoSyncEnabled
        case autoSyncIntervalMinutes
        case enabledCommunitySkills
    }

    // Custom decoder: gracefully handles old settings.json files that
    // had "manifestPath" instead of "scan_roots".
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        remoteGitURL = try c.decode(String.self, forKey: .remoteGitURL)
        scanRoots = try c.decodeIfPresent([String].self, forKey: .scanRoots) ?? Self.defaultScanRoots
        checkoutPath = try c.decode(String.self, forKey: .checkoutPath)
        autoSyncEnabled = try c.decode(Bool.self, forKey: .autoSyncEnabled)
        autoSyncIntervalMinutes = try c.decode(Int.self, forKey: .autoSyncIntervalMinutes)
        enabledCommunitySkills = try c.decodeIfPresent([String].self, forKey: .enabledCommunitySkills) ?? []
    }

    init(remoteGitURL: String, scanRoots: [String], checkoutPath: String, autoSyncEnabled: Bool, autoSyncIntervalMinutes: Int, enabledCommunitySkills: [String] = []) {
        self.remoteGitURL = remoteGitURL
        self.scanRoots = scanRoots
        self.checkoutPath = checkoutPath
        self.autoSyncEnabled = autoSyncEnabled
        self.autoSyncIntervalMinutes = autoSyncIntervalMinutes
        self.enabledCommunitySkills = enabledCommunitySkills
    }

    static let defaultScanRoots = ["everyone"]

    static func defaults() -> AppSettings {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return AppSettings(
            remoteGitURL: "",
            scanRoots: defaultScanRoots,
            checkoutPath: "\(home)/Library/Application Support/HyperSync/registry",
            autoSyncEnabled: true,
            autoSyncIntervalMinutes: 60
        )
    }
}

// MARK: - Multi-Team Support

struct TeamInfo: Identifiable {
    let folderName: String     // e.g. "engineering" — used as scan root
    let displayName: String    // e.g. "Engineering" — from team.yaml or capitalized folder name
    let description: String    // from team.yaml, may be empty
    let hasPlayground: Bool    // whether playground/skills/ exists in this team folder
    var id: String { folderName }
}

struct TeamDiscovery {
    /// Scans the registry checkout root for team folders.
    /// A team folder is any top-level directory containing `skills/` or `rules/`.
    static func discover(registryRoot: URL) -> [TeamInfo] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: registryRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var teams: [TeamInfo] = []
        for child in children {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }

            let name = child.lastPathComponent
            if name == "community-playground" { continue }

            let hasSkills = fm.fileExists(atPath: child.appendingPathComponent("skills").path)
            let hasRules = fm.fileExists(atPath: child.appendingPathComponent("rules").path)
            guard hasSkills || hasRules else { continue }

            let hasPlayground = fm.fileExists(
                atPath: child.appendingPathComponent("playground/skills").path
            )

            // Parse optional team.yaml for metadata
            let (displayName, description) = parseTeamYaml(at: child, fallback: name)

            teams.append(TeamInfo(
                folderName: name,
                displayName: displayName,
                description: description,
                hasPlayground: hasPlayground
            ))
        }

        // Sort: "everyone" first, then alphabetical
        return teams.sorted { a, b in
            if a.folderName == "everyone" { return true }
            if b.folderName == "everyone" { return false }
            return a.folderName < b.folderName
        }
    }

    /// Parse a simple team.yaml with `name:` and `description:` fields.
    private static func parseTeamYaml(at teamDir: URL, fallback: String) -> (String, String) {
        let yamlPath = teamDir.appendingPathComponent("team.yaml").path
        guard let content = try? String(contentsOfFile: yamlPath, encoding: .utf8) else {
            return (fallback.capitalized, "")
        }

        var name = fallback.capitalized
        var description = ""

        for line in content.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var value = parts[1].trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            switch key {
            case "name": name = value
            case "description": description = value
            default: break
            }
        }
        return (name, description)
    }
}

extension String {
    var expandingTildePath: String {
        (self as NSString).expandingTildeInPath
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
