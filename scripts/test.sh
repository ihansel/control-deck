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
  "$ROOT/Sources/ControlDeck/InputMappingModels.swift" \
  "$ROOT/Sources/ControlDeck/ExpandedProfileCatalog.swift" \
  "$ROOT/Sources/ControlDeck/ShiftLayerModels.swift" \
  "$ROOT/Sources/ControlDeck/CodexDictationIntent.swift" \
  "$ROOT/Sources/ControlDeck/TouchpadGestureEngine.swift" \
  "$ROOT/Sources/ControlDeck/PointerService.swift" \
  "$ROOT/Sources/ControlDeck/CodexTaskMonitor.swift" \
  "$ROOT/Sources/ControlDeck/DualSenseBluetoothAudioProtocol.swift" \
  "$ROOT/Tests/ControlDeckTests/ControlDeckTests.swift"

"$OUTPUT"

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
