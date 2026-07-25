#!/usr/bin/env bash
# Build, sign, notarize, staple, and DMG-package CBScope for macOS.
#
# Prerequisites (one-time):
#   1. Developer ID Application certificate installed in the login keychain.
#   2. Notary credentials stored in the keychain:
#        xcrun notarytool store-credentials "notarytool" \
#            --apple-id "you@example.com" \
#            --team-id  "YOURTEAMID" \
#            --password "<app-specific-password>"
#
# Environment overrides (optional):
#   SIGN_ID          Full signing identity string, e.g.
#                    "Developer ID Application: Jane Doe (TEAMID12345)".
#                    Defaults to whatever the first Developer ID cert reports.
#   NOTARY_PROFILE   Keychain profile name (default: "notarytool").
#
# Usage: ./scripts/release_macos.sh

set -euo pipefail

cd "$(dirname "$0")/.."

# --------------------------------------------------------------------- config
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning \
    | awk -F\" '/Developer ID Application/ {print $2; exit}')}"
NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool}"

APP_PATH="build/macos/Build/Products/Release/CBScope.app"
DMG_PATH="build/CBScope.dmg"
ENTITLEMENTS="macos/Runner/Release.entitlements"

if [[ -z "$SIGN_ID" ]]; then
  echo "ERROR: no 'Developer ID Application' certificate found in keychain." >&2
  echo "       Import one from developer.apple.com or set SIGN_ID." >&2
  exit 1
fi
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" \
        >/dev/null 2>&1; then
  echo "ERROR: notarytool profile '$NOTARY_PROFILE' not found." >&2
  echo "       Run 'xcrun notarytool store-credentials' first." >&2
  exit 1
fi

echo "==> Signing as: $SIGN_ID"
echo "==> Notary profile: $NOTARY_PROFILE"

# ---------------------------------------------------------------------- build
echo "==> Building release..."
flutter build macos --release

# --------------------------------------------------------- bundle TTS runtime
# Drop the sherpa-onnx binary + libs + Alan voice into
# Contents/Resources/tts/ BEFORE the codesign pass so the outer signature
# covers them. Otherwise notarization would reject the .app or macOS
# would flag it as damaged on any Mac other than the build machine.
echo "==> Bundling TTS runtime..."
./scripts/bundle_tts.sh "$APP_PATH"

# --------------------------------------------------------------------- sign
# Sign bottom-up: every framework, dylib, and TTS executable first, then
# the outer .app with entitlements + hardened runtime. `--options runtime`
# is required for notarization.
echo "==> Signing frameworks..."
while IFS= read -r -d '' fw; do
  codesign --force --sign "$SIGN_ID" --timestamp --options runtime "$fw"
done < <(find "$APP_PATH/Contents/Frameworks" -maxdepth 2 \
              -type d -name "*.framework" -print0 2>/dev/null || true)

echo "==> Signing dylibs..."
while IFS= read -r -d '' dylib; do
  codesign --force --sign "$SIGN_ID" --timestamp --options runtime "$dylib"
done < <(find "$APP_PATH/Contents/Frameworks" -type f -name "*.dylib" \
              -print0 2>/dev/null || true)

# TTS runtime lives under Contents/Resources/tts/, outside Frameworks/.
# Sign each .dylib and executable individually with the same options.
echo "==> Signing bundled TTS runtime..."
if [[ -d "$APP_PATH/Contents/Resources/tts" ]]; then
  while IFS= read -r -d '' f; do
    codesign --force --sign "$SIGN_ID" --timestamp --options runtime "$f"
  done < <(find "$APP_PATH/Contents/Resources/tts" \
               \( -name "*.dylib" -o -perm -u+x -type f \) -print0)
fi

echo "==> Signing app bundle..."
codesign --force --sign "$SIGN_ID" --timestamp --options runtime \
         --entitlements "$ENTITLEMENTS" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# ------------------------------------------------------------------- notarize
echo "==> Notarizing .app (this can take a few minutes)..."
ZIP="build/cbscope-notarize.zip"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$ZIP"

echo "==> Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

# ------------------------------------------------------------------------ DMG
echo "==> Building DMG..."
rm -f "$DMG_PATH"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname CBScope -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH"

echo "==> Signing + notarizing DMG..."
codesign --force --sign "$SIGN_ID" --timestamp "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo
echo "✓ Signed + notarized DMG ready:"
ls -lh "$DMG_PATH"
