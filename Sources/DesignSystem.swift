import AppKit
import SwiftUI

// MARK: - Brand Colors

enum Brand {
    static let indigo = Color(red: 0.29, green: 0.29, blue: 0.96)       // #4A4AF4
    static let indigoDim = Color(red: 0.18, green: 0.18, blue: 0.76)    // #2F2FC1
    static let indigoMid = Color(red: 0.66, green: 0.66, blue: 0.99)    // #A8A9FC
    static let indigoLight = Color(red: 0.90, green: 0.90, blue: 0.99)  // #E6E6FC
    static let darkBg = Color(red: 0.075, green: 0.075, blue: 0.12)     // #13131F
    static let darkBgAlt = Color(red: 0.106, green: 0.106, blue: 0.19)  // #1B1B30
}

// MARK: - Surface System

enum Surface {
    /// Main content area — nearly opaque, faintest hint of depth
    static let content = Color(.windowBackgroundColor).opacity(0.96)
    /// Header/toolbar bar — matches content surface
    static let header = Color(.windowBackgroundColor).opacity(0.96)
    /// Cards/elevated elements
    static let card = Color.gray.opacity(0.12)
}

// MARK: - Spacing Scale

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let hero: CGFloat = 48
}

// MARK: - Corner Radius

enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 10
    static let xl: CGFloat = 14
}

// MARK: - Visual Effect Bridge

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
