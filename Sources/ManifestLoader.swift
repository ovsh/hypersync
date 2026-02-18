import Foundation

enum ManifestLoaderError: LocalizedError {
    case noMappings

    var errorDescription: String? {
        switch self {
        case .noMappings:
            return "Scan found no skills/ or rules/ directories under the configured scan roots."
        }
    }
}

struct ManifestLoader {
    private enum RegistrySchema {
        case teamBased
        case legacySharedGlobal
    }

    /// All agent tool directories that receive skills
    static let skillDestinations = [
        ".agents/skills",
        ".claude/skills",
        ".cursor/skills",
        ".config/opencode/skills",
    ]

    /// All agent tool directories that receive rules
    static let rulesDestinations = [
        ".claude/rules",
        ".cursor/rules",
    ]

    /// All allowed destination prefixes (skills + rules)
    static let allowedPrefixes = [
        ".agents", ".claude", ".cursor", ".config/opencode",
    ]

    /// Scan the registry for `skills/` and `rules/` directories under the given
    /// scan roots and return a Manifest with merge mappings for each one found.
    func load(
        registryRoot: URL,
        scanRoots: [String],
        logger: @escaping (LogLevel, String) -> Void
    ) throws -> Manifest {
        let fileManager = FileManager.default
        let schema = detectSchema(registryRoot: registryRoot, fileManager: fileManager)
        var mappings: [MappingItem] = []

        if schema == .legacySharedGlobal {
            logger(.warn, "Detected legacy shared-global layout; applying compatibility mapping rules.")
        }

        for root in scanRoots {
            let rootURL = registryRoot.appendingPathComponent(root).standardizedFileURL
            guard fileManager.fileExists(atPath: rootURL.path) else {
                logger(.warn, "Skipping missing scan root: \(rootURL.path)")
                continue
            }
            logger(.info, "Scanning \(root)/ for skills and rules directories")
            let found = scanForContent(
                at: rootURL,
                relativeTo: registryRoot,
                fileManager: fileManager,
                schema: schema
            )
            mappings.append(contentsOf: found)
        }

        // Deduplicate: same (source, destination) pair should only appear once.
        var seen = Set<String>()
        mappings = mappings.filter { item in
            let key = "\(item.source)|\(item.destination)"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }

        guard !mappings.isEmpty else {
            throw ManifestLoaderError.noMappings
        }

        for m in mappings {
            logger(.info, "  discovered: \(m.source) -> ~/\(m.destination)")
        }

        return Manifest(version: 2, mappings: mappings)
    }

    // MARK: - Private

    /// Recursively walk `directory` looking for dirs named "skills" or "rules".
    /// When found, generate merge mappings and stop recursing into them.
    private func scanForContent(
        at directory: URL,
        relativeTo registryRoot: URL,
        fileManager: FileManager,
        schema: RegistrySchema
    ) -> [MappingItem] {
        var results: [MappingItem] = []

        guard let children = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else {
            return results
        }

        for child in children {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }

            let name = child.lastPathComponent
            let relativePath = relativePath(of: child, relativeTo: registryRoot)

            if name == "skills" || name == "skills-cursor" || name == "rules" {
                results.append(contentsOf: mappings(
                    source: relativePath,
                    directoryName: name,
                    schema: schema
                ))
                // Do NOT recurse into skills/ — its children are individual skills, not more scan targets
            } else if name == "playground" {
                // playground/ holds opt-in experimental skills — skip auto-sync
            } else {
                // Not a known content dir — recurse deeper
                results.append(contentsOf: scanForContent(
                    at: child,
                    relativeTo: registryRoot,
                    fileManager: fileManager,
                    schema: schema
                ))
            }
        }

        return results
    }

    private func relativePath(of child: URL, relativeTo registryRoot: URL) -> String {
        let normalizedRoot = registryRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let normalizedChild = child.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = normalizedRoot.hasSuffix("/") ? normalizedRoot : normalizedRoot + "/"

        if normalizedChild.hasPrefix(prefix) {
            return String(normalizedChild.dropFirst(prefix.count))
        }

        // Fallback for unexpected path canonicalization differences.
        return child.lastPathComponent
    }

    private func mappings(source: String, directoryName: String, schema: RegistrySchema) -> [MappingItem] {
        let destinations: [String]
        switch directoryName {
        case "skills":
            destinations = skillDestinations(forSource: source, schema: schema)
        case "skills-cursor":
            destinations = [".cursor/skills"]
        case "rules":
            destinations = rulesDestinations(forSource: source, schema: schema)
        default:
            destinations = []
        }

        return destinations.map { dest in
            MappingItem(source: source, destination: dest, kind: .directory, strategy: .merge)
        }
    }

    private func skillDestinations(forSource source: String, schema: RegistrySchema) -> [String] {
        guard schema == .legacySharedGlobal else { return Self.skillDestinations }

        let parts = Set(source.split(separator: "/").map(String.init))
        if parts.contains("claude") {
            return [".claude/skills"]
        }
        if parts.contains("cursor") {
            return [".cursor/skills"]
        }
        return Self.skillDestinations
    }

    private func rulesDestinations(forSource source: String, schema: RegistrySchema) -> [String] {
        guard schema == .legacySharedGlobal else { return Self.rulesDestinations }

        let parts = Set(source.split(separator: "/").map(String.init))
        if parts.contains("claude") {
            return [".claude/rules"]
        }
        if parts.contains("cursor") {
            return [".cursor/rules"]
        }
        return Self.rulesDestinations
    }

    private func detectSchema(registryRoot: URL, fileManager: FileManager) -> RegistrySchema {
        let sharedGlobal = registryRoot.appendingPathComponent("shared-global")
        let legacyClaude = sharedGlobal.appendingPathComponent("claude").path
        let legacyCursor = sharedGlobal.appendingPathComponent("cursor").path
        if fileManager.fileExists(atPath: legacyClaude) || fileManager.fileExists(atPath: legacyCursor) {
            return .legacySharedGlobal
        }
        return .teamBased
    }
}
