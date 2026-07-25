#!/usr/bin/env bash
# Copy the bundled TTS runtime (sherpa-onnx + Alan voice) into an already
# built CBScope.app for macOS. On first run downloads the assets under
# third_party/ (~150 MB); subsequent runs reuse the cache.
#
# The build script for release invokes this AFTER `flutter build macos`
# and BEFORE codesign; the release codesign pass then re-signs every
# nested binary with the Developer ID.
#
# Usage:
#   ./scripts/bundle_tts.sh [<path-to-CBScope.app>]
#   (defaults to build/macos/Build/Products/Release/CBScope.app or
#    Debug/CBScope.app if only Debug exists)

set -euo pipefail

cd "$(dirname "$0")/.."

# --- pick target .app ------------------------------------------------------
# IMPORTANT: default is the *Debug* build. Never silently mutate a
# Release build — it would invalidate the notarized signature and macOS
# would refuse to open the app ("CBScope.app is damaged").
if [[ $# -ge 1 ]]; then
  APP="$1"
elif [[ -d build/macos/Build/Products/Debug/CBScope.app ]]; then
  APP="build/macos/Build/Products/Debug/CBScope.app"
else
  echo "ERROR: no Debug CBScope.app found. Run 'flutter build macos --debug'" >&2
  echo "       first, or pass an explicit .app path as the first argument." >&2
  exit 1
fi

# --- versions --------------------------------------------------------------
SHERPA_VER="v1.13.4"
VOICE="vits-piper-en_GB-alan-medium"
CACHE=third_party
SHERPA_ROOT="$CACHE/sherpa-onnx/macos/sherpa-onnx-$SHERPA_VER-osx-universal2-shared"
VOICE_ROOT="$CACHE/sherpa-onnx/voices/$VOICE"

mkdir -p "$CACHE/sherpa-onnx/macos" "$CACHE/sherpa-onnx/voices"

# --- fetch sherpa-onnx if missing -----------------------------------------
if [[ ! -x "$SHERPA_ROOT/bin/sherpa-onnx-offline-tts" ]]; then
  echo "==> Downloading sherpa-onnx $SHERPA_VER (universal2 shared)..."
  TB="$CACHE/sherpa-onnx/macos/sherpa.tar.bz2"
  curl -fL -o "$TB" \
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/$SHERPA_VER/sherpa-onnx-$SHERPA_VER-osx-universal2-shared.tar.bz2"
  tar xjf "$TB" -C "$CACHE/sherpa-onnx/macos"
  rm "$TB"
fi

# --- fetch Alan voice if missing ------------------------------------------
if [[ ! -f "$VOICE_ROOT/en_GB-alan-medium.onnx" ]]; then
  echo "==> Downloading Alan voice ($VOICE)..."
  TB="$CACHE/sherpa-onnx/voices/alan.tar.bz2"
  curl -fL -o "$TB" \
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$VOICE.tar.bz2"
  tar xjf "$TB" -C "$CACHE/sherpa-onnx/voices"
  rm "$TB"
fi

# --- copy into the .app ---------------------------------------------------
DEST="$APP/Contents/Resources/tts"
echo "==> Populating $DEST"
rm -rf "$DEST"
mkdir -p "$DEST/bin" "$DEST/lib" "$DEST/voice"

# Only the TTS binary + libs it needs. Skip the 20 other CLI utilities that
# ship in the sherpa-onnx tarball to keep the bundle lean.
cp "$SHERPA_ROOT/bin/sherpa-onnx-offline-tts" "$DEST/bin/"
cp "$SHERPA_ROOT/lib/libonnxruntime.1.27.0.dylib" \
   "$SHERPA_ROOT/lib/libsherpa-onnx-c-api.dylib" \
   "$SHERPA_ROOT/lib/libsherpa-onnx-cxx-api.dylib" "$DEST/lib/"
(cd "$DEST/lib" && ln -sf libonnxruntime.1.27.0.dylib libonnxruntime.dylib)

cp "$VOICE_ROOT/en_GB-alan-medium.onnx" \
   "$VOICE_ROOT/en_GB-alan-medium.onnx.json" \
   "$VOICE_ROOT/tokens.txt" "$DEST/voice/"
cp -R "$VOICE_ROOT/espeak-ng-data" "$DEST/voice/"

# --- ad-hoc sign for local dev --------------------------------------------
# Release builds re-sign with Developer ID + hardened runtime as part of
# release_macos.sh, but for `flutter run` we need at least an ad-hoc
# signature so Gatekeeper doesn't SIGKILL the fresh downloads.
echo "==> Ad-hoc signing bundled TTS runtime..."
find "$DEST" -type f \( -name "*.dylib" -o -perm -u+x \) -print0 \
  | while IFS= read -r -d '' f; do
      codesign --force --sign - "$f" >/dev/null 2>&1 || true
    done

echo "✓ TTS runtime bundled at $DEST"
du -sh "$DEST"
