#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/release.sh v0.2.0
# Creates a git tag and pushes it, triggering the GitHub Actions release workflow.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version-tag>"
  echo "Example: $0 v0.2.0"
  exit 1
fi

if ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must match vX.Y.Z (e.g. v0.2.0)" >&2
  exit 1
fi

# Verify clean working tree
if ! git -C "$ROOT_DIR" diff --quiet HEAD 2>/dev/null; then
  echo "Error: uncommitted changes. Commit or stash first." >&2
  exit 1
fi

echo "Tagging $VERSION..."
git -C "$ROOT_DIR" tag -a "$VERSION" -m "Release $VERSION"

echo "Pushing tag to origin..."
git -C "$ROOT_DIR" push origin "$VERSION"

echo ""
echo "Done. GitHub Actions will build and create the release."
echo "Watch progress: gh run watch"
