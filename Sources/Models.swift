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

    static let defaultScanRoots = ["shared-global"]

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

extension String {
    var expandingTildePath: String {
        (self as NSString).expandingTildeInPath
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
