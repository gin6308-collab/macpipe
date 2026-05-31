# MacPipe Terminal Media UI Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Turn MacPipe into a keyboard-first terminal media terminal while keeping the current CLI commands stable as the tested backend harness.

**Architecture:** Keep `MacPipeCore` as the shared engine. Keep `MacPipeCLI` commands working exactly as they do now. Add a new TUI entry path inside `macpipe tty` first, using a small custom ANSI renderer and raw terminal input layer. The TUI is a terminal-native media surface; real video playback should target the best VLC-compatible combined video+audio stream by default.

**Tech Stack:** Swift 5.9, Swift Package Manager, Foundation, AVFoundation/AVKit where needed, yt-dlp, ANSI terminal escape codes, termios raw input, existing `scripts/test_cli.sh`.

---

## Product Target

MacPipe should feel like a terminal media terminal, not a Hermes chat skin and not necessarily a retro-only green screen. OpenCode is the closest styling reference for the product category: it treats the terminal as the primary app surface, uses strong typography/spacing, keeps key commands visible, and makes status/model/session context part of the chrome.

MacPipe should borrow OpenCode's terminal-product cues without copying its coding-agent identity:

- Use large, confident terminal typography for the title/header where useful.
- Start with generous negative space and a centered launcher/search panel, not a dense table immediately.
- Use one strong vertical accent bar on the active panel to show focus/current mode.
- Keep the main input/search affordance obvious and centered in the flow.
- Keep persistent shortcut hints visible at the bottom, with key names bright and labels dim.
- Use a compact status strip for player/backend/state: VLC, yt-dlp, result count, current mode.
- Prefer flat dark panels over heavy box-drawing borders for the first screen; use borders only where they clarify structure.
- Use color semantically, not decoratively.
- Avoid Hermes' `flower` palette and chat-message feel.
- Avoid locking the design into fake retro nostalgia; this is a media terminal first.

A rough launcher screen should echo the screenshot's useful structure without cloning it:

```text

                            ███╗   ███╗ █████╗  ██████╗██████╗ ██╗██████╗ ███████╗
                            ████╗ ████║██╔══██╗██╔════╝██╔══██╗██║██╔══██╗██╔════╝
                            ██╔████╔██║███████║██║     ██████╔╝██║██████╔╝█████╗
                            ██║╚██╔╝██║██╔══██║██║     ██╔═══╝ ██║██╔═══╝ ██╔══╝
                            ██║ ╚═╝ ██║██║  ██║╚██████╗██║     ██║██║     ███████╗
                            ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝     ╚═╝╚═╝     ╚══════╝

        ▌  Search YouTube...  "qwen 3.7"
        ▌
        ▌  VIDEO · VLC READY · yt-dlp READY

                                            / search   enter play   s new   x exit
```

A rough results screen can become denser after search:

```text
╔════════════════════════ MACPIPE MEDIA TERMINAL ═══════════════════════════════╗
║ QUERY: qwen 3.7                                             yt-dlp READY     ║
╠════╦══════════════════════════════════════════════╦══════════════════════════╣
║ 01 ║ Qwen 3.7 overview and demos                  ║  12:44 · AI Explained   ║
║ 02 ║ Qwen coding agent test                       ║  24:08 · Dev Channel    ║
║ 03 ║ Local models news                            ║  08:31 · Model Watch    ║
╠════╩══════════════════════════════════════════════╩══════════════════════════╣
║ NOW: selected title, channel, duration, stream/player state                   ║
║ STATUS: opened in VLC · choose another number, S search, X exit               ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║ ↑↓ MOVE  1-9 PLAY  ENTER PLAY  A AUDIO  S SEARCH  / FIND  ? HELP  X EXIT    ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

Semantic color roles:

- Frame/chrome: dim teal or green-blue
- Search/input: bright cyan
- Selected row: amber/yellow
- Result title: clean green or off-white
- Metadata: muted blue/cyan
- Shortcuts: purple/magenta or amber
- Playing/opening: bright white + lime status
- Errors: red/orange
- Secondary text: dim gray-green

MVP shortcuts:

- `/` search
- `↑/↓` move selection
- `Enter` open/play selected
- `A` audio-only
- `O` open external player
- `D` toggle description
- `R` related/recommendations
- `H` history later
- `F` favorite later
- `C` copy URL later
- `?` help overlay
- `Q` quit

---

## CLI Product Principle

The existing command-line app must become extremely user-friendly too. The TUI is the main appliance-like experience, but the CLI should remain the fast, obvious power-user path.

CLI rules:

- Commands should read like user intent, not implementation details.
- Prefer 4–5 obvious verbs over many clever subcommands.
- Keep old commands as aliases so existing tests and habits do not break.
- Help output should show the happy path first, not every flag first.
- Every action that can launch playback should have `--dry-run`.
- Machine output stays behind `--json`; human output stays clean and minimal.
- Errors should include the next fix: install yt-dlp, install VLC/mpv, try `--dry-run`, etc.

Recommended CLI vocabulary:

```text
macpipe                     Open green-screen TUI once ready
macpipe tty                 Open green-screen TUI explicitly
macpipe find <query>        Search YouTube
macpipe watch <query>       Search and open best/selected video externally
macpipe listen <query>      Audio-only playback
macpipe open-id <id-or-url> Open exact video externally
macpipe recent              Recent searches/plays later
macpipe help                Short friendly help
```

Aliases to preserve:

```text
search  -> find
open    -> watch
play    -> open-id or stream-info behavior, depending current tests
```

Design target for `macpipe help`:

```text
MACPIPE — terminal YouTube, minus the browser circus.

