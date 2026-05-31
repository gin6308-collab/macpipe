#!/usr/bin/env python3
"""MacPipe observable workbench.

Local, server-rendered, zero-custom-JS control surface around the existing
`macpipe` CLI. Bind defaults to 127.0.0.1 for local use.
"""

from __future__ import annotations

import argparse
import html
import json
import shutil
import subprocess
import threading
import time
import urllib.parse
from dataclasses import asdict, dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MACPIPE = ROOT / ".build" / "debug" / "macpipe"
STYLE_PATH = ROOT / "workbench" / "styles.css"


FIXTURE_RESULTS = [
    {
        "rank": 1,
        "id": "ZmyQxBnf3g8",
        "title": "Anthropic Just Killed SaaS? (Managed Agents Explained)",
        "uploader": "Nick Puru | AI Automation",
        "duration": 1121,
        "thumbnail": None,
        "viewCount": 18000,
        "qualityScore": 95,
        "qualityReasons": ["full title match", "normal duration", "education mode boost"],
    },
    {
        "rank": 2,
        "id": "5z1EX77_3po",
        "title": "Anthropic drops Claude Managed Agents: here's an explanation and demo of what it actually is",
        "uploader": "Edward Donner",
        "duration": 1139,
        "thumbnail": None,
        "viewCount": 9400,
        "qualityScore": 81,
        "qualityReasons": ["full title match", "normal duration", "some views"],
    },
    {
        "rank": 3,
        "id": "uxHolzq1NcA",
        "title": "Anthropic's Managed Agents Are Different (Here's Why)",
        "uploader": "Better Stack",
        "duration": 656,
        "thumbnail": None,
        "viewCount": 21000,
        "qualityScore": 76,
        "qualityReasons": ["full title match", "normal duration", "solid views"],
    },
]


@dataclass
class Event:
    id: int
    type: str
    message: str
    timestamp: float
    data: dict[str, Any] = field(default_factory=dict)


@dataclass
class AppState:
    mode: str = "real"
    screen: str = "empty"
    query: str = ""
    selected_rank: int | None = None
    results: list[dict[str, Any]] = field(default_factory=list)
    last_command: list[str] = field(default_factory=list)
    last_output: str = ""
    last_error: str | None = None
    last_action: str | None = None
    playback_busy: bool = False
    events: list[Event] = field(default_factory=list)
    next_event_id: int = 1


STATE = AppState()
LOCK = threading.Lock()


def duration_text(seconds: int | None) -> str:
    if not isinstance(seconds, int) or seconds < 0:
        return "unknown"
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def add_event(event_type: str, message: str, **data: Any) -> None:
    with LOCK:
        STATE.events.append(Event(STATE.next_event_id, event_type, message, time.time(), data))
        STATE.next_event_id += 1
        STATE.events = STATE.events[-100:]


def public_state() -> dict[str, Any]:
    with LOCK:
        data = asdict(STATE)
    data["events"] = [asdict(e) for e in STATE.events[-25:]]
    data["selected"] = selected_result()
    data["health"] = health()
    return data


def selected_result() -> dict[str, Any] | None:
    rank = STATE.selected_rank
    if not rank:
        return None
    for result in STATE.results:
        if result.get("rank") == rank:
            return result
    return None


def health() -> dict[str, Any]:
    return {
        "macpipeBinary": str(MACPIPE),
        "macpipeBuilt": MACPIPE.exists(),
        "ytDlpAvailable": shutil.which("yt-dlp") is not None,
        "vlcAppLikelyAvailable": Path("/Applications/VLC.app").exists(),
        "mode": STATE.mode,
    }


def run_command(args: list[str], timeout: int = 180) -> subprocess.CompletedProcess[str]:
    with LOCK:
        STATE.last_command = args
    return subprocess.run(args, cwd=ROOT, text=True, capture_output=True, timeout=timeout)


def normalize_results(raw: list[dict[str, Any]]) -> list[dict[str, Any]]:
    normalized = []
    for idx, item in enumerate(raw, start=1):
        normalized.append(
            {
                "rank": idx,
                "id": item.get("id", ""),
                "title": item.get("title", "Untitled"),
                "uploader": item.get("uploader", "Unknown"),
                "duration": item.get("duration"),
                "thumbnail": item.get("thumbnail"),
                "viewCount": item.get("viewCount"),
                "qualityScore": item.get("qualityScore"),
                "qualityReasons": item.get("qualityReasons", []),
            }
        )
    return normalized


