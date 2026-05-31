#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "❌ $1" >&2
  exit 1
}

pass() {
  echo "✅ $1"
}

run() {
  swift run macpipe "$@"
}

run_built() {
  .build/debug/macpipe "$@"
}

echo "Building macpipe..."
swift build --product macpipe -j 1 >/tmp/macpipe_build.log 2>&1 || { cat /tmp/macpipe_build.log; fail "swift build failed"; }
pass "build succeeds"

echo

echo "Scenario 1: help text"
HELP_OUTPUT="$(run help 2>&1)" || fail "help command failed"
echo "$HELP_OUTPUT" | grep -q "Usage:" || fail "help output missing Usage"
echo "$HELP_OUTPUT" | grep -q "macpipe search" || fail "help output missing search command"
echo "$HELP_OUTPUT" | grep -q "macpipe find" || fail "help output missing find command"
echo "$HELP_OUTPUT" | grep -q "macpipe watch" || fail "help output missing watch command"
pass "help output lists expected commands"

echo

echo "Scenario 2: search with --limit 3"
SEARCH_OUTPUT="$(run search lofi --limit 3 2>&1)" || fail "search command failed"
echo "$SEARCH_OUTPUT" | grep -q "Searching for: lofi$" || {
  echo "$SEARCH_OUTPUT"
  fail "search query incorrectly includes flags"
}
RESULT_COUNT="$(echo "$SEARCH_OUTPUT" | grep -E '^\[[0-9]+\]' | wc -l | tr -d ' ')"
[[ "$RESULT_COUNT" == "3" ]] || {
  echo "$SEARCH_OUTPUT"
  fail "expected 3 search results, got $RESULT_COUNT"
}
echo "$SEARCH_OUTPUT" | grep -q "ID:" || fail "search output missing video IDs"
pass "search returns exactly 3 display rows and does not include flags in query"

echo

echo "Scenario 3: JSON search is machine-parseable"
JSON_OUTPUT="$(run search lofi --limit 2 --json 2>/tmp/macpipe_json_stderr.log)" || fail "json search command failed"
python3 - <<'PY' <<< "$JSON_OUTPUT"
import json, sys
payload = json.load(sys.stdin)
assert isinstance(payload, list), type(payload)
assert len(payload) == 2, len(payload)
assert all(item.get('id') and item.get('title') for item in payload)
PY
pass "json search returns pure JSON array of 2 results"

echo

echo "Scenario 3b: quality flags parse and debug explains decisions"
QUALITY_OFF_OUTPUT="$(run search lofi --limit 3 --quality off 2>&1)" || fail "quality off search command failed"
echo "$QUALITY_OFF_OUTPUT" | grep -q "Searching for: lofi$" || {
  echo "$QUALITY_OFF_OUTPUT"
  fail "quality flag incorrectly included in query"
}
quality_off_count="$(echo "$QUALITY_OFF_OUTPUT" | grep -E '^\[[0-9]+\]' | wc -l | tr -d ' ')"
[[ "$quality_off_count" == "3" ]] || {
  echo "$QUALITY_OFF_OUTPUT"
  fail "quality off expected 3 results, got $quality_off_count"
}
QUALITY_DEBUG_OUTPUT="$(run search lofi --limit 2 --quality normal --mode education --quality-debug --allow-shorts 2>&1)" || fail "quality debug search command failed"
echo "$QUALITY_DEBUG_OUTPUT" | grep -q "Searching for: lofi$" || {
  echo "$QUALITY_DEBUG_OUTPUT"
  fail "mode flag incorrectly included in query"
}
echo "$QUALITY_DEBUG_OUTPUT" | grep -q "Quality decisions:" || {
  echo "$QUALITY_DEBUG_OUTPUT"
  fail "quality debug output missing quality decisions"
}
echo "$QUALITY_DEBUG_OUTPUT" | grep -q "quality " || {
  echo "$QUALITY_DEBUG_OUTPUT"
  fail "quality debug output missing score lines"
}
pass "quality flags parse, preserve query text, and debug explains decisions"

echo

echo "Scenario 4: extract audio-only URL from known Rick Astley video"
AUDIO_OUTPUT="$(run play dQw4w9WgXcQ --audio-only 2>&1)" || fail "audio-only play command failed"
echo "$AUDIO_OUTPUT" | grep -q "Audio stream:" || {
  echo "$AUDIO_OUTPUT"
  fail "audio-only output missing Audio stream"
}
echo "$AUDIO_OUTPUT" | grep -q "URL: https://" || {
  echo "$AUDIO_OUTPUT"
  fail "audio-only output missing stream URL"
}
pass "audio-only extraction returns stream URL"

