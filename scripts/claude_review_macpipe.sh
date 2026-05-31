#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FOCUS="${1:-Review MacPipe as a tiny macOS utility. Focus on no-JS server-rendered architecture, small-window UX, result-click-to-VLC flow, observability/debug endpoints, setup docs, screenshots, and concrete improvements. Do not edit files.}"
PROMPT_FILE="${TMPDIR:-/tmp}/macpipe-claude-review-prompt.md"
OUT_FILE="${TMPDIR:-/tmp}/macpipe-claude-review.json"

cd "$ROOT"

cat > "$PROMPT_FILE" <<PROMPT
You are Claude Code acting as a product/UI/code reviewer for MacPipe.

Project path: $ROOT

MacPipe context:
- Tiny macOS utility for searching YouTube and sending selected videos to VLC.
- Main app is a dockable Swift/AppKit/WKWebView wrapper around a local Python server-rendered workbench.
- User dislikes JS-heavy frontends for MacPipe. Prefer server-rendered HTML forms, plain CSS, CLI/tool-first workflows, and local control-plane APIs.
- UI should fit a small native utility window, roughly 20% of visible screen area.
- Clicking a result should directly play it in VLC.
- The app should remain observable through /observe and /debug JSON endpoints.
- Do not edit files unless explicitly asked in a later turn.

Important files:
- README.md
- DESIGN.md
- docs/claude.md
- workbench/server.py
- workbench/styles.css
- Sources/MacPipeWorkbench/main.swift
- scripts/build_macpipe_workbench_app.sh
- docs/screenshots/macpipe-app.png
- docs/screenshots/macpipe-observe.png

Focus:
$FOCUS

Return concise, concrete recommendations. Call out risks, overbuilt parts, missing tests, UX problems, and specific implementation steps.
PROMPT

claude -p "$(cat "$PROMPT_FILE")" \
  --allowedTools 'Read,Bash' \
  --output-format json \
  --max-turns 8 \
  | tee "$OUT_FILE"

python3 - <<'PY' "$OUT_FILE"
import json, sys
path = sys.argv[1]
with open(path) as f:
    result = json.load(f)
print("\n--- Claude result ---\n")
print(result.get("result", ""))
print(f"\nSaved JSON: {path}")
print(f"Session ID: {result.get('session_id', '')}")
PY
