#!/bin/zsh
set -euo pipefail

MODE="${1:-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/ControlDeck.app"
BINARY="$APP/Contents/MacOS/control-deck"
PROCESS="control-deck"
BUNDLE_ID="com.ianhansel.controldeck"

pkill -x "$PROCESS" >/dev/null 2>&1 || true
"$ROOT/scripts/build-app.sh" >/dev/null

launch_app() {
  /usr/bin/open -n "$APP"
}

case "$MODE" in
  run)
    launch_app
    ;;
  --debug|debug)
    lldb -- "$BINARY"
    ;;
  --logs|logs)
    launch_app
    /usr/bin/log stream --info --style compact \
      --predicate "process == \"$PROCESS\""
    ;;
  --telemetry|telemetry)
    launch_app
    /usr/bin/log stream --info --style compact \
      --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    launch_app
    sleep 1
    pgrep -x "$PROCESS" >/dev/null
    ;;
  *)
    print -u2 "usage: $0 [run|--debug|--logs|--telemetry|--verify]"
    exit 2
    ;;
esac