Start:
  macpipe                    open the green-screen app
  macpipe find lofi beats    search videos
  macpipe watch lofi beats   open the best match in VLC-compatible quality
  macpipe listen lofi beats  play audio-only

Useful:
  --limit N      number of results
  --index N      choose result number
  --player VLC   external player
  --dry-run      show what would happen
  --json         machine-readable search results
```

## Implementation Strategy

Do not start by rewriting the CLI. First add isolated, testable TUI pieces, then improve the CLI vocabulary with aliases and friendlier help. The current CLI is valuable because it already proves yt-dlp/search/stream/open flows.

Order:

1. Add pure rendering and input parsing tests.
2. Add terminal primitives.
3. Add `macpipe tty` command.
4. Render a static frame.
5. Add CLI aliases and friendly help without breaking old commands.
6. Add interactive search/results.
7. Add selection and open/play actions.
8. Add descriptions and recommendations.
9. Add polish.

Every code task should keep `swift build` and `scripts/test_cli.sh` passing unless the task explicitly only touches snapshot-only TUI tests.

---

## Task 1: Add TUI Types and Renderer Snapshot Test

**Objective:** Create a pure, deterministic renderer that can draw a green-screen frame from state without touching the terminal.

**Files:**
- Create: `Sources/MacPipeCore/TUI/TUIState.swift`
- Create: `Sources/MacPipeCore/TUI/TUIRenderer.swift`
- Create: `Tests/MacPipeCoreTests/TUIRendererTests.swift` if tests target exists; otherwise create test target in Task 2 first.
- Modify: `Package.swift`

**Step 1: Add a test target if none exists**

Modify `Package.swift` to add:

```swift
.testTarget(
    name: "MacPipeCoreTests",
    dependencies: ["MacPipeCore"]
)
```

Expected target section includes `MacPipeCoreTests`.

**Step 2: Create state types**

Create `Sources/MacPipeCore/TUI/TUIState.swift`:

```swift
import Foundation

public enum TUIScreen: Sendable, Equatable {
    case home
    case searching
    case results
    case details
    case help
}

public struct TUIState: Sendable, Equatable {
    public var screen: TUIScreen
    public var query: String
    public var results: [SearchResult]
    public var selectedIndex: Int
    public var status: String
    public var showFullDescription: Bool

    public init(
        screen: TUIScreen = .home,
        query: String = "",
        results: [SearchResult] = [],
        selectedIndex: Int = 0,
        status: String = "READY",
        showFullDescription: Bool = false
    ) {
        self.screen = screen
        self.query = query
        self.results = results
        self.selectedIndex = selectedIndex
        self.status = status
        self.showFullDescription = showFullDescription
    }

    public var selectedResult: SearchResult? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex]
    }
}
```

**Step 3: Create renderer**

Create `Sources/MacPipeCore/TUI/TUIRenderer.swift`:

```swift
import Foundation

public struct TUIRenderer: Sendable {
    public init() {}

    public func render(state: TUIState, width: Int = 80, height: Int = 24) -> String {
        let safeWidth = max(60, width)
        var lines: [String] = []

        lines.append("╔" + String(repeating: "═", count: safeWidth - 2) + "╗")
        lines.append(padBox(" MACPIPE TERMINAL VIDEO SYSTEM", status: state.status, width: safeWidth))
        lines.append("╠" + String(repeating: "═", count: safeWidth - 2) + "╣")
        lines.append(padBox(" QUERY: \(state.query.isEmpty ? "<press / to search>" : state.query)", status: "", width: safeWidth))
        lines.append("╠" + String(repeating: "═", count: safeWidth - 2) + "╣")

        let visible = Array(state.results.prefix(max(1, height - 10)).enumerated())
        if visible.isEmpty {
            lines.append(padBox(" No results. Press / to search.", status: "", width: safeWidth))
        } else {
            for (idx, result) in visible {
                let marker = idx == state.selectedIndex ? ">" : " "
                let number = String(format: "%02d", idx + 1)
                let row = " \(marker)\(number)  \(result.title) · \(result.durationFormatted) · \(result.uploader)"
                lines.append(padBox(row, status: "", width: safeWidth))
            }
        }

        lines.append("╠" + String(repeating: "═", count: safeWidth - 2) + "╣")
        if let selected = state.selectedResult {
            lines.append(padBox(" DETAILS: \(selected.title)", status: "", width: safeWidth))
            lines.append(padBox(" CHANNEL: \(selected.uploader)   ID: \(selected.id)", status: "", width: safeWidth))
        } else {
            lines.append(padBox(" DETAILS: select a result", status: "", width: safeWidth))
        }
        lines.append("╠" + String(repeating: "═", count: safeWidth - 2) + "╣")
        lines.append(padBox(" ↑↓ MOVE  ENTER PLAY  A AUDIO  O OPEN  D DESC  R RELATED  / SEARCH  Q QUIT", status: "", width: safeWidth))
        lines.append("╚" + String(repeating: "═", count: safeWidth - 2) + "╝")

        return lines.prefix(height).joined(separator: "\n")
    }

