import Foundation

enum ManifestLoaderError: LocalizedError {
    case noMappings
    case scanRootMissing(String)

    var errorDescription: String? {
        switch self {
        case .noMappings:
            return "Scan found no skills/ or rules/ directories under the configured scan roots."
        case .scanRootMissing(let path):
            return "Scan root does not exist: \(path)"
        }
    }
}

struct ManifestLoader {

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
        var mappings: [MappingItem] = []

        for root in scanRoots {
            let rootURL = registryRoot.appendingPathComponent(root).standardizedFileURL
            guard fileManager.fileExists(atPath: rootURL.path) else {
                throw ManifestLoaderError.scanRootMissing(rootURL.path)
            }
            logger(.info, "Scanning \(root)/ for skills and rules directories")
            let found = scanForContent(at: rootURL, relativeTo: registryRoot, fileManager: fileManager)
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
        at directory: URL, relativeTo registryRoot: URL, fileManager: FileManager
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
            let registryPath = registryRoot.path.hasSuffix("/") ? registryRoot.path : registryRoot.path + "/"
            let relativePath = child.path.replacingOccurrences(of: registryPath, with: "")

            if name == "skills" {
                // skills/ → merge into all agent tool directories
                for dest in Self.skillDestinations {
                    results.append(MappingItem(source: relativePath, destination: dest, kind: .directory, strategy: .merge))
                }
                // Do NOT recurse into skills/ — its children are individual skills, not more scan targets
            } else if name == "rules" {
                // rules/ → merge into all agent tool directories that support rules
                for dest in Self.rulesDestinations {
                    results.append(MappingItem(source: relativePath, destination: dest, kind: .directory, strategy: .merge))
                }
                // Do NOT recurse into rules/
            } else if name == "playground" {
                // playground/ holds opt-in experimental skills — skip auto-sync
            } else {
                // Not a known content dir — recurse deeper
                results.append(contentsOf: scanForContent(at: child, relativeTo: registryRoot, fileManager: fileManager))
            }
        }

        return results
    }
}