def action_search(form: dict[str, str]) -> None:
    query = form.get("query", "").strip()
    mode = form.get("mode", STATE.mode).strip() or "mock"
    limit = int(form.get("limit", "5") or 5)
    limit = max(1, min(limit, 20))
    add_event("search.requested", f"Search requested: {query}", query=query, mode=mode)

    with LOCK:
        STATE.mode = mode
        STATE.query = query
        STATE.screen = "searching"
        STATE.last_action = "search"
        STATE.last_error = None

    if not query:
        with LOCK:
            STATE.screen = "empty"
            STATE.results = []
            STATE.selected_rank = None
            STATE.last_error = "Enter a query."
        add_event("search.rejected", "Search rejected: empty query")
        return

    if mode == "mock":
        with LOCK:
            STATE.results = [dict(r) for r in FIXTURE_RESULTS[:limit]]
            STATE.selected_rank = 1 if STATE.results else None
            STATE.screen = "results"
            STATE.last_output = "Loaded fixture results."
        add_event("search.completed", "Loaded fixture results", resultCount=len(STATE.results))
        return

    if not MACPIPE.exists():
        with LOCK:
            STATE.screen = "error"
            STATE.last_error = f"MacPipe binary not found: {MACPIPE}. Run swift build --product macpipe -j 1."
        add_event("search.failed", "MacPipe binary missing")
        return

    args = [str(MACPIPE), "search", query, "--limit", str(limit), "--json"]
    try:
        proc = run_command(args)
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr or proc.stdout or f"exit {proc.returncode}")
        results = normalize_results(json.loads(proc.stdout))
        with LOCK:
            STATE.results = results
            STATE.selected_rank = 1 if results else None
            STATE.screen = "results" if results else "empty"
            STATE.last_output = proc.stdout
        add_event("search.completed", "Search completed", resultCount=len(results))
    except Exception as exc:  # visible local workbench; keep raw error observable
        with LOCK:
            STATE.screen = "error"
            STATE.results = []
            STATE.selected_rank = None
            STATE.last_error = str(exc)
            STATE.last_output = getattr(exc, "stdout", "") or ""
        add_event("search.failed", "Search failed", error=str(exc))


def action_select(form: dict[str, str]) -> None:
    rank = int(form.get("rank", "0") or 0)
    with LOCK:
        valid = any(r.get("rank") == rank for r in STATE.results)
        if valid:
            STATE.selected_rank = rank
            STATE.last_action = "select-result"
            STATE.last_error = None
            STATE.screen = "results"
    add_event("result.selected" if valid else "result.select_failed", f"Selected rank {rank}", rank=rank)


def action_play(form: dict[str, str], next_result: bool = False) -> None:
    with LOCK:
        if STATE.playback_busy:
            STATE.last_action = "play-ignored"
            STATE.last_output = "Ignored duplicate play request while VLC launch was already in progress."
            busy_result = selected_result()
            busy_id = busy_result.get("id") if busy_result else None
            ignored_busy = True
        else:
            ignored_busy = False
            busy_id = None

        if ignored_busy:
            pass
        elif next_result and STATE.results:
            current = STATE.selected_rank or 0
            ranks = [r["rank"] for r in STATE.results]
            larger = [r for r in ranks if r > current]
            STATE.selected_rank = larger[0] if larger else ranks[0]
        if ignored_busy:
            result = None
            mode = STATE.mode
        else:
            result = selected_result()
            mode = STATE.mode
            STATE.last_action = "play-next" if next_result else "play-selected"
            STATE.last_error = None

            if result:
                STATE.playback_busy = True
                STATE.screen = "launching"

    if ignored_busy:
        add_event("play.ignored", "Ignored duplicate play request while launch was in progress", videoId=busy_id)
        return

    if not result:
        with LOCK:
            STATE.last_error = "No result selected."
            STATE.screen = "error"
        add_event("play.failed", "No result selected")
        return

    dry_run = mode != "real"
    args = [str(MACPIPE), "open-id", result["id"], "--player", "VLC"]
    if dry_run:
        args.append("--dry-run")

    if not MACPIPE.exists():
        with LOCK:
            STATE.screen = "error"
            STATE.last_error = f"MacPipe binary not found: {MACPIPE}. Run swift build --product macpipe -j 1."
            STATE.playback_busy = False
        add_event("play.failed", "MacPipe binary missing")
        return

    add_event("play.requested", f"Play requested: {result['title']}", videoId=result["id"], dryRun=dry_run)
    try:
        proc = run_command(args)
        output = (proc.stdout + proc.stderr).strip()
        if proc.returncode != 0:
            raise RuntimeError(output or f"exit {proc.returncode}")
        with LOCK:
            STATE.screen = "playback-sent"
            STATE.last_output = output
            STATE.last_error = None
            STATE.playback_busy = False
        add_event("play.completed", "Playback command completed", videoId=result["id"], dryRun=dry_run)
    except Exception as exc:
        with LOCK:
            STATE.screen = "error"
            STATE.last_error = str(exc)
            STATE.playback_busy = False
        add_event("play.failed", "Playback command failed", error=str(exc), videoId=result["id"])


