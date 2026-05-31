import Foundation
import AVFoundation
import MacPipeCore

struct SearchOptions {
    var queryParts: [String] = []
    var limit: Int = 10
    var jsonMode = false
    var playIndex: Int?
    var qualityMode: SearchQualityMode = .normal
    var contentMode: SearchContentMode = .general
    var allowShorts = false
    var qualityDebug = false
}

struct ListenOptions {
    var queryParts: [String] = []
    var limit: Int = 5
    var index: Int = 1
    var dryRun = false
}

struct OpenOptions {
    var queryParts: [String] = []
    var limit: Int = 5
    var index: Int = 1
    var player: String = "VLC"
    var dryRun = false
    var qualityMode: SearchQualityMode = .normal
    var contentMode: SearchContentMode = .general
    var allowShorts = false
    var qualityDebug = false
}

struct OpenIdOptions {
    var videoIdOrUrl: String = ""
    var player: String = "VLC"
    var dryRun = false
}

func parseQualityMode(_ value: String) throws -> SearchQualityMode {
    guard let mode = SearchQualityMode(rawValue: value.lowercased()) else {
        throw CliError.invalidArguments("--quality must be one of: off, normal, strict")
    }
    return mode
}

func parseContentMode(_ value: String) throws -> SearchContentMode {
    guard let mode = SearchContentMode(rawValue: value.lowercased()) else {
        throw CliError.invalidArguments("--mode must be one of: general, education, entertainment")
    }
    return mode
}

func parseSearchOptions(_ args: [String]) throws -> SearchOptions {
    var options = SearchOptions()
    var i = 0
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--json":
            options.jsonMode = true
            i += 1
        case "--limit":
            guard i + 1 < args.count, let value = Int(args[i + 1]), value > 0 else {
                throw CliError.invalidArguments("--limit requires a positive integer")
            }
            options.limit = value
            i += 2
        case "--play":
            guard i + 1 < args.count, let value = Int(args[i + 1]), value > 0 else {
                throw CliError.invalidArguments("--play requires a positive integer")
            }
            options.playIndex = value
            i += 2
        case "--quality":
            guard i + 1 < args.count else {
                throw CliError.invalidArguments("--quality requires off, normal, or strict")
            }
            options.qualityMode = try parseQualityMode(args[i + 1])
            i += 2
        case "--mode":
            guard i + 1 < args.count else {
                throw CliError.invalidArguments("--mode requires general, education, or entertainment")
            }
            options.contentMode = try parseContentMode(args[i + 1])
            i += 2
        case "--allow-shorts":
            options.allowShorts = true
            i += 1
        case "--quality-debug":
            options.qualityDebug = true
            i += 1
        default:
            options.queryParts.append(arg)
            i += 1
        }
    }
    guard !options.queryParts.isEmpty else {
        throw CliError.invalidArguments("search requires a query")
    }
    return options
}

func parseListenOptions(_ args: [String]) throws -> ListenOptions {
    var options = ListenOptions()
    var i = 0
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--dry-run":
            options.dryRun = true
            i += 1
        case "--limit":
            guard i + 1 < args.count, let value = Int(args[i + 1]), value > 0 else {
                throw CliError.invalidArguments("--limit requires a positive integer")
            }
            options.limit = value
            i += 2
        case "--index":
            guard i + 1 < args.count, let value = Int(args[i + 1]), value > 0 else {
                throw CliError.invalidArguments("--index requires a positive integer")
            }
            options.index = value
            i += 2
        default:
            options.queryParts.append(arg)
            i += 1
        }
    }
    guard !options.queryParts.isEmpty else {
        throw CliError.invalidArguments("listen requires a query")
    }
    return options
}