    private func padBox(_ left: String, status: String, width: Int) -> String {
        let contentWidth = width - 2
        let combined: String
        if status.isEmpty {
            combined = left
        } else {
            let gap = max(1, contentWidth - left.count - status.count)
            combined = left + String(repeating: " ", count: gap) + status
        }
        let clipped = String(combined.prefix(contentWidth))
        return "║" + clipped + String(repeating: " ", count: max(0, contentWidth - clipped.count)) + "║"
    }
}
```

**Step 4: Write renderer test**

Create `Tests/MacPipeCoreTests/TUIRendererTests.swift`:

```swift
import XCTest
@testable import MacPipeCore

final class TUIRendererTests: XCTestCase {
    func testRendererShowsHeaderShortcutsAndSelectedResult() {
        let state = TUIState(
            screen: .results,
            query: "lofi",
            results: [
                SearchResult(id: "abc", title: "Lofi Radio", uploader: "Lofi Girl", duration: 3661, thumbnail: nil),
                SearchResult(id: "def", title: "Coding Music", uploader: "Focus", duration: 120, thumbnail: nil)
            ],
            selectedIndex: 1,
            status: "READY"
        )

        let frame = TUIRenderer().render(state: state, width: 80, height: 24)

        XCTAssertTrue(frame.contains("MACPIPE TERMINAL VIDEO SYSTEM"))
        XCTAssertTrue(frame.contains("QUERY: lofi"))
        XCTAssertTrue(frame.contains(">02"))
        XCTAssertTrue(frame.contains("Coding Music"))
        XCTAssertTrue(frame.contains("/ SEARCH"))
        XCTAssertTrue(frame.contains("Q QUIT"))
    }
}
```

**Step 5: Run test**

Run:

```bash
swift test --filter TUIRendererTests
```

Expected: PASS.

**Step 6: Verify existing CLI still builds**

Run:

```bash
swift build
```

Expected: PASS.

---

## Task 2: Add Keyboard Input Parser Tests

**Objective:** Parse raw key bytes into semantic TUI actions without requiring a real terminal.

**Files:**
- Create: `Sources/MacPipeCore/TUI/TUIInput.swift`
- Create: `Tests/MacPipeCoreTests/TUIInputTests.swift`

**Step 1: Create action enum and parser**

Create `Sources/MacPipeCore/TUI/TUIInput.swift`:

```swift
import Foundation

public enum TUIAction: Sendable, Equatable {
    case moveUp
    case moveDown
    case submit
    case search
    case audio
    case open
    case description
    case related
    case help
    case quit
    case escape
    case character(Character)
    case backspace
    case unknown
}

public struct TUIInputParser: Sendable {
    public init() {}

    public func parse(bytes: [UInt8]) -> TUIAction {
        if bytes == [27, 91, 65] { return .moveUp }
        if bytes == [27, 91, 66] { return .moveDown }
        if bytes == [10] || bytes == [13] { return .submit }
        if bytes == [27] { return .escape }
        if bytes == [127] || bytes == [8] { return .backspace }
        guard bytes.count == 1, let scalar = UnicodeScalar(bytes[0]) else { return .unknown }
        let ch = Character(scalar)
        switch ch.lowercased() {
        case "/": return .search
        case "a": return .audio
        case "o": return .open
        case "d": return .description
        case "r": return .related
        case "?": return .help
        case "q": return .quit
        default: return .character(ch)
        }
    }
}
```

**Step 2: Add tests**

Create `Tests/MacPipeCoreTests/TUIInputTests.swift`:

```swift
import XCTest
@testable import MacPipeCore

final class TUIInputTests: XCTestCase {
    func testParsesArrowKeys() {
        let parser = TUIInputParser()
        XCTAssertEqual(parser.parse(bytes: [27, 91, 65]), .moveUp)
        XCTAssertEqual(parser.parse(bytes: [27, 91, 66]), .moveDown)
    }

