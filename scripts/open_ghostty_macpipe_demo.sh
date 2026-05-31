#!/usr/bin/env bash
set -euo pipefail

# Open a fixed-size Ghostty window running the MacPipe TUI.
# Usage:
#   scripts/open_ghostty_macpipe_demo.sh            # real YouTube search
#   scripts/open_ghostty_macpipe_demo.sh --mock     # mock search, user still presses Enter
#   scripts/open_ghostty_macpipe_demo.sh --demo     # opens directly on a playable mock list

ROOT="/Users/ginugeorge/macpipe"
GHOSTTY="/Applications/Ghostty.app"
MODE="real"
TITLE="MacPipe demo — fixed 100x30"
EXTRA_ARGS=()

if [[ "${1:-}" == "--mock" ]]; then
  MODE="mock"
  TITLE="MacPipe demo — mock fixed 100x30"
  EXTRA_ARGS+=("--mock")
elif [[ "${1:-}" == "--demo" ]]; then
  MODE="demo-results"
  TITLE="MacPipe demo — playable list fixed 100x30"
  EXTRA_ARGS+=("--demo-results")
fi

cd "$ROOT"

# Build first so the launched window does not fail if .build/debug/macpipe is stale/missing.
swift build --product macpipe -j 1 >/tmp/macpipe-ghostty-build.log 2>&1

INNER="cd '$ROOT' && printf '\\033[8;30;100t' && printf 'MacPipe demo window — fixed 100x30\nMode: $MODE\nType a search, press Enter. Real YouTube search may take a few seconds.\n\n' && .build/debug/macpipe tty --dry-run --limit 5 ${EXTRA_ARGS[*]}"

open -na "$GHOSTTY" --args \
  --title="$TITLE" \
  --window-width=100 \
  --window-height=30 \
  --font-size=14 \
  -e /bin/zsh -lc "$INNER"

printf 'Opened Ghostty MacPipe window: %s\n' "$TITLE"
printf 'Build log: /tmp/macpipe-ghostty-build.log\n'
