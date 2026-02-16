---
last_verified: 2026-02-16
status: active
source_of_truth: Sources/DesignSystem.swift
---

# Hypersync Design System

## Principles

1. **Content is king** — The main reading surface should be nearly opaque. The user's focus is on content, not their wallpaper.
2. **Depth through subtlety** — Translucency signals layering, not transparency. The sidebar is *slightly* more translucent than the main content to show it sits behind. The main content is nearly solid.
3. **No dead ends** — Every empty state must have a primary action. If there's nothing to show, show the user what to do next — big, centered, unmissable.
4. **Hero empty states** — When a surface has no content, the empty state becomes the hero. Centered vertically and horizontally. Large icon, clear heading, prominent CTA.
5. **Flat over chrome** — No disclosure triangles, bold section headers, or document icons on list items. Whitespace separates; text weight differentiates.
6. **Match surfaces** — Headers and toolbars match their parent surface. No visual seams between a header bar and its content area.

## Tokens

All tokens live in `Sources/DesignSystem.swift`.

### Brand Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `Brand.indigo` | #4A4AF4 | Primary accent, buttons, links |
| `Brand.indigoDim` | #2F2FC1 | Gradient end, pressed states |
| `Brand.indigoMid` | #A8A9FC | Secondary accent, icon tints |
| `Brand.indigoLight` | #E6E6FC | Light accent (unused in dark mode) |
| `Brand.darkBg` | #13131F | Deep background |
| `Brand.darkBgAlt` | #1B1B30 | Elevated background |

### Surfaces

| Token | Value | Usage |
|-------|-------|-------|
| `Surface.content` | `windowBackgroundColor @ 96%` | Main detail pane, skill detail, placeholder |
| `Surface.header` | `windowBackgroundColor @ 96%` | Header/toolbar bars — matches content |
| `Surface.card` | `gray @ 12%` | Card backgrounds, elevated elements |
| *Sidebar* | Native `.listStyle(.sidebar)` | macOS sidebar material (more translucent than content) |

### Translucency Hierarchy

```
Most opaque ─────────────────────────────── Most translucent
   Main content (96%)    >    Sidebar (native macOS)
   Header matches content
```

The sidebar gets its translucency from macOS `.listStyle(.sidebar)` — we don't control it directly. The main content uses `Surface.content` which is 96% opaque, making it almost solid with the faintest depth hint.

### Spacing

| Token | Value | Usage |
|-------|-------|-------|
| `Space.xs` | 4 | Tight gaps (icon-to-text) |
| `Space.sm` | 8 | Compact spacing |
| `Space.md` | 12 | Default padding |
| `Space.lg` | 16 | Section spacing |
| `Space.xl` | 24 | Content padding, hero element spacing |
| `Space.xxl` | 32 | Large section gaps |
| `Space.hero` | 48 | Hero sections |

### Corner Radius

| Token | Value | Usage |
|-------|-------|-------|
| `Radius.sm` | 6 | Buttons, small cards |
| `Radius.md` | 8 | Input fields, text editors |
| `Radius.lg` | 10 | CTA buttons, action buttons |
| `Radius.xl` | 14 | Large cards, navigation cards |

## Patterns

### Primary Action Button

```swift
Button { ... } label: {
    HStack(spacing: 6) {
        Image(systemName: "icon.name")
            .font(.system(size: 14, weight: .semibold))
        Text("Action")
            .font(.system(size: 15, weight: .semibold))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 28)
    .padding(.vertical, 14)
    .background(
        RoundedRectangle(cornerRadius: Radius.lg)
            .fill(LinearGradient(
                colors: [Brand.indigo, Brand.indigoDim],
                startPoint: .top, endPoint: .bottom))
    )
}
.buttonStyle(.plain)
```

### Detail Pane Background

```swift
.background(Surface.content)
.toolbarBackground(.hidden, for: .automatic)
.ignoresSafeArea(.container, edges: .top)
```

### Hero Empty State

Centered in full pane. Icon (40pt) + heading (20pt semibold) + subtext (14pt secondary) + CTA button. Spacing: `Space.xl` between groups, `Space.sm` between heading and subtext.
