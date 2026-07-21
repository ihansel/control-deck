#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build-app.sh"
pkill -x control-deck 2>/dev/null || true
open "$ROOT/dist/ControlDeck.app"
