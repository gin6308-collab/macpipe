Review MacPipe as a tiny macOS utility and recommend improvements.

User focus, if provided:

$ARGUMENTS

Context:
- MacPipe searches YouTube and sends selected videos to VLC.
- The preferred app surface is a dockable Swift/AppKit/WKWebView wrapper around `workbench/server.py`.
- The workbench should stay zero/minimal custom JS: server-rendered HTML forms, plain CSS, backend-owned state.
- Default app size is about 20% of visible screen area.
- Clicking a result should directly play it in VLC.
- Duplicate rapid clicks should not open multiple VLC launches.
- `/observe` and `/debug/*` endpoints are important for agent/debug visibility.

Inspect these files before answering:
- README.md
- DESIGN.md
- docs/claude.md
- workbench/server.py
- workbench/styles.css
- Sources/MacPipeWorkbench/main.swift
- scripts/build_macpipe_workbench_app.sh
- docs/screenshots/macpipe-app.png
- docs/screenshots/macpipe-observe.png

Rules:
- Do not edit files unless explicitly asked after this review.
- Be concise and practical.
- Call out overbuilt pieces, UX friction, missing verification, and security/privacy risks.
- Return an ordered implementation checklist for the best improvements.
