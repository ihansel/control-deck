#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${TMPDIR:-/tmp}/control-deck-logic-tests"

swiftc \
  -parse-as-library \
  -framework AppKit \
  -framework ApplicationServices \
  -framework Carbon \
  -o "$OUTPUT" \
  "$ROOT/Sources/ControlDeck/Models.swift" \
  "$ROOT/Sources/ControlDeck/GyroModels.swift" \
  "$ROOT/Sources/ControlDeck/InputMappingModels.swift" \
  "$ROOT/Sources/ControlDeck/ExpandedProfileCatalog.swift" \
  "$ROOT/Sources/ControlDeck/ShiftLayerModels.swift" \
  "$ROOT/Sources/ControlDeck/QuickTutorial.swift" \
  "$ROOT/Sources/ControlDeck/CodexDictationIntent.swift" \
  "$ROOT/Sources/ControlDeck/TouchpadGestureEngine.swift" \
  "$ROOT/Sources/ControlDeck/PointerService.swift" \
  "$ROOT/Sources/ControlDeck/ScreenshotEditorModels.swift" \
  "$ROOT/Sources/ControlDeck/ScreenshotEditorController.swift" \
  "$ROOT/Sources/ControlDeck/CodexTaskMonitor.swift" \
  "$ROOT/Sources/ControlDeck/DualSenseBluetoothAudioProtocol.swift" \
  "$ROOT/Tests/ControlDeckTests/ControlDeckTests.swift"

"$OUTPUT"

GYRO_GAME="$ROOT/Sources/ControlDeck/Resources/GyroGame"
node --check "$GYRO_GAME/game.js"
node --check "$GYRO_GAME/game.bundle.js"
for resource in \
  index.html styles.css game.js game.bundle.js three.module.min.js \
  three.core.min.js THREE-LICENSE.txt
do
  if [[ ! -s "$GYRO_GAME/$resource" ]]; then
    print -u2 "FAIL: Tilt Run resource is missing: $resource"
    exit 1
  fi
done
if ! grep -q "three.core.min.js" "$GYRO_GAME/three.module.min.js"; then
  print -u2 "FAIL: bundled Three.js module/core versions do not match"
  exit 1
fi
echo "PASS: Tilt Run Three.js bundle"
"$ROOT/scripts/test-gyro-webkit.sh"

EXTENSION_SERVICE="$ROOT/Sources/ControlDeck/CodexExtensionService.swift"
MCP_SERVER="$ROOT/Sources/ControlDeck/Resources/control_deck_mcp.py"

if grep -Eq 'Process[(]|executableURL|/usr/bin/env' "$EXTENSION_SERVICE"; then
  print -u2 "FAIL: Codex customization must not launch a CLI executable"
  exit 1
fi

if grep -Eq \
  'shell[[:space:]]*=[[:space:]]*True|os\\.system|subprocess\\.Popen|socket|urllib|requests' \
  "$MCP_SERVER"; then
  print -u2 "FAIL: controller MCP exceeded its local preference-only boundary"
  exit 1
fi

echo "PASS: Codex customization security boundaries"
