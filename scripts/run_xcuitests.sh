#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="${APP_BUNDLE:-$ROOT_DIR/dist/Hypersync.app}"
BUNDLE_ID="${BUNDLE_ID:-com.ovsh.hypersync.ui-tests}"
BUILD_APP="${BUILD_APP:-1}"
APP_EXEC="$APP_BUNDLE/Contents/MacOS/Hypersync"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hypersync-xcuitests.XXXXXX")"
APP_SUPPORT_DIR="$TMP_ROOT/app-support"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

require_accessibility() {
  local enabled
  enabled="$(osascript -e 'tell application "System Events" to UI elements enabled')"
  if [[ "$enabled" != "true" ]]; then
    echo "Accessibility permission is required for XCUITests." >&2
    echo "Enable Terminal in System Settings > Privacy & Security > Accessibility." >&2
    exit 1
  fi
}

require_accessibility

if [[ "$BUILD_APP" == "1" ]]; then
  echo "Building ad-hoc test app bundle for bundle id: $BUNDLE_ID"
  BUNDLE_ID="$BUNDLE_ID" CODESIGN_IDENTITY="-" SKIP_NOTARIZE="1" "$ROOT_DIR/scripts/package_app.sh" >/dev/null
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing app bundle at $APP_BUNDLE" >&2
  exit 1
fi

if [[ ! -x "$APP_EXEC" ]]; then
  echo "Missing app executable at $APP_EXEC" >&2
  exit 1
fi

mkdir -p "$APP_SUPPORT_DIR"

HYPERSYNC_RUN_XCUITESTS="1" \
HYPERSYNC_UI_TEST_BUNDLE_ID="$BUNDLE_ID" \
HYPERSYNC_UI_TEST_APP_SUPPORT_DIR="$APP_SUPPORT_DIR" \
HYPERSYNC_UI_TEST_APP_EXEC="$APP_EXEC" \
swift test --filter HypersyncXCUITests
