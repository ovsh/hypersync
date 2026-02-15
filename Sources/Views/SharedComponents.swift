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
