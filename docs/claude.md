# Using Claude Code with MacPipe

MacPipe can use Claude Code in two useful ways:

1. As a command-line review tool from any shell.
2. As a Claude Code slash command when you are inside an interactive `claude` session.

This is optional. MacPipe itself does not require Claude Code to build or run.

## Install / auth

```bash
npm install -g @anthropic-ai/claude-code
claude auth login
```

Smoke test:

```bash
claude -p 'Reply with exactly: ok' --output-format json --max-turns 1
```

If `claude auth status --text` says you are logged in but the smoke test returns `401 Invalid authentication credentials`, refresh auth:

```bash
claude auth logout
claude auth login
```

Then retry the smoke test.

## Use Claude as a tool

Run the bundled review helper from the repo root:

```bash
scripts/claude_review_macpipe.sh
```

It asks Claude to inspect the MacPipe workbench without editing files, focusing on:

- no-JS server-rendered architecture
- small-window UX
- result-click-to-VLC flow
- observability/debug endpoints
- setup docs and screenshots
- practical improvement suggestions

You can pass a custom focus:

```bash
scripts/claude_review_macpipe.sh "Review the duplicate-click VLC guard and suggest safer behavior."
```

The script writes Claude's JSON result to:

```text
/tmp/macpipe-claude-review.json
```

## Use Claude as a slash command

Start Claude Code in the repo:

```bash
claude
```

Then run:

```text
/macpipe-redesign
```

Optional focus text:

```text
/macpipe-redesign tighten the observe page and setup docs
```

The slash command lives at:

```text
.claude/commands/macpipe-redesign.md
```

It is intentionally read-only by default: Claude should inspect and recommend before editing.

## Recommended workflow

1. Run the app and capture the current behavior.
2. Ask Claude for critique using the script or slash command.
3. Push back with constraints.
4. Let Hermes/Ginu decide which suggestions to implement.
5. Verify with:

```bash
python3 -m py_compile workbench/server.py
swift build --product macpipe -j 1
swift test
scripts/build_macpipe_workbench_app.sh
```

Claude's output is useful input, not authority. Keep the MacPipe constraints intact: minimal/no custom JS, server-owned state, and VLC as the playback renderer.
