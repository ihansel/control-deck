#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="$REPO_ROOT/Drivers/DualSenseMicrophone"
BUILD_ROOT="$SOURCE_ROOT/build"
BUNDLE="$BUILD_ROOT/DualSenseMicrophone.driver"
CONTENTS="$BUNDLE/Contents"
BINARY="$CONTENTS/MacOS/DualSenseMicrophone"
SMOKE_TEST="$BUILD_ROOT/LoopbackSmokeTest"

if [[ "${1:-}" == "--clean" ]]; then
    rm -rf "$BUILD_ROOT"
    echo "Removed $BUILD_ROOT"
    exit 0
fi

if [[ $# -ne 0 ]]; then
    echo "Usage: $0 [--clean]" >&2
    exit 64
fi

rm -rf "$BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

xcrun clang \
    -std=c11 \
    -fblocks \
    -bundle \
    -arch arm64 \
    -arch x86_64 \
    -mmacosx-version-min=13.0 \
    -DDEBUG=0 \
    -Wall \
    -Wextra \
    -Wconversion \
    -Wno-deprecated-declarations \
    -framework CoreAudio \
    -framework CoreFoundation \
    "$SOURCE_ROOT/DualSenseMicrophone.c" \
    -o "$BINARY"

cp "$SOURCE_ROOT/Info.plist" "$CONTENTS/Info.plist"
cp "$SOURCE_ROOT/LICENSE.txt" "$CONTENTS/Resources/LICENSE.txt"

plutil -lint "$CONTENTS/Info.plist"

if [[ "$(plutil -extract CFBundleIdentifier raw "$CONTENTS/Info.plist")" != \
      "com.ianhansel.controldeck.audio-driver" ]]; then
    echo "Unexpected driver bundle identifier" >&2
    exit 1
fi

if ! nm -gj "$BINARY" | grep -qx "_NullAudio_Create"; then
    echo "AudioServerPlugIn factory symbol was not exported" >&2
    exit 1
fi

codesign --force --sign - --timestamp=none "$BUNDLE"
codesign --verify --strict --verbose=2 "$BUNDLE"

xcrun clang \
    -std=c11 \
    -mmacosx-version-min=13.0 \
    -Wall \
    -Wextra \
    -Wconversion \
    -framework CoreAudio \
    -framework CoreFoundation \
    "$SOURCE_ROOT/LoopbackSmokeTest.c" \
    -o "$SMOKE_TEST"
"$SMOKE_TEST" "$BINARY"

echo "Built and verified:"
echo "  $BUNDLE"
file "$BINARY"
