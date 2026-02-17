import Foundation
import XCTest
@testable import Hypersync

final class SyncPlannerTests: XCTestCase {
    func testAutoModeUsesDiscoveredRootsWhenDefaultEveryoneMissing() throws {
        let registryRoot = try makeTempRegistry()
        defer { try? FileManager.default.removeItem(at: registryRoot) }

        try FileManager.default.createDirectory(
            at: registryRoot.appendingPathComponent("engineering/skills"),
            withIntermediateDirectories: true
        )

        let settings = AppSettings(
            remoteGitURL: "https://github.com/acme/config.git",
            scanMode: .auto,
            scanRoots: ["everyone"],
            checkoutPath: registryRoot.path,
            autoSyncEnabled: false,
            autoSyncIntervalMinutes: 60
        )

        let plan = try SyncPlanner().plan(settings: settings, registryRoot: registryRoot) { _, _ in }
        XCTAssertEqual(plan.selectedRoots, ["engineering"])
        XCTAssertTrue(plan.missingConfiguredRoots.isEmpty)
    }

    func testExplicitModeFailsWhenConfiguredRootsAreMissing() throws {
        let registryRoot = try makeTempRegistry()
        defer { try? FileManager.default.removeItem(at: registryRoot) }

        try FileManager.default.createDirectory(
            at: registryRoot.appendingPathComponent("engineering/skills"),
            withIntermediateDirectories: true
        )

        let settings = AppSettings(
            remoteGitURL: "https://github.com/acme/config.git",
            scanMode: .explicit,
            scanRoots: ["everyone"],
            checkoutPath: registryRoot.path,
            autoSyncEnabled: false,
            autoSyncIntervalMinutes: 60
        )

        XCTAssertThrowsError(try SyncPlanner().plan(settings: settings, registryRoot: registryRoot) { _, _ in }) { error in
            guard case SyncPlannerError.noUsableScanRoots = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testAutoModeFallsBackToTopLevelSkillsDirectory() throws {
        let registryRoot = try makeTempRegistry()
        defer { try? FileManager.default.removeItem(at: registryRoot) }

        try FileManager.default.createDirectory(
            at: registryRoot.appendingPathComponent("skills"),
            withIntermediateDirectories: true
        )

        let settings = AppSettings(
            remoteGitURL: "https://github.com/acme/config.git",
            scanMode: .auto,
            scanRoots: ["everyone"],
            checkoutPath: registryRoot.path,
            autoSyncEnabled: false,
            autoSyncIntervalMinutes: 60
        )

        let plan = try SyncPlanner().plan(settings: settings, registryRoot: registryRoot) { _, _ in }
        XCTAssertEqual(plan.selectedRoots, ["."])
    }

    private func makeTempRegistry() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("hypersync-syncplanner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