    func testParsesVisibleShortcuts() {
        let parser = TUIInputParser()
        XCTAssertEqual(parser.parse(bytes: Array("/".utf8)), .search)
        XCTAssertEqual(parser.parse(bytes: Array("a".utf8)), .audio)
        XCTAssertEqual(parser.parse(bytes: Array("o".utf8)), .open)
        XCTAssertEqual(parser.parse(bytes: Array("d".utf8)), .description)
        XCTAssertEqual(parser.parse(bytes: Array("r".utf8)), .related)
        XCTAssertEqual(parser.parse(bytes: Array("?".utf8)), .help)
        XCTAssertEqual(parser.parse(bytes: Array("q".utf8)), .quit)
    }

    func testParsesEnterEscapeBackspace() {
        let parser = TUIInputParser()
        XCTAssertEqual(parser.parse(bytes: [10]), .submit)
        XCTAssertEqual(parser.parse(bytes: [27]), .escape)
        XCTAssertEqual(parser.parse(bytes: [127]), .backspace)
    }
}
```

**Step 3: Run tests**

Run:

```bash
swift test --filter TUIInputTests
```

Expected: PASS.

---

## Task 3: Add Terminal ANSI Session Primitive

**Objective:** Create a tiny terminal writer that can enter/leave alternate screen and draw frames safely.

**Files:**
- Create: `Sources/MacPipeCLI/TerminalSession.swift`

**Step 1: Create terminal session**

Create `Sources/MacPipeCLI/TerminalSession.swift`:

```swift
import Foundation

struct TerminalSession {
    private let out = FileHandle.standardOutput

    func enterAlternateScreen() {
        write("\u{001B}[?1049h\u{001B}[?25l")
    }

    func leaveAlternateScreen() {
        write("\u{001B}[?25h\u{001B}[?1049l")
    }

    func clear() {
        write("\u{001B}[2J\u{001B}[H")
    }

    func draw(_ frame: String) {
        clear()
        write("\u{001B}[32m")
        write(frame)
        write("\u{001B}[0m")
    }

    func write(_ text: String) {
        if let data = text.data(using: .utf8) {
            out.write(data)
        }
    }
}
```

**Step 2: Build**

Run:

```bash
swift build
```

Expected: PASS.

---

## Task 4: Add `macpipe tty --snapshot` Smoke Mode

**Objective:** Add a safe, deterministic TUI preview that does not enter raw mode and can be tested in scripts.

**Files:**
- Modify: `Sources/MacPipeCLI/main.swift`
- Create: `Sources/MacPipeCLI/TUIRunner.swift`
- Modify: `scripts/test_cli.sh`

**Step 1: Add command dispatch**

In `Sources/MacPipeCLI/main.swift`, add before `case "test":`:

```swift
case "tty":
    do {
        let runner = TUIRunner()
        try await runner.run(args: Array(args.dropFirst(2)))
    } catch {
        print("TUI failed: \(error.localizedDescription)")
        exit(1)
    }
```

Update usage to include:

```text
macpipe tty                         Open green-screen terminal UI
macpipe tty --snapshot              Print deterministic TUI snapshot
```

**Step 2: Create runner**

Create `Sources/MacPipeCLI/TUIRunner.swift`:

```swift
import Foundation
import MacPipeCore

struct TUIRunner {
    func run(args: [String]) async throws {
        if args.contains("--snapshot") {
            let state = TUIState(
                screen: .results,
                query: "lofi coding music",
                results: [
                    SearchResult(id: "abc", title: "lofi hip hop radio", uploader: "Lofi Girl", duration: 43199, thumbnail: nil),
                    SearchResult(id: "def", title: "coding music for deep focus", uploader: "Focus Channel", duration: 7391, thumbnail: nil),
                    SearchResult(id: "ghi", title: "synthwave night drive", uploader: "Neon Wave", duration: 4364, thumbnail: nil)
                ],
                selectedIndex: 0,
                status: "yt-dlp READY"
            )
            print(TUIRenderer().render(state: state, width: 80, height: 24))
            return
        }

        let terminal = TerminalSession()
        terminal.enterAlternateScreen()
        defer { terminal.leaveAlternateScreen() }

        let state = TUIState(status: "READY")
        terminal.draw(TUIRenderer().render(state: state, width: 80, height: 24))
        try await Task.sleep(for: .seconds(2))
    }
}
```

**Step 3: Add shell test scenario**

Append to `scripts/test_cli.sh` before final success:

```bash
echo

echo "Scenario 8: TUI snapshot renders green-screen frame"
TUI_OUTPUT="$(run tty --snapshot 2>&1)" || fail "tty snapshot command failed"
echo "$TUI_OUTPUT" | grep -q "MACPIPE TERMINAL VIDEO SYSTEM" || fail "tty snapshot missing header"
echo "$TUI_OUTPUT" | grep -q "/ SEARCH" || fail "tty snapshot missing shortcut footer"
echo "$TUI_OUTPUT" | grep -q "lofi hip hop radio" || fail "tty snapshot missing sample result"
pass "tty snapshot renders expected frame"
```

**Step 4: Run verification**

Run:

```bash
swift build
scripts/test_cli.sh
```

Expected: PASS. If live YouTube scenarios fail due network/yt-dlp, run `swift run macpipe tty --snapshot` and `swift test` to verify the new TUI slice independently, then note the external failure.

---

## Task 5: Add Raw Terminal Input Reader

**Objective:** Enable interactive single-key input while restoring terminal settings safely.

**Files:**
- Create: `Sources/MacPipeCLI/RawTerminalInput.swift`
- Modify: `Sources/MacPipeCLI/TUIRunner.swift`

**Step 1: Create raw input helper**

Create `Sources/MacPipeCLI/RawTerminalInput.swift`:

```swift
import Foundation
import Darwin

