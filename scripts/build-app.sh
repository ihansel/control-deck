#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BINARY=""
RESOURCE_BUNDLE=""
OPUS_PREFIX="$("$ROOT/scripts/build-opus.sh" --print-prefix)"
OPUS_DYLIB="$OPUS_PREFIX/lib/libopus.0.dylib"
OPUS_DEPLOYMENT_TARGET="14.0"

minimum_macos_version() {
  local binary="$1"
  local architecture="$2"
  otool -arch "$architecture" -l "$binary" |
    awk '
      $1 == "cmd" && $2 == "LC_BUILD_VERSION" { in_build_version = 1; next }
      in_build_version && $1 == "minos" { print $2; exit }
    '
}

verify_bundled_opus() {
  local binary="$1"

  lipo "$binary" -verify_arch arm64 x86_64
  local architecture
  for architecture in arm64 x86_64; do
    [[ "$(minimum_macos_version "$binary" "$architecture")" == \
      "$OPUS_DEPLOYMENT_TARGET" ]]
    [[ "$(otool -arch "$architecture" -D "$binary" | sed -n '2p')" == \
      "@rpath/libopus.0.dylib" ]]
  done
}

package_app() {
  local app_name="$1"
  local plist="$2"
  local bundle_id="$3"
  local icon="${4:-}"
  local app="$ROOT/dist/$app_name.app"
  local contents="$app/Contents"
  local macos="$contents/MacOS"
  local frameworks="$contents/Frameworks"
  local resources="$contents/Resources"
  local licenses="$resources/ThirdPartyLicenses"

  rm -rf "$app"
  mkdir -p "$macos" "$frameworks" "$resources" "$licenses"
  cp "$BINARY" "$macos/control-deck"
  cp "$OPUS_DYLIB" "$frameworks/libopus.0.dylib"
  cp \
    "$ROOT/Resources/ThirdPartyLicenses/Opus-COPYING.txt" \
    "$licenses/Opus-COPYING.txt"
  cp "$plist" "$contents/Info.plist"
  if [[ -n "$icon" ]]; then
    cp "$icon" "$resources/$(basename "$icon")"
  fi
  cp -R "$RESOURCE_BUNDLE" "$resources/ControlDeck_ControlDeck.bundle"
  local opus_load_path
  opus_load_path="$(otool -L "$macos/control-deck" | awk '/libopus/{print $1; exit}')"
  install_name_tool \
    -change "$opus_load_path" \
    "@rpath/libopus.0.dylib" \
    "$macos/control-deck"
  install_name_tool \
    -add_rpath "@executable_path/../Frameworks" \
    "$macos/control-deck"
  install_name_tool \
    -id "@rpath/libopus.0.dylib" \
    "$frameworks/libopus.0.dylib"
  codesign --force --sign - "$frameworks/libopus.0.dylib"
  codesign \
    --force \
    --sign - \
    --requirements "=designated => identifier \"$bundle_id\"" \
    "$app"
  verify_bundled_opus "$frameworks/libopus.0.dylib"
  codesign --verify --deep --strict "$app"
  echo "$app"
}

cd "$ROOT"
"$ROOT/scripts/build-opus.sh"
export PKG_CONFIG_PATH="$OPUS_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
swift build -c release
BINARY_DIR="$(swift build -c release --show-bin-path)"
BINARY="$BINARY_DIR/control-deck"
RESOURCE_BUNDLE="$BINARY_DIR/ControlDeck_ControlDeck.bundle"
mkdir -p "$ROOT/dist"

package_app \
  "ControlDeck" \
  "$ROOT/Resources/Info.plist" \
  "com.ianhansel.controldeck" \
  "$ROOT/Resources/AppIcon.icns"
