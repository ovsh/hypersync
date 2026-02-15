import Foundation

struct SyncSummary {
    let registryPath: String
    let targetCount: Int
    let mappingCount: Int
}

struct SyncService {
    private let gitSync = GitSync()
    private let manifestLoader = ManifestLoader()
    private let fileSyncEngine = FileSyncEngine()

    func run(settings: AppSettings, logger: @escaping (LogLevel, String) -> Void) throws -> SyncSummary {
        let registryRoot = try gitSync.prepareRegistry(settings: settings, logger: logger)
        let manifest = try manifestLoader.load(registryRoot: registryRoot, scanRoots: settings.scanRoots, logger: logger)
        logger(.info, "Loaded manifest v\(manifest.version) with \(manifest.mappings.count) mappings")

        let result = try fileSyncEngine.apply(
            manifest: manifest,
            registryRoot: registryRoot,
            logger: logger
        )

        return SyncSummary(
            registryPath: registryRoot.path,
            targetCount: result.targetCount,
            mappingCount: result.mappingCount
        )
    }
}