echo

echo "Scenario 5: resolve first search result for listen mode"
LISTEN_OUTPUT="$(run listen 'rick astley never gonna give you up official' --limit 5 --index 1 --dry-run 2>&1)" || fail "listen dry-run command failed"
echo "$LISTEN_OUTPUT" | grep -q "Would play:" || {
  echo "$LISTEN_OUTPUT"
  fail "listen dry-run output missing selected title"
}
echo "$LISTEN_OUTPUT" | grep -q "Audio stream:" || {
  echo "$LISTEN_OUTPUT"
  fail "listen dry-run output missing Audio stream"
}
echo "$LISTEN_OUTPUT" | grep -q "URL: https://" || {
  echo "$LISTEN_OUTPUT"
  fail "listen dry-run output missing audio URL"
}
pass "listen dry-run resolves query to playable audio URL"

echo

echo "Scenario 6: resolve first search result for VLC video playback"
OPEN_OUTPUT="$(run open lofi --limit 2 --index 1 --player VLC --dry-run 2>&1)" || fail "open dry-run command failed"
echo "$OPEN_OUTPUT" | grep -q "Would open with VLC:" || {
  echo "$OPEN_OUTPUT"
  fail "open dry-run output missing VLC launch description"
}
echo "$OPEN_OUTPUT" | grep -q "URL: https://" || {
  echo "$OPEN_OUTPUT"
  fail "open dry-run output missing video URL"
}
pass "open dry-run resolves query to VLC-playable video URL"

echo

echo "Scenario 7: open exact video ID with VLC title metadata"
OPEN_ID_OUTPUT="$(run open-id vBPz_YPlDwk --player VLC --dry-run 2>&1)" || fail "open-id dry-run command failed"
echo "$OPEN_ID_OUTPUT" | grep -q "Would open with VLC: Starship Flight 12 Full Analysis" || {
  echo "$OPEN_ID_OUTPUT"
  fail "open-id dry-run output missing exact fetched title"
}
echo "$OPEN_ID_OUTPUT" | grep -q "Playlist: .*\.xspf" || {
  echo "$OPEN_ID_OUTPUT"
  fail "open-id dry-run should create an XSPF playlist for VLC title metadata"
}
echo "$OPEN_ID_OUTPUT" | grep -q "VLC cleanup: --play-and-exit" || {
  echo "$OPEN_ID_OUTPUT"
  fail "open-id dry-run should document VLC cleanup mode"
}
pass "open-id dry-run resolves exact ID and preserves title metadata for VLC"

echo

echo "Scenario 8: TUI result-list snapshot renders frame"
TUI_OUTPUT="$(run tty --snapshot 2>&1)" || fail "tty snapshot command failed"
echo "$TUI_OUTPUT" | grep -q "MACPIPE TERMINAL VIDEO SYSTEM" || fail "tty snapshot missing header"
echo "$TUI_OUTPUT" | grep -q "/ SEARCH" || fail "tty snapshot missing shortcut footer"
echo "$TUI_OUTPUT" | grep -q "lofi hip hop radio" || fail "tty snapshot missing sample result"
pass "tty result-list snapshot renders expected frame"

echo

echo "Scenario 8b: TUI launcher snapshot renders terminal media launcher"
TUI_HOME_OUTPUT="$(run tty --snapshot --home 2>&1)" || fail "tty home snapshot command failed"
echo "$TUI_HOME_OUTPUT" | grep -q "MACPIPE" || fail "tty home snapshot missing wordmark"
echo "$TUI_HOME_OUTPUT" | grep -q "Search YouTube" || fail "tty home snapshot missing search prompt"
echo "$TUI_HOME_OUTPUT" | grep -q "VIDEO · VLC READY" || fail "tty home snapshot missing media status"
echo "$TUI_HOME_OUTPUT" | grep -q "enter search" || fail "tty home snapshot missing search shortcut"

TUI_COMPACT_HOME_OUTPUT="$(run_built tty --snapshot --home --width 72 --height 18 2>&1)" || fail "tty compact home snapshot command failed"
compact_home_lines="$(printf '%s\n' "$TUI_COMPACT_HOME_OUTPUT" | wc -l | tr -d ' ')"
[[ "$compact_home_lines" == "18" ]] || fail "tty compact home snapshot should render exactly 18 lines, got $compact_home_lines"
if printf '%s\n' "$TUI_COMPACT_HOME_OUTPUT" | python3 -c 'import sys; raise SystemExit(0 if all(len(line.rstrip("\n")) <= 72 for line in sys.stdin) else 1)'; then
  :
