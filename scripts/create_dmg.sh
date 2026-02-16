#!/usr/bin/env bash
set -euo pipefail

# Creates a polished DMG with drag-to-Applications layout.
# Usage: ./scripts/create_dmg.sh [app_path] [dmg_path]
#   app_path  defaults to dist/Hypersync.app
#   dmg_path  defaults to dist/Hypersync-MacOS.dmg

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/Hypersync.app}"
DMG_PATH="${2:-$ROOT_DIR/dist/Hypersync-MacOS.dmg}"
VOL_NAME="Hypersync"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: app bundle not found at $APP_PATH" >&2
  exit 1
fi

echo "Creating DMG from $APP_PATH..."

# Clean any previous DMG
rm -f "$DMG_PATH"

# Eject any existing volume with the same name
if [[ -d "/Volumes/$VOL_NAME" ]]; then
  hdiutil detach "/Volumes/$VOL_NAME" -force 2>/dev/null || true
  sleep 1
fi

# Create temporary writable DMG (200 MB is plenty)
TEMP_DIR="$(mktemp -d)"
TEMP_DMG="$TEMP_DIR/temp.dmg"

hdiutil create -size 200m -fs HFS+ -volname "$VOL_NAME" "$TEMP_DMG" -quiet

# Mount writable DMG and capture the mount point
MOUNT_OUTPUT=$(hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen)
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/.*' | head -1)
DEVICE=$(echo "$MOUNT_OUTPUT" | head -1 | awk '{print $1}')

# Copy app and create Applications symlink
ditto "$APP_PATH" "$MOUNT_POINT/Hypersync.app"
ln -s /Applications "$MOUNT_POINT/Applications"

# Set Finder window properties for the classic drag-to-Applications layout
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOL_NAME"
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
APPLESCRIPT

# Ensure writes are flushed
sync
sleep 1

# Unmount
hdiutil detach "$DEVICE" -quiet 2>/dev/null || hdiutil detach "$DEVICE" -force -quiet 2>/dev/null || true
sleep 1

# Convert to compressed read-only DMG
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" -quiet

# Clean up
rm -rf "$TEMP_DIR"

echo "DMG created: $DMG_PATH"