final class RawTerminalInput {
    private var original = termios()
    private var enabled = false

    func enable() throws {
        guard !enabled else { return }
        guard tcgetattr(STDIN_FILENO, &original) == 0 else {
            throw CliError.invalidArguments("Failed to read terminal settings")
        }
        var raw = original
        raw.c_lflag &= ~(UInt(ECHO | ICANON))
        raw.c_cc.16 = 1  // VMIN on macOS Darwin layout
        raw.c_cc.17 = 0  // VTIME on macOS Darwin layout
        guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else {
            throw CliError.invalidArguments("Failed to enter raw terminal mode")
        }
        enabled = true
    }

    func disable() {
        guard enabled else { return }
        _ = tcsetattr(STDIN_FILENO, TCSANOW, &original)
        enabled = false
    }

    func readBytes() -> [UInt8] {
        var byte: UInt8 = 0
        let count = read(STDIN_FILENO, &byte, 1)
        guard count == 1 else { return [] }
        if byte == 27 {
            var sequence: [UInt8] = [27]
            var next: UInt8 = 0
            while read(STDIN_FILENO, &next, 1) == 1 {
                sequence.append(next)
                if sequence.count >= 3 { break }
            }
            return sequence
        }
        return [byte]
    }

    deinit {
        disable()
    }
}
```

**Note:** If Swift rejects `raw.c_cc.16`, replace with indexed constants if available in this toolchain:

```swift
raw.c_cc[Int(VMIN)] = 1
raw.c_cc[Int(VTIME)] = 0
```

**Step 2: Wire temporary interactive loop**

In `TUIRunner.run`, replace the 2-second sleep path with:

```swift
let terminal = TerminalSession()
let input = RawTerminalInput()
try input.enable()
terminal.enterAlternateScreen()
defer {
    input.disable()
    terminal.leaveAlternateScreen()
}

var state = TUIState(status: "READY")
let parser = TUIInputParser()
while true {
    terminal.draw(TUIRenderer().render(state: state, width: 80, height: 24))
    let action = parser.parse(bytes: input.readBytes())
    switch action {
    case .quit, .escape:
        return
    case .search:
        state.status = "SEARCH MODE COMING NEXT"
    case .moveDown:
        state.selectedIndex = min(state.selectedIndex + 1, max(0, state.results.count - 1))
    case .moveUp:
        state.selectedIndex = max(0, state.selectedIndex - 1)
    default:
        state.status = "KEY: \(String(describing: action))"
    }
}
```

**Step 3: Build**

Run:

```bash
swift build
```

Expected: PASS.

**Step 4: Manual verification**

Run:

```bash
swift run macpipe tty
```

Expected:
- Alternate full-screen frame appears.
- Pressing `/` changes status.
- Pressing `q` exits and restores terminal.

---

## Task 6: Add Search Mode in TUI

**Objective:** Let user press `/`, type query, press Enter, and see live search results.

**Files:**
- Modify: `Sources/MacPipeCLI/TUIRunner.swift`
- Modify: `Sources/MacPipeCore/TUI/TUIState.swift`
- Modify: `Sources/MacPipeCore/TUI/TUIRenderer.swift`

**Step 1: Add input mode**

In `TUIState.swift`, add:

```swift
public enum TUIInputMode: Sendable, Equatable {
    case normal
    case search
}
```

Add property to `TUIState`:

```swift
public var inputMode: TUIInputMode
```

Update init default:

```swift
inputMode: TUIInputMode = .normal
```

Set `self.inputMode = inputMode`.

**Step 2: Renderer should show search mode**

In renderer query line, show:

```swift
let queryPrefix = state.inputMode == .search ? " SEARCH> " : " QUERY: "
lines.append(padBox(queryPrefix + (state.query.isEmpty ? "" : state.query), status: "", width: safeWidth))
```

**Step 3: TUIRunner search behavior**

In the loop:

```swift
case .search:
    state.inputMode = .search
    state.query = ""
    state.status = "TYPE QUERY, ENTER TO SEARCH"
case .character(let ch):
    if state.inputMode == .search {
        state.query.append(ch)
    }
case .backspace:
    if state.inputMode == .search, !state.query.isEmpty {
        state.query.removeLast()
    }
