#!/usr/bin/env bash
set -euo pipefail
cd /Users/ginugeorge/macpipe

# Ask the terminal emulator for a predictable 100x30 cell grid.
printf '\033[8;30;100t'

# Small pause gives Ghostty a beat to apply the requested size before raw-mode TUI starts.
sleep 0.15

exec .build/debug/macpipe tty --dry-run --demo-results --limit 5