def action_reset() -> None:
    with LOCK:
        mode = STATE.mode
        STATE.query = ""
        STATE.screen = "empty"
        STATE.selected_rank = None
        STATE.results = []
        STATE.last_command = []
        STATE.last_output = ""
        STATE.last_error = None
        STATE.last_action = "reset"
        STATE.playback_busy = False
        STATE.mode = mode
    add_event("state.reset", "Workbench reset")


def parse_form(body: bytes) -> dict[str, str]:
    parsed = urllib.parse.parse_qs(body.decode("utf-8"), keep_blank_values=True)
    return {k: v[-1] if v else "" for k, v in parsed.items()}


def e(value: Any) -> str:
    return html.escape("" if value is None else str(value), quote=True)


def redact_long_urls(text: str, max_len: int = 900) -> str:
    lines = []
    for line in (text or "").splitlines():
        if line.startswith("URL: ") and len(line) > 120:
            lines.append("URL: [redacted long stream URL; full value available at /debug/state]")
        else:
            lines.append(line)
    rendered = "\n".join(lines)
    if len(rendered) > max_len:
        return rendered[:max_len].rstrip() + "\n… [truncated; full value available at /debug/state]"
    return rendered


def status_info(state: dict[str, Any], selected: dict[str, Any] | None) -> tuple[str, str, str]:
    screen = state.get("screen")
    if state.get("last_error"):
        return ("error", "✕", state["last_error"])
    if state.get("playback_busy") or screen == "launching":
        return ("searching", "●", "Launching VLC — duplicate clicks ignored.")
    if screen == "searching":
        return ("searching", "●", f"Searching for \"{state.get('query', '')}\"…")
    if screen == "playback-sent" and selected:
        title = selected.get("title") or "Untitled"
        if len(title) > 42:
            title = title[:39].rstrip() + "…"
        return ("playing", "▶", f"Playing #{selected.get('rank')} \"{title}\" in VLC · {selected.get('id')}")
    if state.get("results"):
        count = len(state["results"])
        return ("results", "●", f"{count} result{'s' if count != 1 else ''} — click one to play in VLC.")
    return ("idle", "●", "Idle — enter a subject to search.")


def render_status_line(state: dict[str, Any], selected: dict[str, Any] | None) -> str:
    status_class, glyph, message = status_info(state, selected)
    controls = ""
    if status_class == "playing":
        controls = """
          <form method="post" action="/actions/play-next"><button type="submit">next</button></form>
          <form method="post" action="/actions/reset"><button type="submit">reset</button></form>
        """
    elif status_class == "error":
        controls = '<form method="post" action="/actions/reset"><button type="submit">reset</button></form>'
    return f"""
    <section class="status-strip {status_class}" aria-live="polite">
      <span class="status-dot">{glyph}</span>
      <span class="status-message">{e(message)}</span>
      <span class="status-actions">{controls}</span>
    </section>
    """


def render_page() -> str:
    state = public_state()
    results = state["results"]
    selected = state["selected"]

    result_rows = []
    for result in results:
        is_selected = selected and selected.get("rank") == result.get("rank")
        title = result.get("title") or "Untitled"
        rank_label = "▶" if is_selected else result.get("rank")
        result_rows.append(
            f"""
            <li id="r{e(result.get('rank'))}" class="result {'selected' if is_selected else ''}">
              <form method="post" action="/actions/play-rank" class="result-form">
                <input type="hidden" name="rank" value="{e(result.get('rank'))}">
                <button class="result-button" type="submit" aria-label="Play: {e(title)}">
                  <span class="rank" aria-hidden="true">{e(rank_label)}</span>
                  <span class="result-main">
                    <strong>{e(title)}</strong>
                    <small>{duration_text(result.get('duration'))} · {e(result.get('uploader'))}</small>
                  </span>
                  <span class="score" title="quality score">{e(result.get('qualityScore') or '—')}</span>
                </button>
              </form>
            </li>
            """
        )

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MacPipe</title>
  <link rel="stylesheet" href="/styles.css">
</head>
<body class="app-page">
  <header class="topbar">
    <div><strong>MacPipe</strong></div>
    <nav><a href="/">app</a><a href="/observe">observe</a></nav>
  </header>

  <main class="app-main">
    <section class="search-panel">
      <form method="post" action="/actions/search" class="search-form">
        <input name="query" value="{e(state['query'])}" placeholder="Enter subject here" aria-label="Enter subject here" autofocus>
        <button class="primary" type="submit">Find</button>
      </form>
    </section>

    <section class="results-panel" aria-label="Results">
      <ol class="results">{''.join(result_rows) or '<li class="empty">No results yet.</li>'}</ol>
    </section>

    {render_status_line(state, selected)}
  </main>