func parseOpenOptions(_ args: [String]) throws -> OpenOptions {
    var options = OpenOptions()
    var i = 0
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--dry-run":
            options.dryRun = true
            i += 1
        case "--limit":
            guard i + 1 < args.count, let value = Int(args[i + 1]), value > 0 else {
                throw CliError.invalidArguments("--limit requires a positive integer")
            }
            options.limit = value
            i += 2
        case "--index":
            guard i + 1 < args.count, let value = Int(args[i + 1]), value > 0 else {
                throw CliError.invalidArguments("--index requires a positive integer")
            }
            options.index = value
            i += 2
        case "--player":
            guard i + 1 < args.count else {
                throw CliError.invalidArguments("--player requires an app name")
            }
            options.player = args[i + 1]
            i += 2
        case "--quality":
            guard i + 1 < args.count else {
                throw CliError.invalidArguments("--quality requires off, normal, or strict")
            }
            options.qualityMode = try parseQualityMode(args[i + 1])
            i += 2
        case "--mode":
            guard i + 1 < args.count else {
                throw CliError.invalidArguments("--mode requires general, education, or entertainment")
            }
            options.contentMode = try parseContentMode(args[i + 1])
            i += 2
        case "--allow-shorts":
            options.allowShorts = true
            i += 1
        case "--quality-debug":
            options.qualityDebug = true
            i += 1
        default:
            options.queryParts.append(arg)
            i += 1
        }
    }
    guard !options.queryParts.isEmpty else {
        throw CliError.invalidArguments("open requires a query")
    }
    return options
}

func parseOpenIdOptions(_ args: [String]) throws -> OpenIdOptions {
    guard !args.isEmpty else {
        throw CliError.invalidArguments("open-id requires a video ID or URL")
    }
    var options = OpenIdOptions(videoIdOrUrl: args[0])
    var i = 1
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--dry-run":
            options.dryRun = true
            i += 1
        case "--player":
            guard i + 1 < args.count else {
                throw CliError.invalidArguments("--player requires an app name")
            }
            options.player = args[i + 1]
            i += 2
        default:
            throw CliError.invalidArguments("unexpected argument for open-id: \(arg)")
        }
    }
    return options
}

enum CliError: Error, LocalizedError {
    case invalidArguments(String)
    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message): return message
        }
    }
}

let args = CommandLine.arguments

guard args.count > 1 else {
    printUsage()
    exit(1)
}

let command = args[1]

switch command {
case "search", "find":
    do {
        let options = try parseSearchOptions(Array(args.dropFirst(2)))
        let query = options.queryParts.joined(separator: " ")
        try await runSearch(
            query: query,
            limit: options.limit,
            jsonMode: options.jsonMode,
            playIndex: options.playIndex,
            qualityMode: options.qualityMode,
            contentMode: options.contentMode,
            allowShorts: options.allowShorts,
            qualityDebug: options.qualityDebug
        )
    } catch {
        print("Search failed: \(error.localizedDescription)")
        exit(1)
    }

case "play":
    guard args.count > 2 else {
        print("Error: play requires a video ID")
        print("Usage: macpipe play <video_id> [--audio-only]")
        exit(1)
    }
    let videoId = args[2]
    let audioOnly = args.contains("--audio-only")

    do {
        try await runPlay(videoId: videoId, audioOnly: audioOnly)
    } catch {
        print("Play failed: \(error.localizedDescription)")
        exit(1)
    }

case "listen":
    do {
        let options = try parseListenOptions(Array(args.dropFirst(2)))
        let query = options.queryParts.joined(separator: " ")
        try await runListen(query: query, limit: options.limit, index: options.index, dryRun: options.dryRun)
    } catch {
        print("Listen failed: \(error.localizedDescription)")
        exit(1)
    }

case "open", "watch":
    do {
        let options = try parseOpenOptions(Array(args.dropFirst(2)))
        let query = options.queryParts.joined(separator: " ")
        try await runOpen(query: query, limit: options.limit, index: options.index, player: options.player, dryRun: options.dryRun, qualityMode: options.qualityMode, contentMode: options.contentMode, allowShorts: options.allowShorts, qualityDebug: options.qualityDebug)
    } catch {
        print("Open failed: \(error.localizedDescription)")
        exit(1)
    }

case "open-id":
    do {
        let options = try parseOpenIdOptions(Array(args.dropFirst(2)))
        try await runOpenId(videoIdOrUrl: options.videoIdOrUrl, player: options.player, dryRun: options.dryRun)
    } catch {
        print("Open-id failed: \(error.localizedDescription)")
        exit(1)
    }

case "tty":
    do {
        let runner = TUIRunner()
        try await runner.run(args: Array(args.dropFirst(2)))
    } catch {
        print("TUI failed: \(error.localizedDescription)")
        exit(1)
    }

case "test":
    await runTests()

case "help", "-h", "--help":
    printUsage()

default:
    do {
        let options = try parseOpenOptions(Array(args.dropFirst(1)))
        let query = options.queryParts.joined(separator: " ")
        try await runPromptedOpen(query: query, limit: options.limit, player: options.player, dryRun: options.dryRun, qualityMode: options.qualityMode, contentMode: options.contentMode, allowShorts: options.allowShorts, qualityDebug: options.qualityDebug)
    } catch {
        print("Open failed: \(error.localizedDescription)")
        printUsage()
        exit(1)
    }
}

