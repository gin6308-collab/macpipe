import Foundation
import Darwin
import MacPipeCore

struct TUIRunnerOptions {
    var colorMode: TUIColorMode = .never
    var limit: Int = 5
    var player: String = "VLC"
    var width: Int?
    var height: Int?
    var qualityMode: SearchQualityMode = .normal
    var contentMode: SearchContentMode = .general
    var allowShorts = false
    var dryRun = false
    var scripted = false
    var mock = false
    var demoResults = false
    var snapshot = false
    var homeSnapshot = false
    var postPlaybackSnapshot = false

    func frameSize(defaultWidth: Int = 96, defaultHeight: Int = 24) -> (width: Int, height: Int) {
        (
            width: max(40, width ?? defaultWidth),
            height: max(10, height ?? defaultHeight)
        )
    }
}

struct TUIRunner {
    func run(args: [String]) async throws {
        let options = try parseOptions(args)
        if options.snapshot {
            runSnapshot(options: options)
            return
        }

        if options.scripted {
            let input = FileHandle.standardInput.readDataToEndOfFile()
            try await runLoop(options: options, scriptedInput: Array(input), drawMode: .plain)
            return
        }

        try await runLoop(options: options, scriptedInput: nil, drawMode: .alternateScreen)
    }

    private enum DrawMode {
        case plain
        case alternateScreen
    }