</body>
</html>"""


def render_observe_page() -> str:
    state = public_state()
    event_rows = "".join(
        f"<tr><td>{e(ev['id'])}</td><td>{e(ev['type'])}</td><td>{e(ev['message'])}</td></tr>" for ev in reversed(state['events'][-25:])
    )
    command = " ".join(state.get("last_command") or [])
    output = redact_long_urls(state.get("last_output") or "No output yet.", max_len=1600)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MacPipe Observe</title>
  <link rel="stylesheet" href="/styles.css">
</head>
<body class="observe-page">
  <header class="topbar">
    <div><strong>Observe</strong></div>
    <nav><a href="/">app</a><a href="/observe">observe</a></nav>
  </header>
  <main class="observe-main">
    <section class="panel debug-panel">
      <div class="section-title"><h1>Controls</h1><span>next search</span></div>
      <form method="post" action="/actions/search" class="search-form observe-controls">
        <input name="query" value="{e(state['query'])}" placeholder="Enter subject here" aria-label="Enter subject here">
        <select name="mode" title="Playback mode" aria-label="Playback mode">
          <option value="real" {'selected' if state['mode'] == 'real' else ''}>VLC</option>
          <option value="mock" {'selected' if state['mode'] == 'mock' else ''}>mock</option>
          <option value="dry-run" {'selected' if state['mode'] == 'dry-run' else ''}>dry</option>
        </select>
        <input class="limit" type="number" name="limit" min="1" max="20" value="5" aria-label="Result limit">
        <button class="primary" type="submit">Find</button>
      </form>
    </section>
    <section class="panel debug-panel">
      <div class="section-title"><h1>Health</h1><span>local</span></div>
      <pre>{e(json.dumps(state['health'], indent=2))}</pre>
    </section>
    <section class="panel debug-panel">
      <details open>
        <summary>Last command</summary>
        <pre>{e(command or 'No command yet.')}</pre>
      </details>
      <details>
        <summary>Last output</summary>
        <pre>{e(output)}</pre>
      </details>
    </section>
    <section class="panel debug-panel">
      <div class="section-title"><h1>Events</h1><span>{len(state['events'])}</span></div>
      <table><tbody>{event_rows or '<tr><td>No events yet.</td></tr>'}</tbody></table>
    </section>
    <section class="panel debug-panel">
      <details>
        <summary>State JSON</summary>
        <pre>{e(json.dumps(state, indent=2))}</pre>
      </details>
    </section>
  </main>
</body>
</html>"""


class Handler(BaseHTTPRequestHandler):
    server_version = "MacPipeWorkbench/0.1"

    def log_message(self, format: str, *args: Any) -> None:
        return

    def send_bytes(self, status: int, content_type: str, body: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def send_json(self, data: Any, status: int = 200) -> None:
        self.send_bytes(status, "application/json; charset=utf-8", json.dumps(data, indent=2).encode())

    def redirect_home(self) -> None:
        self.send_response(303)
        self.send_header("Location", "/")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        path = urllib.parse.urlparse(self.path).path
        if path == "/":
            self.send_bytes(200, "text/html; charset=utf-8", render_page().encode())
        elif path == "/observe":
            self.send_bytes(200, "text/html; charset=utf-8", render_observe_page().encode())
        elif path == "/styles.css":
            self.send_bytes(200, "text/css; charset=utf-8", STYLE_PATH.read_bytes())
        elif path == "/debug/state":
            self.send_json(public_state())
        elif path == "/debug/events":
            self.send_json([asdict(e) for e in STATE.events])
        elif path == "/debug/health":
            self.send_json(health())
        else:
            self.send_bytes(404, "text/plain; charset=utf-8", b"not found")

    def do_POST(self) -> None:  # noqa: N802
        path = urllib.parse.urlparse(self.path).path
        length = int(self.headers.get("Content-Length", "0") or 0)
        form = parse_form(self.rfile.read(length))

        if path in {"/actions/search", "/debug/actions/search"}:
            action_search(form)
        elif path in {"/actions/select", "/debug/actions/select-result"}:
            action_select(form)
        elif path in {"/actions/play-rank", "/debug/actions/play-rank"}:
            action_select(form)
            action_play(form)
        elif path in {"/actions/play", "/debug/actions/play-selected"}:
            action_play(form)
        elif path in {"/actions/play-next", "/debug/actions/play-next"}:
            action_play(form, next_result=True)
        elif path in {"/actions/reset", "/debug/actions/reset"}:
            action_reset()
        else:
            self.send_bytes(404, "text/plain; charset=utf-8", b"not found")
            return

        if path.startswith("/debug/"):
            self.send_json(public_state())
        else:
            self.redirect_home()


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the MacPipe observable workbench")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()
    add_event("server.started", f"Workbench started on http://{args.host}:{args.port}")
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"MacPipe Workbench: http://{args.host}:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
