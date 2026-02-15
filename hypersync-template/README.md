# HyperSync Registry Template

This is a template repository for [HyperSync](https://github.com/AugmentedAI/hypersync) -- a macOS menu-bar app that syncs shared AI agent rules and skills across your team.

HyperSync distributes your team's config to **Cursor, Claude Code, Codex, Kiro, Roo, Windsurf**, and the shared `~/.agents/` directory -- all from a single Git repo.

## Getting Started

1. Click **Use this template** on GitHub to create your team's config repo
2. Edit the files under `shared-global/` to add your team's rules and skills
3. Commit and push to `main`
4. Share the repo URL with your team -- they'll enter it in HyperSync's setup wizard

## Structure

```
shared-global/
  skills/          # Shared agent skills (synced to all tools)
  rules/           # Shared rules (synced to Cursor, Claude, Roo, Windsurf)
    .cursorrules   # Cursor-specific rules file
    team-rules.md  # Universal team rules
```

## Destinations

| Content | Destinations |
|---------|-------------|
| `skills/` | `~/.cursor/skills`, `~/.claude/skills`, `~/.codex/skills`, `~/.kiro/skills`, `~/.roo/skills`, `~/.agents/skills` |
| `rules/` | `~/.cursor/rules`, `~/.claude/rules`, `~/.roo/rules`, `~/.windsurf/rules` |

## Adding Content

Add files directly to the appropriate folders. HyperSync will sync them on the next pull.

For example, to add a new skill:
1. Create a file in `shared-global/skills/my-skill.md`
2. Commit and push
3. Team members get it on their next sync (auto-syncs every 60 minutes by default)
4. The skill appears in all agent tool directories listed above
