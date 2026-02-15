#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Hypersync.app"
EXECUTABLE_NAME="HyperSyncMac"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME"
TARGET_DIR="${TARGET_DIR:-$HOME/Applications}"
TARGET_APP="$TARGET_DIR/$APP_NAME"
OPEN_AFTER_INSTALL="${OPEN_AFTER_INSTALL:-1}"

"$ROOT_DIR/scripts/package_app.sh"

# Quit any running instance before overwriting
if pgrep -x "$EXECUTABLE_NAME" >/dev/null 2>&1; then
  echo "Stopping running Hypersync..."
  pkill -x "$EXECUTABLE_NAME" || true
  sleep 1
fi

mkdir -p "$TARGET_DIR"
rsync -a --delete "$SOURCE_APP/" "$TARGET_APP/"

# Remove quarantine attribute when present
xattr -dr com.apple.quarantine "$TARGET_APP" >/dev/null 2>&1 || true

echo "Installed: $TARGET_APP"

if [[ "$OPEN_AFTER_INSTALL" == "1" ]]; then
  open "$TARGET_APP"
fi