    private func parseOptions(_ args: [String]) throws -> TUIRunnerOptions {
        var options = TUIRunnerOptions()
        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--snapshot":
                options.snapshot = true
                i += 1
            case "--home":
                options.homeSnapshot = true
                i += 1
            case "--post-playback":
                options.postPlaybackSnapshot = true
                i += 1
            case "--color":
                options.colorMode = .always
                i += 1
            case "--no-color":
                options.colorMode = .never
                i += 1
            case "--dry-run":
                options.dryRun = true
                i += 1
            case "--scripted":
                options.scripted = true
                options.colorMode = .never
                i += 1
            case "--mock":
                options.mock = true
                i += 1
            case "--demo-results":
                options.mock = true
                options.demoResults = true
                i += 1
            case "--limit":
                guard i + 1 < args.count, let value = Int(args[i + 1]), value > 0 else {
                    throw CliError.invalidArguments("tty --limit requires a positive integer")
                }
                options.limit = value
                i += 2
            case "--player":
                guard i + 1 < args.count else {
                    throw CliError.invalidArguments("tty --player requires an app name")
                }
                options.player = args[i + 1]
                i += 2
            case "--width":
                guard i + 1 < args.count, let value = Int(args[i + 1]), value > 0 else {
                    throw CliError.invalidArguments("tty --width requires a positive integer")
                }
                options.width = value
                i += 2
            case "--height":
                guard i + 1 < args.count, let value = Int(args[i + 1]), value > 0 else {
                    throw CliError.invalidArguments("tty --height requires a positive integer")
                }
                options.height = value
                i += 2
            case "--quality":
                guard i + 1 < args.count, let mode = SearchQualityMode(rawValue: args[i + 1].lowercased()) else {
                    throw CliError.invalidArguments("tty --quality requires off, normal, or strict")
                }
                options.qualityMode = mode
                i += 2
            case "--mode":
                guard i + 1 < args.count, let mode = SearchContentMode(rawValue: args[i + 1].lowercased()) else {
                    throw CliError.invalidArguments("tty --mode requires general, education, or entertainment")
                }
                options.contentMode = mode
                i += 2
            case "--allow-shorts":
                options.allowShorts = true
                i += 1
            default:
                throw CliError.invalidArguments("unexpected tty argument: \(arg)")
            }
        }
        return options
    }

    private func runSnapshot(options: TUIRunnerOptions) {
        let defaultSize = options.frameSize(defaultWidth: 96, defaultHeight: 24)
        let compactSize = options.frameSize(defaultWidth: 80, defaultHeight: 24)

        if options.homeSnapshot {
            let homeState = TUIState(
                screen: .home,
                query: "",
                results: [],
                selectedIndex: 0,
                status: "VIDEO · VLC READY · yt-dlp READY"
            )
            print(TUIRenderer().render(state: homeState, width: defaultSize.width, height: defaultSize.height, colorMode: options.colorMode))
            return
        }

        if options.postPlaybackSnapshot {
            let state = TUIState(
                screen: .postPlayback,
                query: "qwen 3.7",
                results: TUIRunner.demoResults,
                selectedIndex: 0,
                status: "PLAYBACK SENT TO VLC"
            )
            print(TUIRenderer().render(state: state, width: compactSize.width, height: compactSize.height, colorMode: options.colorMode))
            return
        }

        let state = TUIState(
            screen: .results,
            query: "lofi coding music",
            results: TUIRunner.demoResults,
            selectedIndex: 0,
            status: "yt-dlp READY"
        )
        print(TUIRenderer().render(state: state, width: compactSize.width, height: compactSize.height, colorMode: options.colorMode))
    }

    private func runLoop(options: TUIRunnerOptions, scriptedInput: [UInt8]?, drawMode: DrawMode) async throws {
        let renderer = TUIRenderer()
        let reducer = TUIReducer()
        let parser = TUIInputParser()
        let client = YtDlpClient()
        let terminal = TerminalSession()
        var state = TUIState(screen: .home, status: "VIDEO · VLC READY · yt-dlp READY")
        if options.demoResults {
            state = TUIState(
                screen: .results,
                query: "demo search",
                results: Array(TUIRunner.demoResults.prefix(options.limit)),
                selectedIndex: 0,
                status: "DEMO RESULTS · MOCK SEARCH READY"
            )
        }
        var terminalSize = options.frameSize(defaultWidth: 96, defaultHeight: 24)
        var shouldQuitPlayerOnExit = false

        func refreshTerminalSize() {
            guard options.width == nil || options.height == nil else { return }
            let detected = terminal.currentSize(defaultWidth: terminalSize.width, defaultHeight: terminalSize.height)
            terminalSize = (
                width: max(40, options.width ?? detected.width),
                height: max(10, options.height ?? detected.height)
            )
        }

        func render() {
            if drawMode == .alternateScreen { refreshTerminalSize() }
            let frame = renderer.render(state: state, width: terminalSize.width, height: terminalSize.height, colorMode: options.colorMode)
            switch drawMode {
            case .plain:
                print(frame)
            case .alternateScreen:
                terminal.draw(frame)
            }
        }

        func log(_ message: String) {
            if drawMode == .plain { print(message) }
        }

        func apply(_ action: TUIAction) async throws -> Bool {
            let transition = reducer.reduce(state: state, action: action)
            state = transition.state
            render()

            switch transition.effect {
            case .none:
                return true
            case .quit:
                log("TUI effect: quit")
                return false
            case .search(let query):
                log("TUI effect: search \(query)")
                let results: [SearchResult]
                if options.mock {
                    results = Array(TUIRunner.demoResults.prefix(options.limit))
                } else {
                    let policy = SearchQualityPolicy(mode: options.qualityMode, contentMode: options.contentMode, allowShorts: options.allowShorts, displayLimit: options.limit)
                    let rawResults = try await client.search(query: query, maxResults: policy.fetchLimit)
                    results = SearchQualityScorer().filter(rawResults, query: query, policy: policy).accepted
                }
                state = reducer.receiveResults(state: state, results: results)
                render()
                return true
            case .play(let resultID):
                log("TUI effect: play \(resultID)")
                if options.mock, let selected = state.selectedResult {
                    print("Would open with \(options.player): \(selected.title)")
                } else {
                    try await openVideoId(resultID, player: options.player, dryRun: options.dryRun)
                }
                if options.player.caseInsensitiveCompare("VLC") == .orderedSame {
                    shouldQuitPlayerOnExit = true
                }
                state = reducer.markPlaybackSent(state: state)
                render()
                return true
            }
        }

        defer {
            if shouldQuitPlayerOnExit {
                quitPlayerOnMacPipeExit(player: options.player, dryRun: options.dryRun)
            }
        }

        switch drawMode {
        case .plain:
            render()
            if let scriptedInput {
                for byte in scriptedInput {
                    let action = parser.parse(bytes: [byte], state: state)
                    if try await !apply(action) { break }
                }
            }
        case .alternateScreen:
            terminal.enterAlternateScreen()
            var originalMode: termios?
            defer {
                if let originalMode {
                    TerminalSession.restoreMode(originalMode)
                }
                terminal.leaveAlternateScreen()
            }
            originalMode = try TerminalSession.enableRawMode()
            render()
            while true {
                let data = FileHandle.standardInput.readData(ofLength: 1)
                if data.isEmpty {
                    let previousSize = terminalSize
                    refreshTerminalSize()
                    if previousSize.width != terminalSize.width || previousSize.height != terminalSize.height {
                        render()
                    }
                    continue
                }
                var bytes = Array(data)
                if bytes == [27] {
                    let rest = FileHandle.standardInput.readData(ofLength: 2)
                    bytes.append(contentsOf: Array(rest))
                }
                let action = parser.parse(bytes: bytes, state: state)
                if try await !apply(action) { break }
            }
        }
    }

    private static let demoResults = [
        SearchResult(id: "abc", title: "lofi hip hop radio", uploader: "Lofi Girl", duration: 43199, thumbnail: nil),
        SearchResult(id: "def", title: "coding music for deep focus", uploader: "Focus Channel", duration: 7391, thumbnail: nil),
        SearchResult(id: "ghi", title: "synthwave night drive", uploader: "Neon Wave", duration: 4364, thumbnail: nil),
        SearchResult(id: "jkl", title: "Qwen 3.7 Max hands-on demo", uploader: "AI Lab Notes", duration: 842, thumbnail: nil),
        SearchResult(id: "mno", title: "terminal-native media launcher walkthrough", uploader: "MacPipe", duration: 615, thumbnail: nil)
    ]
}
