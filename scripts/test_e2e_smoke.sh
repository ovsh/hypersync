#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Hypersync"
APP_BUNDLE="${APP_BUNDLE:-$ROOT_DIR/dist/Hypersync.app}"
APP_EXEC="$APP_BUNDLE/Contents/MacOS/Hypersync"
TIMEOUT="${TIMEOUT:-30}"
BUILD_APP="${BUILD_APP:-1}"
TEST_BUNDLE_ID="${TEST_BUNDLE_ID:-com.ovsh.hypersync.smoke}"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hypersync-smoke.XXXXXX")"
APP_SUPPORT_DIR="$TMP_ROOT/app-support"
LOG_FILE="$TMP_ROOT/hypersync.log"
APP_PID=""

cleanup() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

require_accessibility() {
  local enabled
  enabled="$(osascript -e 'tell application "System Events" to UI elements enabled')"
  if [[ "$enabled" != "true" ]]; then
    echo "Accessibility permission is required for smoke tests." >&2
    echo "Enable Terminal in System Settings > Privacy & Security > Accessibility." >&2
    exit 1
  fi
}

wait_until() {
  local description="$1"
  local check_fn="$2"
  local deadline=$((SECONDS + TIMEOUT))
  while (( SECONDS < deadline )); do
    if "$check_fn"; then
      return 0
    fi
    sleep 0.25
  done
  echo "Timed out waiting for: $description" >&2
  return 1
}

skills_window_exists() {
  local out
  out="$(osascript <<OSA 2>/dev/null || true
tell application "System Events"
    if not (exists process "$APP_NAME") then return false
    tell process "$APP_NAME"
        return (exists window "Skills")
    end tell
end tell
OSA
)"
  [[ "$out" == "true" ]]
}

onboarding_visible() {
  local out
  out="$(osascript <<OSA 2>/dev/null || true
tell application "System Events"
    if not (exists process "$APP_NAME") then return false
    tell process "$APP_NAME"
        if not (exists window "Skills") then return false
        if (count of sheets of window "Skills") > 0 then return true
        if exists static text "Welcome to Hypersync" of window "Skills" then return true
        return false
    end tell
end tell
OSA
)"
  [[ "$out" == "true" ]]
}

close_skills_window() {
  osascript <<OSA >/dev/null
tell application "System Events"
    tell process "$APP_NAME"
        set frontmost to true
        keystroke "w" using {command down}
    end tell
end tell
OSA
}

skills_window_gone() {
  ! skills_window_exists
}

reopen_app() {
  osascript -e "tell application id \"$TEST_BUNDLE_ID\" to reopen" >/dev/null
}

if [[ "$BUILD_APP" == "1" ]]; then
  echo "Building ad-hoc test app bundle..."
  BUNDLE_ID="$TEST_BUNDLE_ID" CODESIGN_IDENTITY="-" SKIP_NOTARIZE="1" "$ROOT_DIR/scripts/package_app.sh" >/dev/null
fi

if [[ ! -x "$APP_EXEC" ]]; then
  echo "Missing app executable at $APP_EXEC" >&2
  exit 1
fi

require_accessibility
mkdir -p "$APP_SUPPORT_DIR"

echo "Launching app in isolated test mode..."
HYPERSYNC_APP_SUPPORT_DIR="$APP_SUPPORT_DIR" \
HYPERSYNC_SKIP_LOGIN_ITEM="1" \
HYPERSYNC_DISABLE_ANALYTICS="1" \
HYPERSYNC_DISABLE_BACKGROUND_JOBS="1" \
"$APP_EXEC" >"$LOG_FILE" 2>&1 &
APP_PID=$!

wait_until "Skills window to appear" skills_window_exists
echo "PASS: Skills window appears on launch"

wait_until "onboarding sheet to appear on first run" onboarding_visible
echo "PASS: Onboarding appears on first run"

close_skills_window
wait_until "Skills window to close" skills_window_gone
echo "PASS: Skills window can close"

reopen_app
wait_until "Skills window to reopen" skills_window_exists
echo "PASS: Reopen shows Skills window"

echo "Smoke test completed successfully."
