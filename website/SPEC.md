# Hypersync Landing Page — Redesign Spec

## Core Insight

Visitors arrive via a shared link. They already heard a one-liner from whoever sent it. The page's job is **credibility** — prove this is a real, maintained, trustworthy app — and give them a download button.

## What the page must communicate in 5 seconds

**"Oh, this solves my problem."**

The problem: sharing AI skills/rules with teammates is manual, and keeping them updated over time is worse.

## Constraints

- **Single viewport** — no scrolling required
- **One screenshot** — real, settings window (wider macOS window shape), in a macOS window mockup frame
- **Side-by-side layout** — text left, screenshot right
- **Pain-first headline** — name Cursor and Claude Code explicitly
- **CTA** → GitHub releases (latest)
- **Credibility signals** — open source badge, MIT license, GitHub link, the screenshot itself

## 3 Variants

Each variant is a separate page file. Same tech stack, same brand palette (indigo), same `layout.tsx` and `globals.css`. Different layout, copy density, and visual treatment.

---

### Variant A — "Minimal"

**Layout:** Centered single-column. Headline, one-line subtitle, CTA button, trust strip.
**Copy:** Tagline only — no explanation paragraph. Let the app name + headline + CTA do the work.
**Screenshot:** None. Pure text + download. Smallest possible page.
**Trust:** Inline badges below CTA: `Open Source · MIT License · macOS`

**Hierarchy:**
```
[Nav: logo + GitHub + Download pill]

            [App icon]
     [Pain-first headline]
      [One-line tagline]
   [Download CTA]  [GitHub link]
  Open Source · MIT · macOS
```

---

### Variant B — "Side-by-Side"

**Layout:** Split hero — text left (60%), screenshot right (40%). Classic SaaS landing.
**Copy:** Headline + one supporting sentence clarifying the mechanism.
**Screenshot:** Settings window in macOS mockup frame, slight bob animation.
**Trust:** Small footer strip at bottom: GitHub link, MIT License, "Open Source".

**Hierarchy:**
```
[Nav: logo + GitHub + Download pill]

[Left side]                    [Right side]
  [App icon + badge]            [macOS window mockup]
  [Pain-first headline]         [Screenshot inside]
  [One sentence subtitle]
  [Download CTA] [GitHub]

─────────────────────────────────
GitHub · MIT License · Open Source
```

---

### Variant C — "Screenshot-Forward"

**Layout:** Split hero — text left (45%), screenshot right (55%). Screenshot is dominant, slightly larger and overlapping the right edge.
**Copy:** Headline + two sentences. First: what it does. Second: the "stays updated" angle.
**Screenshot:** Settings window, larger, with subtle shadow and float. Visual anchor of the page.
**Trust:** Badges integrated into the left column below CTAs: `Open Source · MIT License` as styled pills.

**Hierarchy:**
```
[Nav: logo + GitHub + Download pill]

[Left side]                         [Right side — larger]
  [Badge: "macOS app"]               [macOS window mockup — oversized]
  [Pain-first headline]              [Screenshot, floating with shadow]
  [Two-sentence subtitle]
  [Download CTA] [GitHub link]
  [Open Source pill] [MIT pill]
```

---

## Headline Candidates (pain-first, names tools)

Pick one per variant or test:
- "Share Cursor and Claude Code rules across your team"
- "One config for Cursor, Claude Code, and every AI tool"
- "Keep your team's Cursor and Claude Code skills in sync"

## Subtitle Candidates

**One-liner (Variant A/B):**
- "Hypersync installs shared skills from a GitHub repo into every teammate's tools."

**Two sentences (Variant C):**
- "Hypersync installs shared skills and rules from a GitHub repo into Cursor, Claude Code, and more. Update once, everyone gets it."

## File Structure

```
website/app/
├── layout.tsx        # Shared (unchanged)
├── globals.css       # Shared (unchanged)
├── page.tsx          # Variant B (default — side-by-side, the balanced option)
├── a/page.tsx        # Variant A (minimal)
└── c/page.tsx        # Variant C (screenshot-forward)
```

## Brand / Visual (unchanged from current)

- Indigo palette: `#4A4AF4` primary, `#2E2EC2` hover, `#6B6BF7` gradients
- Fonts: JetBrains Mono (display) + DM Sans (body)
- Glassmorphism nav, floating clouds, film grain, dot grid
- macOS window mockup with traffic light dots