case .submit:
    if state.inputMode == .search {
        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { break }
        state.inputMode = .normal
        state.status = "SEARCHING..."
        terminal.draw(TUIRenderer().render(state: state, width: 80, height: 24))
        do {
            let results = try await YtDlpClient().search(query: query, maxResults: 10)
            state.results = results
            state.selectedIndex = 0
            state.status = "RESULTS: \(results.count)"
        } catch {
            state.status = "SEARCH FAILED: \(error.localizedDescription)"
        }
    }
```

**Step 4: Manual verification**

Run:

```bash
swift run macpipe tty
```

Expected:
- `/` enters search mode.
- Typing shows query.
- Enter searches YouTube.
- Results render in list.
- Arrow keys move selection.
- `q` exits cleanly.

---

## Video Quality Requirement

MacPipe should get the best VLC-compatible video quality by default, without making the user think about YouTube format codes.

Quality policy:

```text
Default path: VLC + generated playlist using best combined video+audio stream
Audio path: best audio-only stream by abr
Optional future path: mpv adaptive bestvideo+bestaudio, if we later add mpv-specific support
```

Important distinction:

- The product target is “best VLC-compatible quality,” not absolute YouTube maximum quality.
- That means selecting the highest-quality combined stream that VLC can play reliably.
- Do not label adaptive video-only + audio-only as default unless we explicitly add a player/backend that handles it well.

CLI language:

```text
macpipe watch <query>              best VLC-compatible stream
macpipe watch <query> --player VLC best VLC-compatible stream
macpipe listen <query>             best available audio
```

Implementation implication:

- Keep VLC as the default video playback target.
- Improve `StreamInfo.bestVideoFormat` so it intentionally chooses the best combined VLC-compatible stream.
- Prefer non-HLS direct streams when reliable, but allow HLS only if VLC handles it better than available direct combined formats.
- Do not rely on mpv/adaptive selection as the default product path.

---

## Task 7: Add Open Selected in External Player

**Objective:** Press `O` or Enter to open selected result using the best VLC-compatible combined video+audio stream.

**Files:**
- Modify: `Sources/MacPipeCLI/main.swift`
- Create: `Sources/MacPipeCore/Playback/PlaylistWriter.swift`
- Create: `Sources/MacPipeCore/Playback/ExternalPlayerLauncher.swift`
- Modify: `Sources/MacPipeCLI/TUIRunner.swift`

**Step 1: Move reusable playlist functions to Core**

Create `Sources/MacPipeCore/Playback/PlaylistWriter.swift`:

```swift
import Foundation

public struct PlaylistWriter: Sendable {
    public init() {}

    public func sanitizeTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: ",", with: " -")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func write(title: String, streamURL: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("macpipe", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let playlistURL = dir.appendingPathComponent("now-playing-\(UUID().uuidString).m3u")
        let contents = """
        #EXTM3U
        #EXTINF:-1,\(sanitizeTitle(title))
        \(streamURL)
        """
        try contents.write(to: playlistURL, atomically: true, encoding: .utf8)
        return playlistURL
    }
}
```

Create `Sources/MacPipeCore/Playback/ExternalPlayerLauncher.swift`:

```swift
import Foundation

public struct ExternalPlayerLauncher: Sendable {
    public init() {}

    public func open(playlistURL: URL, player: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", player, playlistURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw YtDlpError.extractFailed("Failed to open \(player)")
        }
    }
}
```

**Step 2: Update CLI openVideoId to use Core helpers**

In `main.swift`, replace local `sanitizePlaylistTitle` and `writePlaylist` usage with `PlaylistWriter`.

Expected behavior should not change.

**Step 3: TUI open selected**

In `TUIRunner`, when action is `.open` or `.submit` in normal mode:

```swift
case .open, .submit:
    guard state.inputMode == .normal, let selected = state.selectedResult else { break }
    state.status = "RESOLVING STREAM..."
    terminal.draw(TUIRenderer().render(state: state, width: 80, height: 24))
    do {
        let info = try await YtDlpClient().extractInfo(videoId: selected.id)
        guard let stream = info.playableUrl else {
            state.status = "NO PLAYABLE STREAM"
            break
        }
        let playlist = try PlaylistWriter().write(title: info.title, streamURL: stream)
        try ExternalPlayerLauncher().open(playlistURL: playlist, player: "VLC")
        state.status = "OPENED: \(info.title)"
    } catch {
        state.status = "OPEN FAILED: \(error.localizedDescription)"
    }
```

**Step 4: Verify**

Run:

```bash
swift build
scripts/test_cli.sh
swift run macpipe tty
```

Expected:
- Existing CLI open/open-id tests pass.
- In TUI, searching and pressing `O` opens selected video in VLC.

---

## Task 8: Add Audio-Only Action

**Objective:** Press `A` to resolve and play the selected result audio-only from the TUI.

**Files:**
- Create: `Sources/MacPipeCore/Playback/AudioPlaybackService.swift`
- Modify: `Sources/MacPipeCLI/TUIRunner.swift`

**Step 1: Create service**

Create `Sources/MacPipeCore/Playback/AudioPlaybackService.swift`:

```swift
import Foundation
import AVFoundation