else
  echo "$TUI_COMPACT_HOME_OUTPUT"
  fail "tty compact home snapshot should fit width 72"
fi

tui_compact_script_output=$(printf 'qwen 3.7\n1\nx\n' | run_built tty --scripted --mock --dry-run --limit 2 --width 70 --height 18)
if ! grep -q "TUI effect: search qwen 3.7" <<<"$tui_compact_script_output"; then
  echo "$tui_compact_script_output"
  fail "compact scripted TUI did not run search effect"
fi
if ! printf '%s\n' "$tui_compact_script_output" | python3 -c 'import sys; raise SystemExit(0 if all(len(line.rstrip("\n")) <= 70 for line in sys.stdin if not line.startswith("TUI effect:") and not line.startswith("Would open")) else 1)'; then
  echo "$tui_compact_script_output"
  fail "compact scripted TUI frame should fit width 70"
fi

POST_PLAYBACK_OUTPUT="$(run tty --snapshot --post-playback 2>&1)" || fail "tty post-playback snapshot command failed"
echo "$POST_PLAYBACK_OUTPUT" | grep -q "PLAYBACK SENT TO VLC" || fail "tty post-playback snapshot missing playback status"
echo "$POST_PLAYBACK_OUTPUT" | grep -q "S SEARCH AGAIN" || fail "tty post-playback snapshot missing search-again shortcut"
echo "$POST_PLAYBACK_OUTPUT" | grep -q "X EXIT" || fail "tty post-playback snapshot missing exit shortcut"
pass "tty launcher and post-playback snapshots render terminal media loop"

echo

echo "Scenario 9: interactive TUI scripted flow searches, plays, and exits"
tui_script_output=$(printf 'qwen 3.7\n1\nx\n' | run tty --scripted --mock --dry-run --limit 2)
if ! grep -q "TUI effect: search qwen 3.7" <<<"$tui_script_output"; then
  echo "❌ interactive TUI did not run search effect"
  echo "$tui_script_output"
  exit 1
fi
if ! grep -q "TUI effect: play" <<<"$tui_script_output"; then
  echo "❌ interactive TUI did not run play effect"
  echo "$tui_script_output"
  exit 1
fi
if ! grep -q "Would open with VLC" <<<"$tui_script_output"; then
  echo "❌ interactive TUI did not dry-run VLC playback"
  echo "$tui_script_output"
  exit 1
fi
if ! grep -q "TUI effect: quit" <<<"$tui_script_output"; then
  echo "❌ interactive TUI did not quit from X"
  echo "$tui_script_output"
  exit 1
fi
echo "✅ interactive TUI scripted flow searches, plays, and exits"

echo

echo "Scenario 10: default query prompts again after playing"
prompt_output=$(printf '1\nx\n' | run "rick astley never gonna give you up official" --limit 2 --dry-run)
prompt_count=$(grep -c "Which number should I play?" <<<"$prompt_output" || true)
if [[ "$prompt_count" -lt 2 ]]; then
  echo "❌ default query did not prompt again after selected result"
  echo "$prompt_output"
  exit 1
fi
if ! grep -q "Would open with VLC" <<<"$prompt_output"; then
  echo "❌ default query did not resolve selected result through VLC dry-run"
  exit 1
fi
if ! grep -q "Exiting." <<<"$prompt_output"; then
  echo "❌ default query did not exit cleanly on X"
  exit 1
fi
if ! grep -q "Would quit VLC on MacPipe exit" <<<"$prompt_output"; then
  echo "❌ default query did not clean up VLC on X"
  echo "$prompt_output"
  exit 1
fi
echo "✅ default query prompts again after playing, exits on X, and cleans up VLC"

echo

echo "Scenario 11: default query can search again from prompt"
search_again_output=$(printf 's\nrick astley never gonna give you up official\nx\n' | run "qwen 3.7" --limit 1 --dry-run)
if ! grep -q "Search for:" <<<"$search_again_output"; then
  echo "❌ prompt loop did not offer search input"
  exit 1
fi
if ! grep -q "Searching for: rick astley never gonna give you up official" <<<"$search_again_output"; then
  echo "❌ prompt loop did not run the second search"
  exit 1
fi
echo "✅ default query supports S to search again"

echo "All CLI scenarios passed."