func qualityPolicy(mode: SearchQualityMode, contentMode: SearchContentMode, allowShorts: Bool, displayLimit: Int) -> SearchQualityPolicy {
    SearchQualityPolicy(mode: mode, contentMode: contentMode, allowShorts: allowShorts, displayLimit: displayLimit)
}

func qualityFilter(results: [SearchResult], query: String, policy: SearchQualityPolicy) -> SearchQualityEvaluation {
    SearchQualityScorer().filter(results, query: query, policy: policy)
}

func printQualityDebug(_ evaluation: SearchQualityEvaluation) {
    print("Quality decisions:")
    for decision in evaluation.acceptedDecisions {
        print("+ [\(decision.originalIndex + 1)] \(decision.result.title)")
        print("    quality \(decision.score): \(decision.reasons.joined(separator: ", "))")
    }
    let hidden = evaluation.hidden
    if !hidden.isEmpty {
        print("\nHidden:")
        for decision in hidden {
            print("- [\(decision.originalIndex + 1)] \(decision.result.title)")
            print("    \(decision.rejectionReason ?? "hidden"): \(decision.reasons.joined(separator: ", "))")
        }
    }
    print()
}

func runSearch(query: String, limit: Int, jsonMode: Bool, playIndex: Int?, qualityMode: SearchQualityMode = .normal, contentMode: SearchContentMode = .general, allowShorts: Bool = false, qualityDebug: Bool = false) async throws {
    if !jsonMode {
        print("macpipe v0.1.0")
        print("================\n")
        print("Searching for: \(query)\n")
    }

    let client = YtDlpClient()
    let policy = qualityPolicy(mode: qualityMode, contentMode: contentMode, allowShorts: allowShorts, displayLimit: limit)
    let rawResults = try await client.search(query: query, maxResults: policy.fetchLimit)
    let evaluation = qualityFilter(results: rawResults, query: query, policy: policy)
    let results = evaluation.accepted

    if qualityDebug && !jsonMode {
        printQualityDebug(evaluation)
    }

    if results.isEmpty {
        if jsonMode {
            print("[]")
        } else {
            print("No results found")
        }
        return
    }

    if jsonMode {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(results)
        print(String(data: data, encoding: .utf8)!)
    } else {
        print("Results (\(results.count)):\n")
        for (index, result) in results.enumerated() {
            print("[\(index + 1)] \(result.title)")
            print("    ID: \(result.id)")
            print("    Duration: \(result.durationFormatted)")
            print("    Uploader: \(result.uploader)")
            print()
        }
    }

    if let playIndex = playIndex {
        guard playIndex > 0 && playIndex <= results.count else {
            print("Error: --play index out of range (1-\(results.count))")
            return
        }
        let selected = results[playIndex - 1]
        print("\n▶ Playing #\(playIndex): \(selected.title)\n")
        try await runPlay(videoId: selected.id, audioOnly: false)
    }
}

func runPlay(videoId: String, audioOnly: Bool) async throws {
    print("macpipe v0.1.0")
    print("================\n")
    print("Extracting info for: \(videoId)")

    let client = YtDlpClient()
    let info = try await client.extractInfo(videoId: videoId)

    print("Title: \(info.title)")
    print("Formats available: \(info.formats.count)")

    if audioOnly {
        guard let audio = info.bestAudioFormat else {
            print("Error: No audio-only format available")
            return
        }
        print("\nAudio stream: \(audio.ext) @ \(Int(audio.abr ?? 0))kbps")
        print("URL: \(audio.url)\n")
    } else {
        guard let video = info.bestVideoFormat else {
            print("Error: No video format with audio available")
            if let url = info.playableUrl {
                print("Fallback URL: \(url)\n")
            }
            return
        }
        print("\nVideo stream: \(video.ext) @ \(Int(video.tbr ?? 0))kbps")
        print("Resolution: \(video.format_note ?? "unknown")")
        print("URL: \(video.url)\n")
    }
}