@MainActor
public final class AudioPlaybackService {
    private var player: AVPlayer?

    public init() {}

    public func play(url: URL) {
        player = AVPlayer(url: url)
        player?.play()
    }

    public func pause() {
        player?.pause()
    }

    public func stop() {
        player?.pause()
        player = nil
    }
}
```

**Step 2: Add service instance to TUIRunner**

In `TUIRunner.run`, create:

```swift
let audioService = AudioPlaybackService()
```

For `.audio` action:

```swift
case .audio:
    guard state.inputMode == .normal, let selected = state.selectedResult else { break }
    state.status = "RESOLVING AUDIO..."
    terminal.draw(TUIRenderer().render(state: state, width: 80, height: 24))
    do {
        let info = try await YtDlpClient().extractInfo(videoId: selected.id)
        guard let audio = info.bestAudioFormat, let url = URL(string: audio.url) else {
            state.status = "NO AUDIO STREAM"
            break
        }
        await audioService.play(url: url)
        state.status = "AUDIO: \(info.title)"
    } catch {
        state.status = "AUDIO FAILED: \(error.localizedDescription)"
    }
```

**Step 3: Add stop/pause later**

For MVP, `q` should call:

```swift
await audioService.stop()
```

**Step 4: Manual verification**

Run:

```bash
swift run macpipe tty
```

Expected:
- Search.
- Select item.
- Press `A`.
- Audio starts.
- `q` stops audio and exits.

---

## Task 9: Add Description Panel

**Objective:** Press `D` to fetch and display title/channel/description for the selected video.

**Files:**
- Modify: `Sources/MacPipeCore/TUI/TUIState.swift`
- Modify: `Sources/MacPipeCore/TUI/TUIRenderer.swift`
- Modify: `Sources/MacPipeCLI/TUIRunner.swift`

**Step 1: Add detail fields**

Add to `TUIState`:

```swift
public var selectedDescription: String?
public var selectedTitle: String?
```

Update init with defaults.

**Step 2: Render description**

Renderer should show:

```swift
if let description = state.selectedDescription {
    for line in description.split(separator: "\n").prefix(state.showFullDescription ? 8 : 3) {
        lines.append(padBox(" DESC: \(line)", status: "", width: safeWidth))
    }
}
```

Keep clipping to screen height.

**Step 3: Fetch on D**

In TUIRunner `.description`:

```swift
case .description:
    guard state.inputMode == .normal, let selected = state.selectedResult else { break }
    if state.selectedDescription != nil {
        state.showFullDescription.toggle()
        break
    }
    state.status = "FETCHING DESCRIPTION..."
    terminal.draw(TUIRenderer().render(state: state, width: 80, height: 24))
    do {
        let info = try await YtDlpClient().extractInfo(videoId: selected.id)
        state.selectedTitle = info.title
        state.selectedDescription = info.description ?? "No description available."
        state.showFullDescription = false
        state.status = "DESCRIPTION READY"
    } catch {
        state.status = "DESCRIPTION FAILED: \(error.localizedDescription)"
    }
```

**Step 4: Manual verification**

Run TUI, search, select item, press `D`.

Expected:
- Description appears.
- Pressing `D` again toggles more lines.

---

## Task 10: Add Related/Recommendations MVP

**Objective:** Press `R` to load useful related results without relying on private YouTube recommendation APIs.

**Files:**
- Create: `Sources/MacPipeCore/Recommendations/RecommendationQueryBuilder.swift`
- Modify: `Sources/MacPipeCLI/TUIRunner.swift`
- Modify: `Sources/MacPipeCore/TUI/TUIRenderer.swift`

**Step 1: Create query builder**

Create `Sources/MacPipeCore/Recommendations/RecommendationQueryBuilder.swift`:

```swift
import Foundation

public struct RecommendationQueryBuilder: Sendable {
    public init() {}

