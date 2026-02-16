import SwiftUI

// MARK: - Card Container

struct HyperCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.background.opacity(0.55))
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Card Header

struct CardHeader: View {
    let icon: HyperIcon
    let title: String

    var body: some View {
        HStack(spacing: 7) {
            HyperIconView(icon: icon, size: 13, color: Brand.indigoMid)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Sync Now Button

struct SyncNowButton: View {
    let isSyncing: Bool
    var isAwaitingAuth: Bool = false
    var setupCheckFailed: Bool = false
    var hasRepo: Bool = true
    let action: () -> Void
    @State private var isHovered = false

    private var isDisabled: Bool { isSyncing }

    private enum Mode {
        case syncNow, syncing, awaitingAuth, setupGitHub, openSettings
    }

    private var mode: Mode {
        if isSyncing { return .syncing }
        if isAwaitingAuth { return .awaitingAuth }
        if !hasRepo { return .openSettings }
        if setupCheckFailed { return .setupGitHub }
        return .syncNow
    }

    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                HStack {
                    Spacer()
                    switch mode {
                    case .syncing:
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                        Text("Syncing\u{2026}")
                    case .awaitingAuth:
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                        Text("Sync Now")
                    case .setupGitHub:
                        Image(systemName: "key")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.trailing, 2)
                        Text("Setup GitHub")
                    case .openSettings:
                        Image(systemName: "gearshape")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.trailing, 2)
                        Text("Open Settings")
                    case .syncNow:
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.trailing, 2)
                        Text("Sync Now")
                    }
                    Spacer()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isDisabled ? Color.secondary : Color.white)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            isDisabled
                                ? AnyShapeStyle(Color.secondary.opacity(0.15))
                                : AnyShapeStyle(
                                    LinearGradient(
                                        colors: [
                                            isHovered ? Brand.indigoDim : Brand.indigo,
                                            Brand.indigoDim,
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .onHover { hovering in
                isHovered = hovering
            }

            if isAwaitingAuth {
                Text("Complete login in Terminal, then click Sync")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Field Label

struct FieldLabel<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.3)
            content
        }
    }
}
