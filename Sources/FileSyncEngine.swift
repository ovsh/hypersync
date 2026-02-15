import Foundation

struct FileSyncSummary {
    var targetCount: Int
    var mappingCount: Int
}

enum FileSyncError: LocalizedError {
    case sourceMissing(String)
    case destinationEscapesHome(String)
    case destinationOutsideAllowedScopes(String)
    case unsupportedStrategy(String)
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .sourceMissing(let path):
            return "Source path from manifest does not exist: \(path)"
        case .destinationEscapesHome(let path):
            return "Destination escapes home directory: \(path)"
        case .destinationOutsideAllowedScopes(let path):
            return "Destination must be under a supported agent directory. Invalid path: \(path)"
        case .unsupportedStrategy(let strategy):
            return "Unsupported mapping strategy: \(strategy)"
        case .copyFailed(let reason):
            return "Failed applying mapping: \(reason)"
        }
    }
}

struct FileSyncEngine {
    func apply(
        manifest: Manifest,
        registryRoot: URL,
        logger: @escaping (LogLevel, String) -> Void
    ) throws -> FileSyncSummary {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.standardizedFileURL

        logger(.info, "Applying \(manifest.mappings.count) mappings into global user config")

        for mapping in manifest.mappings {
            try apply(
                mapping: mapping,
                registryRoot: registryRoot,
                homeRoot: home,
                fileManager: fileManager,
                logger: logger
            )
        }

        return FileSyncSummary(targetCount: 1, mappingCount: manifest.mappings.count)
    }

    private func apply(
        mapping: MappingItem,
        registryRoot: URL,
        homeRoot: URL,
        fileManager: FileManager,
        logger: @escaping (LogLevel, String) -> Void
    ) throws {
        let sourceURL = registryRoot.appendingPathComponent(mapping.source).standardizedFileURL
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw FileSyncError.sourceMissing(sourceURL.path)
        }

        let destinationURL = homeRoot.appendingPathComponent(mapping.destination).standardizedFileURL
        try ensureDestinationAllowed(homeRoot: homeRoot, destination: destinationURL)

        do {
            switch mapping.strategy {
            case .replace:
                try applyReplace(source: sourceURL, destination: destinationURL, kind: mapping.kind, fileManager: fileManager)
            case .merge:
                try applyMerge(source: sourceURL, destination: destinationURL, kind: mapping.kind, fileManager: fileManager, logger: logger)
            }

            logger(.info, "Synced \(mapping.source) -> ~/\(mapping.destination) [\(mapping.strategy.rawValue)]")
        } catch let error as FileSyncError {
            throw error
        } catch {
            throw FileSyncError.copyFailed(error.localizedDescription)
        }
    }

    /// Nuke destination and replace entirely with source. Only safe for paths you fully own.
    private func applyReplace(
        source: URL, destination: URL, kind: MappingKind, fileManager: FileManager
    ) throws {
        let parent = destination.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    /// Overlay source into destination — update/add managed files, never delete unmanaged ones.
    private func applyMerge(
        source: URL, destination: URL, kind: MappingKind,
        fileManager: FileManager, logger: @escaping (LogLevel, String) -> Void
    ) throws {
        switch kind {
        case .file:
            // For single files, merge == overwrite that one file
            let parent = destination.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parent.path) {
                try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            }
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)

        case .directory:
            // Walk source tree, copy each file into destination, creating subdirs as needed
            try mergeDirectory(source: source, destination: destination, fileManager: fileManager, logger: logger)
        }
    }

    /// Recursively copy every item from source into destination without removing
    /// files that only exist in the destination.
    private func mergeDirectory(
        source: URL, destination: URL,
        fileManager: FileManager, logger: @escaping (LogLevel, String) -> Void
    ) throws {
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }

        let children = try fileManager.contentsOfDirectory(
            at: source, includingPropertiesForKeys: [.isDirectoryKey], options: []
        )

        let ignoredNames: Set<String> = [".DS_Store", ".git", ".gitkeep"]

        for child in children {
            let name = child.lastPathComponent
            guard !ignoredNames.contains(name) else { continue }
            let destChild = destination.appendingPathComponent(name)

            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDir {
                try mergeDirectory(source: child, destination: destChild, fileManager: fileManager, logger: logger)
            } else {
                // Overwrite existing file or add new one
                if fileManager.fileExists(atPath: destChild.path) {
                    try fileManager.removeItem(at: destChild)
                }
                try fileManager.copyItem(at: child, to: destChild)
            }
        }
    }

    private func ensureDestinationAllowed(homeRoot: URL, destination: URL) throws {
        let homePath = homeRoot.path.hasSuffix("/") ? homeRoot.path : homeRoot.path + "/"
        let destinationPath = destination.path

        if !destinationPath.hasPrefix(homePath) {
            throw FileSyncError.destinationEscapesHome(destination.path)
        }

        let relativePath = String(destinationPath.dropFirst(homePath.count))
        let isAllowed = ManifestLoader.allowedPrefixes.contains { prefix in
            relativePath.hasPrefix("\(prefix)/") || relativePath == prefix
        }
        guard isAllowed else {
            throw FileSyncError.destinationOutsideAllowedScopes(destination.path)
        }
    }
}