func runListen(query: String, limit: Int, index: Int, dryRun: Bool) async throws {
    print("macpipe v0.1.0")
    print("================\n")
    print("Searching for: \(query)")

    let client = YtDlpClient()
    let results = try await client.search(query: query, maxResults: limit)
    guard index > 0 && index <= results.count else {
        throw CliError.invalidArguments("--index out of range (1-\(results.count))")
    }

    let selected = results[index - 1]
    print("Selected [\(index)]: \(selected.title)")
    print("Video ID: \(selected.id)")
    print("Extracting audio stream…")

    let info = try await client.extractInfo(videoId: selected.id)
    guard let audio = info.bestAudioFormat, let url = URL(string: audio.url) else {
        throw CliError.invalidArguments("No audio-only stream available")
    }

    if dryRun {
        print("Would play: \(info.title)")
        print("Audio stream: \(audio.ext) @ \(Int(audio.abr ?? 0))kbps")
        print("URL: \(audio.url)")
        return
    }

    print("Now playing: \(info.title)")
    print("Audio stream: \(audio.ext) @ \(Int(audio.abr ?? 0))kbps")
    print("Press Ctrl+C to stop.")

    let player = AVPlayer(url: url)
    player.play()
    RunLoop.current.run()
}

func runPromptedOpen(query: String, limit: Int, player: String, dryRun: Bool, qualityMode: SearchQualityMode = .normal, contentMode: SearchContentMode = .general, allowShorts: Bool = false, qualityDebug: Bool = false) async throws {
    print("macpipe v0.1.0")
    print("================\n")

    let client = YtDlpClient()
    var currentQuery = query
    var results: [SearchResult] = []
    var shouldQuitPlayerOnExit = false
    defer {
        if shouldQuitPlayerOnExit {
            quitPlayerOnMacPipeExit(player: player, dryRun: dryRun)
        }
    }

    func searchAndPrint(_ query: String) async throws {
        print("Searching for: \(query)\n")
        let policy = qualityPolicy(mode: qualityMode, contentMode: contentMode, allowShorts: allowShorts, displayLimit: limit)
        let rawResults = try await client.search(query: query, maxResults: policy.fetchLimit)
        let evaluation = qualityFilter(results: rawResults, query: query, policy: policy)
        results = evaluation.accepted
        if qualityDebug {
            printQualityDebug(evaluation)
        }
        guard !results.isEmpty else {
            print("No results found")
            return
        }

        print("Results (\(results.count)):\n")
        for (index, result) in results.enumerated() {
            print("[\(index + 1)] \(result.title)")
            print("    ID: \(result.id)")
            print("    Duration: \(result.durationFormatted)")
            print("    Uploader: \(result.uploader)")
            print()
        }
    }

    try await searchAndPrint(currentQuery)

    while true {
        guard !results.isEmpty else { return }
        print("Which number should I play? Enter a number, S to search, or X to exit: ", terminator: "")
        guard let answer = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            print("\nExiting.")
            return
        }

        if answer.caseInsensitiveCompare("x") == .orderedSame {
            print("Exiting.")
            return
        }

        if answer.caseInsensitiveCompare("s") == .orderedSame {
            print("Search for: ", terminator: "")
            guard let newQuery = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !newQuery.isEmpty else {
                print("No search entered. Exiting.")
                return
            }
            currentQuery = newQuery
            print()
            try await searchAndPrint(currentQuery)
            continue
        }

        guard let selectedIndex = Int(answer), selectedIndex > 0, selectedIndex <= results.count else {
            print("Please enter a number from 1 to \(results.count), S to search, or X to exit.")
            continue
        }

        let selected = results[selectedIndex - 1]
        print("\nSelected [\(selectedIndex)]: \(selected.title)")
        print("Video ID: \(selected.id)")
        try await openVideoId(selected.id, player: player, dryRun: dryRun)
        if player.caseInsensitiveCompare("VLC") == .orderedSame {
            shouldQuitPlayerOnExit = true
        }
        print()
    }
}

