#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/ginugeorge/macpipe"
GHOSTTY="/Applications/Ghostty.app"
RUNNER="$ROOT/scripts/run_macpipe_demo_tui.sh"
TITLE="MacPipe demo — playable list fixed 100x30"

cd "$ROOT"
chmod +x "$RUNNER"
swift build --product macpipe -j 1 >/tmp/macpipe-ghostty-build.log 2>&1

open -na "$GHOSTTY" --args \
  --title="$TITLE" \
  --window-width=100 \
  --window-height=30 \
  --font-size=14 \
  -e "$RUNNER"

printf 'Opened Ghostty MacPipe window: %s\n' "$TITLE"
printf 'Runner: %s\n' "$RUNNER"
printf 'Build log: /tmp/macpipe-ghostty-build.log\n'
