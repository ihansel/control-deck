#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to an installed Developer ID Application identity}"
: "${NOTARYTOOL_PROFILE:?Set NOTARYTOOL_PROFILE to an xcrun notarytool keychain profile}"
WORK_DIR="$(mktemp -d -t control-deck-release)"

cleanup() {
  [[ ! -d "$WORK_DIR" ]] || rm -r "$WORK_DIR" 2>/dev/null || true
}

trap cleanup EXIT

if [[ "${1:-}" != "--no-build" ]]; then
  "$ROOT/scripts/build-app.sh"
fi

package_and_notarize() {
  local app_name="$1"
  local app="$ROOT/dist/$app_name.app"
  local framework="$app/Contents/Frameworks/libopus.0.dylib"
  local app_submission="$WORK_DIR/$app_name-app.zip"
  local dmg="$WORK_DIR/$app_name.dmg"
  local dmg_root="$WORK_DIR/dmg-root"
  local mount_point="$WORK_DIR/dmg-mount"
  local zip="$WORK_DIR/$app_name.zip"

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

  ditto -c -k --sequesterRsrc --keepParent "$app" "$app_submission"
  xcrun notarytool submit \
    "$app_submission" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  spctl --assess --type execute --verbose=4 "$app"

  ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"

  mkdir -p "$dmg_root"
  ditto "$app" "$dmg_root/$app_name.app"
  ln -s /Applications "$dmg_root/Applications"
  hdiutil create \
    -volname "$app_name" \
    -srcfolder "$dmg_root" \
    -format UDZO \
    -ov \
    "$dmg"
  codesign \
    --force \
    --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$dmg"
  codesign --verify --verbose=2 "$dmg"
  xcrun notarytool submit \
    "$dmg" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait
  xcrun stapler staple "$dmg"
  xcrun stapler validate "$dmg"
  spctl \
    --assess \
    --type open \
    --context context:primary-signature \
    --verbose=4 \
    "$dmg"

  mkdir -p "$mount_point"
  hdiutil attach \
    -nobrowse \
    -readonly \
    -mountpoint "$mount_point" \
    "$dmg" >/dev/null
  local mount_validation=0
  codesign \
    --verify \
    --deep \
    --strict \
    --verbose=2 \
    "$mount_point/$app_name.app" || mount_validation=$?
  [[ "$(readlink "$mount_point/Applications")" == "/Applications" ]] || \
    mount_validation=1
  hdiutil detach "$mount_point" >/dev/null || mount_validation=$?
  (( mount_validation == 0 ))

  mv -f "$zip" "$ROOT/dist/$app_name.zip"
  mv -f "$dmg" "$ROOT/dist/$app_name.dmg"
}

package_and_notarize "ControlDeck"

shasum -a 256 \
  "$ROOT/dist/ControlDeck.dmg" \
  "$ROOT/dist/ControlDeck.zip"
