# Hypersync

Menu-bar macOS app that keeps your team's AI coding tools configured with shared skills and rules. Connect a GitHub repo, click Sync, and every tool stays in sync.

## Install

1. Download **Hypersync-MacOS.zip** from the [latest release](../../releases/latest)
2. Unzip and move **Hypersync.app** to `/Applications`
3. Open Hypersync — it lives in your menu bar
4. Connect an existing repo or **one-click create** a new one from the template, then hit **Sync**

> Requires macOS 14+.

## What it syncs

Hypersync auto-discovers `skills/` and `rules/` directories from your registry repo and merges them into every supported tool:

| Tool | Skills | Rules |
|------|:------:|:-----:|
| Agents (Codex, Windsurf, Gemini CLI, ...) | `~/.agents/skills` | — |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `~/.claude/skills` | `~/.claude/rules` |
| [Cursor](https://cursor.sh) | `~/.cursor/skills` | `~/.cursor/rules` |
| [OpenCode](https://opencode.ai) | `~/.config/opencode/skills` | — |

Any tool that reads from `~/.agents/` works out of the box. Need another path? Add it to `ManifestLoader.swift`.

## Features

- **One-click sync** from the menu bar
- **Skills browser** — browse Team, Local, and Playground skills
- **Playground skills** — try out skills from teammates before promoting to team
- **Auto sync** — periodic background sync on a configurable interval
- **Onboarding wizard** — guided setup with GitHub CLI integration
- **Auto-update** — checks GitHub Releases and self-updates in place
- **Launch at login** — optional, via macOS Login Items

## Configuration

| Setting | Description |
|---|---|
| **Repository URL** | GitHub repo containing your shared config (HTTPS or SSH) |
| **Scan mode** | `Auto` (recommended) syncs all discovered team roots; `Selected` syncs only configured roots. |
| **Teams** | Team folders used in `Selected` mode. |
| **Auto sync** | Enable periodic sync with configurable interval |

## Building from source

Requires Xcode 16+ (Swift 6) and macOS 14+.

```bash
# Debug build
swift build

# Release build + app bundle (ad-hoc signed, no notarization)
CODESIGN_IDENTITY="-" SKIP_NOTARIZE=1 ./scripts/package_app.sh
```

The app bundle lands at `dist/Hypersync.app`.

### Signed + notarized (for distribution)

```bash
# One-time: store notarization credentials
xcrun notarytool store-credentials "HyperSync" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "YOUR_APP_SPECIFIC_PASSWORD"

# Build, sign, notarize
VERSION=0.3.0 ./scripts/package_app.sh
```

### Install locally

```bash
./scripts/install_app.sh
```

## Releasing

```bash
./scripts/release.sh v0.3.0
```

Tags the commit and pushes. GitHub Actions builds, signs, notarizes, and publishes a release with DMG + ZIP.

> **CI note:** Uses the Xcode-bundled Swift toolchain (not the standalone swift.org toolchain).

## E2E testing

### Smoke test (AppleScript/UI scripting)

```bash
./scripts/test_e2e_smoke.sh
```

This validates:
- Skills window appears on launch
- onboarding appears on first run
- closing Skills and reopening brings it back

Requires Terminal to be enabled in **System Settings > Privacy & Security > Accessibility**.

### XCUITests

```bash
./scripts/run_xcuitests.sh
```

The script builds an ad-hoc app with a test bundle id and runs the `HypersyncXCUITests`
SwiftPM test target against an isolated app-support directory.

It validates:
- `HypersyncXCUITests.testLaunchShowsSkillsWindow`
- `HypersyncXCUITests.testFirstRunShowsOnboarding`
- `HypersyncXCUITests.testReopenAfterClosingSkillsWindow`

Requires Terminal to be enabled in **System Settings > Privacy & Security > Accessibility**.

## Data

| Item | Path |
|---|---|
| Settings | `~/Library/Application Support/HyperSync/settings.json` |
| Logs | `~/Library/Application Support/HyperSync/sync.log` |
| Registry | `~/Library/Application Support/HyperSync/registry` |

## License

MIT
