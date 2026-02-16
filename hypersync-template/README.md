# HyperSync Registry Template

This is a template repository for [HyperSync](https://github.com/AugmentedAI/hypersync) -- a macOS menu-bar app that syncs shared AI agent rules and skills across your team.

HyperSync distributes your team's config to **Cursor, Claude Code, Codex, Kiro, Roo, Windsurf**, and the shared `~/.agents/` directory -- all from a single Git repo.

## Getting Started

1. Click **Use this template** on GitHub to create your team's config repo
2. Edit the files under `everyone/` to add org-wide rules and skills
3. Commit and push to `main`
4. Share the repo URL with your team -- they'll enter it in HyperSync's setup wizard

## Structure

```
everyone/                    # Org-wide skills & rules (synced to everyone)
  skills/
  rules/
  playground/                # Experimental skills (opt-in)
    skills/
```

### Multi-Team Setup

Create a folder per team. Any top-level folder containing `skills/` or `rules/` is auto-discovered as a team:

```
everyone/                    # Org-wide (always synced)
  skills/
  rules/
  playground/skills/
engineering/                 # Engineering team
  skills/
  rules/
  playground/skills/
product/                     # Product team
  skills/
  rules/
  playground/skills/
CODEOWNERS                   # Governance
```

Team members select which teams to subscribe to in the HyperSync app. The `everyone/` team is always synced.

You can create teams directly from the HyperSync app using the **+** button, or by creating the folder structure manually.

## Destinations

| Content | Destinations |
|---------|-------------|
| `skills/` | `~/.cursor/skills`, `~/.claude/skills`, `~/.codex/skills`, `~/.kiro/skills`, `~/.roo/skills`, `~/.agents/skills` |
| `rules/` | `~/.cursor/rules`, `~/.claude/rules`, `~/.roo/rules`, `~/.windsurf/rules` |

## Playground Skills

Each team has a `playground/skills/` directory for experimental skills. These are **not auto-synced** -- team members opt in to specific playground skills from the HyperSync app.

To promote a playground skill to official: move it from `playground/skills/` to `skills/` via a pull request.

## Governance

Use GitHub's `CODEOWNERS` file to control who can approve changes to each team's official skills:

```
# Official skills require team lead approval
engineering/skills/    @myorg/eng-leads
engineering/rules/     @myorg/eng-leads
product/skills/        @myorg/product-leads

# Playgrounds are open to anyone
# (no CODEOWNERS entry = anyone can merge)
```

## Naming

Skill folder names must be unique across all teams you subscribe to. If two teams need a similar skill, prefix them: `eng-code-review`, `product-code-review`.
