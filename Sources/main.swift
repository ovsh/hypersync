import SwiftUI

// Handle --generate-icon CLI flag before launching the app
if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--generate-icon" {
    let outputPath = CommandLine.arguments[2]
    // main.swift top-level code runs on MainActor in Swift 6
    if IconGenerator.generateICNS(to: outputPath) {
        print("Icon written to \(outputPath)")
        exit(0)
    } else {
        fputs("Failed to generate icon\n", stderr)
        exit(1)
    }
}

HyperSyncMacApp.main()
