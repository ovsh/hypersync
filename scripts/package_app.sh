#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Hypersync.app"
EXECUTABLE_NAME="HyperSyncMac"
BUNDLE_ID="${BUNDLE_ID:-com.ovsh.hypersync}"
CONFIGURATION="${CONFIGURATION:-release}"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$DIST_DIR"

# Build the binary using SwiftPM (skip if SKIP_BUILD is set, e.g. in CI)
if [[ "${SKIP_BUILD:-}" != "1" ]]; then
  swift build --package-path "$ROOT_DIR" -c "$CONFIGURATION" --product "$EXECUTABLE_NAME"
fi
BIN_PATH="$(swift build --package-path "$ROOT_DIR" -c "$CONFIGURATION" --show-bin-path)/$EXECUTABLE_NAME"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Error: built executable not found at $BIN_PATH" >&2
  exit 1
fi

# Recreate bundle directory cleanly
if [[ -d "$APP_BUNDLE" ]]; then
  rm -r "$APP_BUNDLE"
fi

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

# Generate app icon
echo "Generating app icon..."
"$MACOS_DIR/$EXECUTABLE_NAME" --generate-icon "$RESOURCES_DIR/AppIcon.icns" || {
  echo "Warning: icon generation failed, bundling without icon"
}

# Resolve version: use VERSION env var if set, otherwise default
APP_VERSION="${VERSION:-0.2.0}"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Hypersync</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Hypersync</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER:-1}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

# Code signing (inside-out, not --deep)
# Set CODESIGN_IDENTITY to override; defaults to Developer ID for distribution.
# Use CODESIGN_IDENTITY="-" for ad-hoc signing during local development.
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Digital Lane LLC (7Z82LSPAPP)}"

codesign --force --options runtime --sign "$CODESIGN_IDENTITY" "$MACOS_DIR/$EXECUTABLE_NAME"
codesign --force --options runtime --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"

echo "Bundle created: $APP_BUNDLE (signed with: $CODESIGN_IDENTITY)"

# Notarize (skip for ad-hoc builds or if SKIP_NOTARIZE is set)
if [[ "$CODESIGN_IDENTITY" != "-" && "${SKIP_NOTARIZE:-}" != "1" ]]; then
  echo "Creating ZIP for notarization..."
  NOTARIZE_ZIP="$(mktemp -d)/Hypersync-notarize.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$NOTARIZE_ZIP"

  echo "Submitting to Apple notary service..."
  if [[ -n "${NOTARIZE_KEY_PATH:-}" && -n "${NOTARIZE_KEY_ID:-}" && -n "${NOTARIZE_ISSUER_ID:-}" ]]; then
    # API key auth (CI)
    xcrun notarytool submit "$NOTARIZE_ZIP" \
      --key "$NOTARIZE_KEY_PATH" \
      --key-id "$NOTARIZE_KEY_ID" \
      --issuer "$NOTARIZE_ISSUER_ID" \
      --wait
  else
    # Keychain profile auth (local)
    NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-HyperSync}"
    xcrun notarytool submit "$NOTARIZE_ZIP" \
      --keychain-profile "$NOTARIZE_PROFILE" \
      --wait
  fi

  echo "Stapling notarization ticket..."
  xcrun stapler staple "$APP_BUNDLE" || {
    echo "Warning: stapling failed (network issue). The app is still notarized — Gatekeeper checks online."
  }

  rm -f "$NOTARIZE_ZIP"
  echo "Notarization complete."
else
  echo "Skipping notarization (ad-hoc signing or SKIP_NOTARIZE=1)."
fi

echo "Launch with: open \"$APP_BUNDLE\""
