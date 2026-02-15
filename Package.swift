// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HyperSyncMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HyperSyncMac", targets: ["HyperSyncMac"])
    ],
    dependencies: [
        .package(url: "https://github.com/PostHog/posthog-ios", from: "3.0.0")
    ],
    targets: [
        .executableTarget(
            name: "HyperSyncMac",
            dependencies: [
                .product(name: "PostHog", package: "posthog-ios")
            ],
            path: "Sources",
            swiftSettings: [
                // Workaround for Swift 6.0.x compiler crash in release builds:
                // "Failed to reconstruct type for StateObject<AppState>"
                // https://github.com/swiftlang/swift/issues/73970
                .unsafeFlags(["-Xfrontend", "-disable-round-trip-debug-types"],
                             .when(configuration: .release))
            ]
        )
    ]
)
