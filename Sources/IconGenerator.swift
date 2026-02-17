import AppKit
import SwiftUI

@MainActor
enum IconGenerator {
    /// Safe SPM resource bundle lookup — returns nil instead of crashing.
    /// `Bundle.module` calls `fatalError` when the resource bundle is missing
    /// (e.g. in a packaged .app where the SPM bundle wasn't copied).
    private static let spmResourceBundle: Bundle? = {
        let bundleName = "Hypersync_Hypersync"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle(for: NSApplication.self).resourceURL,
        ]
        for candidate in candidates {
            if let bundleURL = candidate?.appendingPathComponent(bundleName + ".bundle"),
               let bundle = Bundle(url: bundleURL) {
                return bundle
            }
        }
        return nil
    }()

    /// Loads the bundled AppIcon.png and returns its data.
    static func renderAppIconPNG() -> Data? {
        // Try the app bundle's Resources directory first (.app/Contents/Resources/)
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            return data
        }

        // Try SPM resource bundle (works with swift run / development)
        if let url = spmResourceBundle?.url(forResource: "AppIcon", withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            return data
        }

        // Fallback: load from Sources/Resources relative to executable (CLI usage)
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let sourceRoot = execURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fallbackURL = sourceRoot.appendingPathComponent("Sources/Resources/AppIcon.png")
        return try? Data(contentsOf: fallbackURL)
    }

    /// Generates an .icns file from the bundled icon and writes it to the given path.
    @discardableResult
    static func generateICNS(to outputPath: String) -> Bool {
        guard let pngData = renderAppIconPNG() else {
            print("IconGenerator: failed to load icon PNG")
            return false
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hypersync-iconset-\(ProcessInfo.processInfo.processIdentifier)")
        let iconsetDir = tempDir.appendingPathComponent("AppIcon.iconset")

        do {
            try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
        } catch {
            print("IconGenerator: failed to create iconset dir: \(error)")
            return false
        }

        let sizes: [(String, Int)] = [
            ("icon_16x16", 16),
            ("icon_16x16@2x", 32),
            ("icon_32x32", 32),
            ("icon_32x32@2x", 64),
            ("icon_128x128", 128),
            ("icon_128x128@2x", 256),
            ("icon_256x256", 256),
            ("icon_256x256@2x", 512),
            ("icon_512x512", 512),
            ("icon_512x512@2x", 1024),
        ]

        guard let sourceImage = NSImage(data: pngData) else {
            print("IconGenerator: failed to load source image from PNG data")
            return false
        }

        for (name, px) in sizes {
            let dest = iconsetDir.appendingPathComponent("\(name).png")
            let resized = resizeImage(sourceImage, to: NSSize(width: px, height: px))

            guard let tiffData = resized.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiffData),
                  let png = rep.representation(using: .png, properties: [:])
            else {
                print("IconGenerator: failed to create \(name).png")
                return false
            }

            do {
                try png.write(to: dest)
            } catch {
                print("IconGenerator: failed to write \(name).png: \(error)")
                return false
            }
        }

        // Run iconutil to create .icns
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconsetDir.path, "-o", outputPath]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("IconGenerator: iconutil failed: \(error)")
            return false
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)

        return process.terminationStatus == 0
    }

    private static func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size))
        newImage.unlockFocus()
        return newImage
    }
}
