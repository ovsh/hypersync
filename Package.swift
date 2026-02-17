// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Hypersync",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Hypersync", targets: ["Hypersync"])
    ],
    dependencies: [
        .package(url: "https://github.com/PostHog/posthog-ios", from: "3.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0")
    ],
    targets: [
        .executableTarget(
            name: "Hypersync",
            dependencies: [
                .product(name: "PostHog", package: "posthog-ios"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources",
            resources: [
                .copy("Resources/AppIcon.png")
            ],
            swiftSettings: [
                // Workaround for Swift 6.0.x compiler crash in release builds:
                // "Failed to reconstruct type for StateObject<AppState>"
                // https://github.com/swiftlang/swift/issues/73970
                .unsafeFlags(["-Xfrontend", "-disable-round-trip-debug-types"],
                             .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "HypersyncXCUITests",
            dependencies: ["Hypersync"],
            path: "Tests/HypersyncXCUITests"
        )
    ]
)
