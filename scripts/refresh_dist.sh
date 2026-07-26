#!/usr/bin/env bash
# Populate ../dist/ with the tidy set of testable + shippable artifacts:
#
#   dist/
#   ├── latestversion/CBScope.app     ← fresh Debug build + TTS bundled
#   ├── CBScope.dmg                   ← last signed+notarized macOS release
#   └── CBScope-linux-x86_64.tar.gz   ← last Linux tarball
#
# Only the Debug .app is rebuilt from source each run. The DMG and Linux
# tarball are just copied from build/ if they exist there — cut those
# with ./scripts/release_macos.sh and the Linux script respectively.
#
# Run from the repo root or from anywhere:
#   ./scripts/refresh_dist.sh

set -euo pipefail
cd "$(dirname "$0")/.."

DIST="../dist"
mkdir -p "$DIST/latestversion"

echo "==> Building Debug .app (with TTS)..."
flutter build macos --debug
./scripts/bundle_tts.sh

echo "==> Copying to $DIST/latestversion/"
rm -rf "$DIST/latestversion/CBScope.app"
# `ditto` handles macOS bundles (symlinks + resource forks + acl) far more
# reliably than `cp -R` when overwriting a previously-launched .app.
/usr/bin/ditto build/macos/Build/Products/Debug/CBScope.app \
  "$DIST/latestversion/CBScope.app"

if [[ -f build/CBScope.dmg ]]; then
  cp build/CBScope.dmg "$DIST/CBScope.dmg"
  echo "==> Copied signed DMG"
fi
if [[ -f build/CBScope-linux-x86_64.tar.gz ]]; then
  cp build/CBScope-linux-x86_64.tar.gz "$DIST/CBScope-linux-x86_64.tar.gz"
  echo "==> Copied Linux tarball"
fi

echo
echo "✓ dist/ ready:"
ls -lh "$DIST"
echo
ls -lh "$DIST/latestversion"
