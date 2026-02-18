import Foundation
import XCTest
@testable import Hypersync

final class ManifestLoaderTests: XCTestCase {
    func testLegacySharedGlobalLayoutUsesToolSpecificDestinations() throws {
        let registryRoot = try makeTempRegistry()
        defer { try? FileManager.default.removeItem(at: registryRoot) }

        try FileManager.default.createDirectory(
            at: registryRoot.appendingPathComponent("shared-global/claude/skills"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: registryRoot.appendingPathComponent("shared-global/claude/rules"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: registryRoot.appendingPathComponent("shared-global/cursor/skills-cursor"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: registryRoot.appendingPathComponent("shared-global/cursor/rules"),
            withIntermediateDirectories: true
        )

        let manifest = try ManifestLoader().load(
            registryRoot: registryRoot,
            scanRoots: ["shared-global"],
            logger: { _, _ in }
        )

        let pairs = Set(manifest.mappings.map { "\($0.source)->\($0.destination)" })

        XCTAssertTrue(pairs.contains("shared-global/claude/skills->.claude/skills"))
        XCTAssertTrue(pairs.contains("shared-global/claude/rules->.claude/rules"))
        XCTAssertTrue(pairs.contains("shared-global/cursor/skills-cursor->.cursor/skills"))
        XCTAssertTrue(pairs.contains("shared-global/cursor/rules->.cursor/rules"))

        XCTAssertFalse(pairs.contains("shared-global/claude/skills->.cursor/skills"))
        XCTAssertFalse(pairs.contains("shared-global/cursor/rules->.claude/rules"))
    }

    private func makeTempRegistry() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("hypersync-manifestloader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
