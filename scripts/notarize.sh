#!/usr/bin/env bash
set -euo pipefail

# Standalone notarization script for Hypersync.app
# Required env vars: NOTARIZE_KEY_ID, NOTARIZE_ISSUER_ID, NOTARIZE_KEY_PATH

APP_PATH="${1:-}"

if [[ -z "$APP_PATH" ]]; then
  echo "Usage: $0 <path/to/Hypersync.app>" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: $APP_PATH not found" >&2
  exit 1
fi

for var in NOTARIZE_KEY_ID NOTARIZE_ISSUER_ID NOTARIZE_KEY_PATH; do
  if [[ -z "${!var:-}" ]]; then
    echo "Error: $var is not set" >&2
    exit 1
  fi
done

if [[ ! -f "$NOTARIZE_KEY_PATH" ]]; then
  echo "Error: API key file not found at $NOTARIZE_KEY_PATH" >&2
  exit 1
fi

ZIP_PATH="${APP_PATH%.app}.zip"
echo "Creating zip for notarization: $ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Submitting for notarization..."
SUBMIT_OUTPUT=$(xcrun notarytool submit "$ZIP_PATH" \
  --key "$NOTARIZE_KEY_PATH" \
  --key-id "$NOTARIZE_KEY_ID" \
  --issuer "$NOTARIZE_ISSUER_ID" \
  --wait \
  --output-format json 2>&1) || true

echo "$SUBMIT_OUTPUT"

SUBMISSION_ID=$(echo "$SUBMIT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)
STATUS=$(echo "$SUBMIT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || true)

if [[ "$STATUS" == "Accepted" ]]; then
  echo "Notarization succeeded!"
  echo "Stapling ticket to $APP_PATH..."
  xcrun stapler staple "$APP_PATH"
  echo "Stapling complete."
  rm -f "$ZIP_PATH"
else
  echo "Notarization failed (status: $STATUS)" >&2
  if [[ -n "$SUBMISSION_ID" ]]; then
    echo "Fetching log for submission $SUBMISSION_ID..."
    xcrun notarytool log "$SUBMISSION_ID" \
      --key "$NOTARIZE_KEY_PATH" \
      --key-id "$NOTARIZE_KEY_ID" \
      --issuer "$NOTARIZE_ISSUER_ID" || true
  fi
  rm -f "$ZIP_PATH"
  exit 1
fi
