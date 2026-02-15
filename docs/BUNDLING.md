# Bundling and Installing Hypersync

## One-command install (recommended)

```bash
cd /Users/ovsh/Documents/code/hypersync
./scripts/install_app.sh
```

This will:

- build release binary
- create `dist/Hypersync.app`
- install into `~/Applications/Hypersync.app`
- launch it

## Build bundle only

```bash
cd /Users/ovsh/Documents/code/hypersync
./scripts/package_app.sh
```

Bundle output:

- `/Users/ovsh/Documents/code/hypersync/dist/Hypersync.app`

## Reinstall after code changes

```bash
cd /Users/ovsh/Documents/code/hypersync
./scripts/install_app.sh
```

## Optional knobs

- install to custom folder:

```bash
TARGET_DIR="/Applications" ./scripts/install_app.sh
```

- skip auto-launch after install:

```bash
OPEN_AFTER_INSTALL=0 ./scripts/install_app.sh
```

## First run setup in the app

1. Click menu bar icon `Hypersync`.
2. Click `Open Settings`.
3. Fill `GitHub SSH repo` (for example: `git@github.com:your-org/agent-config.git`).
4. Click `Run Setup Check`.
5. Resolve any failed check (SSH key loaded, GitHub auth, repo access).
6. Click `Sync Now`.

## Troubleshooting

- `Permission denied (publickey)`:

```bash
ssh-add -l
ssh -T git@github.com
git ls-remote git@github.com:<org>/<repo>.git main
```

- If settings file gets into bad state, remove:

`~/Library/Application Support/HyperSync/settings.json`

Then relaunch app.
