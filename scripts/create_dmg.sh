#!/usr/bin/env bash
set -euo pipefail

# Creates a polished DMG with drag-to-Applications layout.
# Usage: ./scripts/create_dmg.sh [app_path] [dmg_path]
#   app_path  defaults to dist/Hypersync.app
#   dmg_path  defaults to dist/Hypersync-MacOS.dmg
#
# Optional env vars:
#   DMG_SIZE_MB=<int>            size of temporary writable image (default: 200)
#   DMG_USE_FINDER_LAYOUT=auto   auto|1|0 (default auto; auto disables Finder in CI)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/Hypersync.app}"
DMG_PATH="${2:-$ROOT_DIR/dist/Hypersync-MacOS.dmg}"
VOL_NAME="Hypersync"
DMG_SIZE_MB="${DMG_SIZE_MB:-200}"
DMG_USE_FINDER_LAYOUT="${DMG_USE_FINDER_LAYOUT:-auto}"

if [[ "$DMG_USE_FINDER_LAYOUT" == "auto" ]]; then
  if [[ -n "${CI:-}" ]]; then
    DMG_USE_FINDER_LAYOUT="0"
  else
    DMG_USE_FINDER_LAYOUT="1"
  fi
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: app bundle not found at $APP_PATH" >&2
  exit 1
fi

if ! [[ "$DMG_SIZE_MB" =~ ^[0-9]+$ ]]; then
  echo "Error: DMG_SIZE_MB must be an integer (got: $DMG_SIZE_MB)" >&2
  exit 1
fi

log() {
  echo "[create_dmg] $*"
}

retry() {
  local attempts="$1"
  local sleep_seconds="$2"
  shift 2

  local i=1
  while true; do
    if "$@"; then
      return 0
    fi
    if (( i >= attempts )); then
      return 1
    fi
    log "Attempt ${i}/${attempts} failed. Retrying in ${sleep_seconds}s: $*"
    sleep "$sleep_seconds"
    ((i += 1))
  done
}

DEVICE=""
MOUNT_POINT=""
TEMP_DIR=""
TEMP_DMG=""

cleanup() {
  # Best-effort detach; we intentionally ignore failures here.
  if [[ -n "$DEVICE" ]]; then
    hdiutil detach "$DEVICE" >/dev/null 2>&1 || hdiutil detach "$DEVICE" -force >/dev/null 2>&1 || true
  fi
  if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1 || true
  fi
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

detach_existing_volume() {
  if [[ -d "/Volumes/$VOL_NAME" ]]; then
    hdiutil detach "/Volumes/$VOL_NAME" >/dev/null 2>&1 || hdiutil detach "/Volumes/$VOL_NAME" -force >/dev/null 2>&1
  fi
}

attach_temp_dmg() {
  local mount_output
  mount_output="$(hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen)"

  DEVICE="$(echo "$mount_output" | awk '/^\/dev\// {print $1; exit}')"
  MOUNT_POINT="$(echo "$mount_output" | awk -F'\t' '/\/Volumes\// {print $NF; exit}')"

  [[ -n "$DEVICE" && -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]
}

configure_finder_layout() {
  osascript - "$VOL_NAME" <<'APPLESCRIPT'
on run argv
    set volName to item 1 of argv
    tell application "Finder"
        tell disk volName
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {200, 200, 700, 500}
            set theViewOptions to the icon view options of container window
            set arrangement of theViewOptions to not arranged
            set icon size of theViewOptions to 80
            set position of item "Hypersync.app" of container window to {120, 140}
            set position of item "Applications" of container window to {380, 140}
            close
            open
            update without registering applications
            delay 1
            close
        end tell
    end tell
end run
APPLESCRIPT
}

detach_device() {
  [[ -n "$DEVICE" ]] || return 0
  hdiutil detach "$DEVICE" >/dev/null 2>&1 || hdiutil detach "$DEVICE" -force >/dev/null 2>&1
}

log "Creating DMG from $APP_PATH"

# Clean any previous DMG
rm -f "$DMG_PATH"

# Eject any existing volume with the same name
retry 3 1 detach_existing_volume || true

# Create temporary writable DMG.
TEMP_DIR="$(mktemp -d -t hypersync_dmg)"
TEMP_DMG="$TEMP_DIR/temp.dmg"
hdiutil create \
  -size "${DMG_SIZE_MB}m" \
  -fs HFS+ \
  -volname "$VOL_NAME" \
  "$TEMP_DMG"

# Mount writable DMG and capture the mount point.
retry 3 2 attach_temp_dmg

# Copy app and create Applications symlink
ditto "$APP_PATH" "$MOUNT_POINT/Hypersync.app"
ln -sfn /Applications "$MOUNT_POINT/Applications"

if [[ "$DMG_USE_FINDER_LAYOUT" == "1" ]]; then
  # Finder automation is visually nice but flaky on CI runners; if it fails we
  # still ship a functional DMG instead of failing the entire release.
  if ! retry 3 2 configure_finder_layout; then
    log "Warning: Finder layout customization failed; continuing with default icon layout."
  fi
else
  log "Skipping Finder layout customization (DMG_USE_FINDER_LAYOUT=$DMG_USE_FINDER_LAYOUT)."
fi

# Ensure writes are flushed
sync
sleep 1

# Unmount
retry 5 1 detach_device
sleep 1

# Convert to compressed read-only DMG
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Error: DMG was not created at $DMG_PATH" >&2
  exit 1
fi

log "DMG created: $DMG_PATH"
