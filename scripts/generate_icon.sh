#!/usr/bin/env bash
set -euo pipefail

# Generates AppIcon.icns by running the app binary with --generate-icon flag
# The binary uses IconGenerator.swift to render the SwiftUI AppIconView at 1024x1024

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
DIST_DIR="$ROOT_DIR/dist"
OUTPUT_ICNS="$DIST_DIR/AppIcon.icns"

mkdir -p "$DIST_DIR"

BIN_PATH="$(swift build --package-path "$ROOT_DIR" -c "$CONFIGURATION" --show-bin-path)/HyperSyncMac"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Error: binary not found at $BIN_PATH — run swift build first" >&2
  exit 1
fi

"$BIN_PATH" --generate-icon "$OUTPUT_ICNS"
echo "Icon generated: $OUTPUT_ICNS"