func runOpen(query: String, limit: Int, index: Int, player: String, dryRun: Bool, qualityMode: SearchQualityMode = .normal, contentMode: SearchContentMode = .general, allowShorts: Bool = false, qualityDebug: Bool = false) async throws {
    print("macpipe v0.1.0")
    print("================\n")
    print("Searching for: \(query)")

    let client = YtDlpClient()
    let policy = qualityPolicy(mode: qualityMode, contentMode: contentMode, allowShorts: allowShorts, displayLimit: limit)
    let rawResults = try await client.search(query: query, maxResults: policy.fetchLimit)
    let evaluation = qualityFilter(results: rawResults, query: query, policy: policy)
    let results = evaluation.accepted
    if qualityDebug {
        printQualityDebug(evaluation)
    }
    guard index > 0 && index <= results.count else {
        throw CliError.invalidArguments("--index out of range (1-\(results.count))")
    }

    let selected = results[index - 1]
    print("Selected [\(index)]: \(selected.title)")
    print("Video ID: \(selected.id)")
    try await openVideoId(selected.id, player: player, dryRun: dryRun)
}

func runOpenId(videoIdOrUrl: String, player: String, dryRun: Bool) async throws {
    print("macpipe v0.1.0")
    print("================\n")
    print("Opening exact video: \(videoIdOrUrl)")
    try await openVideoId(videoIdOrUrl, player: player, dryRun: dryRun)
}

func openVideoId(_ videoIdOrUrl: String, player: String, dryRun: Bool) async throws {
    print("Extracting video stream…")

    let client = YtDlpClient()
    let info = try await client.extractInfo(videoId: videoIdOrUrl)
    guard let url = info.playableUrl else {
        throw CliError.invalidArguments("No playable video URL available")
    }

    let title = sanitizePlaylistTitle(info.title)
    let playlistURL = try writePlaylist(title: title, streamURL: url)

    if dryRun {
        print("Would open with \(player): \(info.title)")
        print("Playback mode: streaming URL via temporary XSPF playlist (no download)")
        if player.caseInsensitiveCompare("VLC") == .orderedSame {
            print("VLC cleanup: --play-and-exit")
        }
        print("Playlist title: \(title)")
        print("Playlist: \(playlistURL.path)")
        print("URL: \(url)")
        return
    }

    if player.caseInsensitiveCompare("VLC") == .orderedSame {
        try launchVLCAndExitWhenDone(playlistURL: playlistURL)
    } else {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", player, playlistURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CliError.invalidArguments("Failed to open \(player) with playlist")
        }
    }
    print("Opened with \(player): \(info.title)")
    print("Playlist: \(playlistURL.path)")
}

func quitPlayerOnMacPipeExit(player: String, dryRun: Bool) {
    guard player.caseInsensitiveCompare("VLC") == .orderedSame else { return }

    if dryRun {
        print("Would quit VLC on MacPipe exit")
        return
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", "tell application \"VLC\" to quit"]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            print("Quit VLC on MacPipe exit")
        } else {
            print("Could not quit VLC automatically")
        }
    } catch {
        print("Could not quit VLC automatically: \(error.localizedDescription)")
    }
}

func launchVLCAndExitWhenDone(playlistURL: URL) throws {
    let vlcPath = "/Applications/VLC.app/Contents/MacOS/VLC"
    guard FileManager.default.fileExists(atPath: vlcPath) else {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "VLC", playlistURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CliError.invalidArguments("Failed to open VLC with playlist")
        }
        return
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: vlcPath)
    process.arguments = ["--play-and-exit", playlistURL.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
}

