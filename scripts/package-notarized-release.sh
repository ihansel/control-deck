#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to an installed Developer ID Application identity}"
: "${NOTARYTOOL_PROFILE:?Set NOTARYTOOL_PROFILE to an xcrun notarytool keychain profile}"

if [[ "${1:-}" != "--no-build" ]]; then
  "$ROOT/scripts/build-app.sh"
fi

package_and_notarize() {
  local app_name="$1"
  local app="$ROOT/dist/$app_name.app"
  local framework="$app/Contents/Frameworks/libopus.0.dylib"
  local submission
  submission="$(mktemp -t control-deck-notary).zip"

  codesign \
    --force \
    --timestamp \
    --options runtime \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$framework"
  codesign \
    --force \
    --timestamp \
    --options runtime \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$app"
  codesign --verify --deep --strict --verbose=2 "$app"

  ditto -c -k --sequesterRsrc --keepParent "$app" "$submission"
  xcrun notarytool submit \
    "$submission" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  spctl --assess --type execute --verbose=4 "$app"

  ditto \
    -c \
    -k \
    --sequesterRsrc \
    --keepParent \
    "$app" \
    "$ROOT/dist/$app_name.zip.notarized"
  mv -f \
    "$ROOT/dist/$app_name.zip.notarized" \
    "$ROOT/dist/$app_name.zip"
}

package_and_notarize "ControlDeck"

shasum -a 256 \
  "$ROOT/dist/ControlDeck.zip"