    public func relatedQuery(for result: SearchResult) -> String {
        let title = result.title
            .replacingOccurrences(of: "|", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        if !result.uploader.isEmpty {
            return "\(result.uploader) \(title)"
        }
        return title
    }
}
```

**Step 2: Wire R action**

In TUIRunner `.related`:

```swift
case .related:
    guard state.inputMode == .normal, let selected = state.selectedResult else { break }
    let relatedQuery = RecommendationQueryBuilder().relatedQuery(for: selected)
    state.status = "RELATED: \(relatedQuery)"
    terminal.draw(TUIRenderer().render(state: state, width: 80, height: 24))
    do {
        let results = try await YtDlpClient().search(query: relatedQuery, maxResults: 10)
        state.query = relatedQuery
        state.results = results
        state.selectedIndex = 0
        state.selectedDescription = nil
        state.status = "RELATED RESULTS: \(results.count)"
    } catch {
        state.status = "RELATED FAILED: \(error.localizedDescription)"
    }
```

**Step 3: Verify**

Manual TUI test:
- Search.
- Select result.
- Press `R`.
- Related search replaces list.

Expected: new results appear.

---

## Task 11: Polish Green-Screen Styling

**Objective:** Make the TUI visually distinct while keeping it fast and readable.

**Files:**
- Modify: `Sources/MacPipeCLI/TerminalSession.swift`
- Modify: `Sources/MacPipeCore/TUI/TUIRenderer.swift`

**Step 1: Add ANSI style helpers**

In `TerminalSession`, use:

```swift
let green = "\u{001B}[38;5;46m"
let dimGreen = "\u{001B}[38;5;28m"
let amber = "\u{001B}[38;5;220m"
let reset = "\u{001B}[0m"
```

Keep renderer mostly style-free if possible. Styling can be applied at terminal layer first.

**Step 2: Add boot splash**

Before first frame in `TUIRunner`:

```swift
terminal.draw("""
╔══════════════════════════════════════════════════════════════════════════════╗
║                    MACPIPE TERMINAL VIDEO SYSTEM                            ║
║                    INITIALIZING YT-DLP INTERFACE                            ║
║                    STATUS: READY                                            ║
╚══════════════════════════════════════════════════════════════════════════════╝
""")
try await Task.sleep(for: .milliseconds(350))
```

**Step 3: Verify terminal restore still works**

Run:

```bash
swift run macpipe tty
```

Expected:
- Boot splash appears briefly.
- TUI opens.
- `q` exits and terminal prompt is normal.

---

## Task 12: Add Minimal Config and Player Preference

**Objective:** Store default external player without adding a heavy settings system.

**Files:**
- Create: `Sources/MacPipeCore/Config/MacPipeConfig.swift`
- Modify: `Sources/MacPipeCLI/TUIRunner.swift`

**Step 1: Create config model**

```swift
import Foundation

public struct MacPipeConfig: Codable, Sendable, Equatable {
    public var defaultPlayer: String
    public var searchLimit: Int

    public init(defaultPlayer: String = "VLC", searchLimit: Int = 10) {
        self.defaultPlayer = defaultPlayer
        self.searchLimit = searchLimit
    }
}

public struct MacPipeConfigStore: Sendable {
    public init() {}

    public var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/macpipe/config.json")
    }

    public func load() -> MacPipeConfig {
        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(MacPipeConfig.self, from: data)
        } catch {
            return MacPipeConfig()
        }
    }

    public func save(_ config: MacPipeConfig) throws {
        let dir = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(config)
        try data.write(to: configURL, options: .atomic)
    }
}
```

**Step 2: Use config in TUIRunner**

Load at start:

```swift
let config = MacPipeConfigStore().load()
```

Use `config.searchLimit` for search and `config.defaultPlayer` for open.

**Step 3: Verify default behavior unchanged**

Run:

```bash
swift build
scripts/test_cli.sh
```

Expected: PASS.

---

## Task 13: Add History Later, Not First

**Objective:** Preserve searches/plays after the core TUI loop feels good.

Do not implement until after Tasks 1–12 are usable.

Proposed later files:

- `Sources/MacPipeCore/History/HistoryStore.swift`
- `~/.local/share/macpipe/history.jsonl`

Events:

```json
{"type":"search","query":"lofi","at":"2026-05-29T20:00:00Z"}
{"type":"play","id":"abc","title":"Lofi Radio","mode":"external","at":"2026-05-29T20:01:00Z"}
```

Later shortcut:

- `H` shows history.
- `Enter` replays selected history item.

---

## Final Verification Checklist

Before claiming the MVP works:

```bash
cd /Users/ginugeorge/macpipe
swift build
swift test
scripts/test_cli.sh
swift run macpipe tty --snapshot
```

Manual smoke:

```bash
swift run macpipe tty
```

Check:

- `/` enters search mode.
- Query text appears.
- Enter searches.
- Results display.
- Arrow keys move selection.
- `O` opens selected result in configured external player.
- `A` plays audio-only.
- `D` shows description.
- `R` loads related results.
- `Q` exits cleanly and terminal is restored.

---

## Risks and Guards

- Terminal raw mode can corrupt the shell if not restored. Always use `defer` to disable raw mode and leave alternate screen.
- yt-dlp calls can be slow. Always show status before awaiting search/extract.
- Search/extract can fail due YouTube changes. Keep errors visible in the status bar, not as crashes.
- Keep existing CLI commands stable. They are the regression harness.
- Avoid adding a large TUI framework until custom ANSI proves insufficient.
- Avoid in-terminal video. The TUI is the console; external players are the renderer.

---

## Execution Notes

Recommended execution mode:

1. Implement Tasks 1–4 first as one safe vertical slice.
2. Verify renderer snapshot and CLI tests.
3. Then implement raw input and live search.
4. Only after that wire playback.

Do not implement history/favorites/config polish before the basic TUI loop feels good.