func sanitizePlaylistTitle(_ title: String) -> String {
    title
        .replacingOccurrences(of: "\r", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: ",", with: " -")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func writePlaylist(title: String, streamURL: String) throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("macpipe", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let filename = "now-playing-\(UUID().uuidString).xspf"
    let playlistURL = dir.appendingPathComponent(filename)
    let contents = """
    <?xml version="1.0" encoding="UTF-8"?>
    <playlist version="1" xmlns="http://xspf.org/ns/0/">
      <title>\(xmlEscape(title))</title>
      <trackList>
        <track>
          <location>\(xmlEscape(streamURL))</location>
          <title>\(xmlEscape(title))</title>
        </track>
      </trackList>
    </playlist>
    """
    try contents.write(to: playlistURL, atomically: true, encoding: .utf8)
    return playlistURL
}

func xmlEscape(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}

func runTests() async {
    var passed = 0
    var failed = 0

    func check(_ name: String, _ condition: Bool) {
        if condition {
            print("  ✅ \(name)")
            passed += 1
        } else {
            print("  ❌ \(name)")
            failed += 1
        }
    }

    print("Test Scenario 1: Search 'lofi'")
    let client = YtDlpClient()
    do {
        let results = try await client.search(query: "lofi", maxResults: 5)
        check("Returns results", !results.isEmpty)
        check("Returns correct count", results.count <= 5)
        check("Results have IDs", results.allSatisfy { !$0.id.isEmpty })
        check("Results have titles", results.allSatisfy { !$0.title.isEmpty })
        check("Duration formatting works", !results[0].durationFormatted.isEmpty)
        if !results.isEmpty {
            print("    First result: \(results[0].title) (\(results[0].id))")
        }
    } catch {
        print("  ❌ Search threw: \(error)")
        failed += 5
    }

    print()

    print("Test Scenario 2: Extract stream info")
    do {
        let results = try await client.search(query: "lofi", maxResults: 1)
        guard let first = results.first else {
            print("  ❌ No results to extract from")
            failed += 5
            return
        }
        let info = try await client.extractInfo(videoId: first.id)
        check("Has title", !info.title.isEmpty)
        check("Has formats", !info.formats.isEmpty)
        check("Has playable URL", info.playableUrl != nil)
        check("Has audio-only URL", info.audioUrl != nil)
        print("    Title: \(info.title)")
        print("    Formats: \(info.formats.count)")
    } catch {
        print("  ❌ Extract threw: \(error)")
        failed += 4
    }

    print()
    print("========================================")
    print("Results: \(passed) passed, \(failed) failed")
    print("========================================")
    if failed > 0 { exit(1) }
}

func printUsage() {
    print("""
    Usage:
      macpipe <query>                     Search, list results, ask which number to play
      macpipe find <query>                Search YouTube (friendly alias for search)
      macpipe search <query>              Search YouTube (multi-word queries supported)
      macpipe search <query> --limit N    Limit search results
      macpipe search <query> --json       Output results as JSON
      macpipe search <query> --quality off|normal|strict
      macpipe search <query> --mode general|education|entertainment
      macpipe search <query> --allow-shorts
      macpipe search <query> --quality-debug
      macpipe search <query> --play N     Search and play result N (1-indexed)
      macpipe play <video_id>             Print stream URL for a specific video
      macpipe play <id> --audio-only      Print audio-only stream URL
      macpipe listen <query>              Play first result as audio in this terminal
      macpipe watch <query>               Open first result video stream in VLC-compatible quality
      macpipe open <query>                Open first result video stream in VLC
      macpipe open-id <video_id_or_url>   Open exact video in VLC with title metadata
      macpipe tty                         Open interactive terminal media UI
      macpipe tty --dry-run               Interactive TUI without launching VLC
      macpipe tty --scripted --dry-run    Test TUI by reading key bytes from stdin
      macpipe tty --scripted --mock       Deterministic scripted TUI with fixture results
      macpipe tty --snapshot              Print deterministic result-list TUI snapshot
      macpipe tty --snapshot --home       Print deterministic launcher snapshot
      macpipe tty --snapshot --post-playback Print deterministic post-playback loop snapshot
      macpipe tty --snapshot --home --color Print launcher snapshot with semantic ANSI colors
      macpipe tty --width N --height N     Override terminal frame size for TUI/snapshots
      macpipe test                        Run end-to-end test suite
      macpipe help                        Show this help

    Examples:
      macpipe "qwen 3.7"
      macpipe search lofi hiphop --limit 5
      macpipe search "swift tutorial" --play 1
      macpipe play dQw4w9WgXcQ --audio-only
    """)
}
