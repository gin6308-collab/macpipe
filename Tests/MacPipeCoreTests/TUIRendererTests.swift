import XCTest
@testable import MacPipeCore

final class TUIRendererTests: XCTestCase {
    func testHomeRendererShowsTerminalMediaLauncherWithoutANSIByDefault() {
        let state = TUIState(
            screen: .home,
            query: "",
            results: [],
            selectedIndex: 0,
            status: "VIDEO · VLC READY · yt-dlp READY"
        )

        let frame = TUIRenderer().render(state: state, width: 96, height: 24)

        XCTAssertTrue(frame.contains("MACPIPE"))
        XCTAssertTrue(frame.contains("Search YouTube"))
        XCTAssertTrue(frame.contains("SOURCE YouTube"))
        XCTAssertTrue(frame.contains("PLAYER VLC"))
        XCTAssertTrue(frame.contains("VIDEO · VLC READY · yt-dlp READY"))
        XCTAssertTrue(frame.contains("▌"))
        XCTAssertTrue(frame.contains("enter search"))
        XCTAssertTrue(frame.contains("paste query"))
        XCTAssertFalse(frame.contains("\u{001B}"))
        XCTAssertFalse(frame.contains("MACPIPE TERMINAL VIDEO SYSTEM"))
    }


    func testHomeRendererUsesCompactLayoutAtSixtyColumns() {
        let state = TUIState(screen: .home, status: "VIDEO · VLC READY · yt-dlp READY")

        let frame = TUIRenderer().render(state: state, width: 60, height: 12)
        let lines = frame.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.count, 12)
        XCTAssertTrue(lines.allSatisfy { $0.count <= 60 })
        XCTAssertTrue(frame.contains("MACPIPE"))
        XCTAssertFalse(frame.contains("███"))
        XCTAssertFalse(frame.contains("████"))
        XCTAssertTrue(frame.contains("yt-dlp READY"))
        XCTAssertTrue(frame.contains("ctrl-c exit"))
    }

    func testResultsRendererAdaptsBelowSixtyColumns() {
        let state = TUIState(
            screen: .results,
            query: "compact terminal search",
            results: [
                SearchResult(id: "abc", title: "A Very Long Educational Video Title That Must Clip", uploader: "Long Channel Name", duration: 3661, thumbnail: nil),
                SearchResult(id: "def", title: "Second Result", uploader: "Focus", duration: 120, thumbnail: nil)
            ],
            selectedIndex: 0,
            status: "2 RESULTS"
        )

        let frame = TUIRenderer().render(state: state, width: 48, height: 10)
        let lines = frame.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.count, 10)
        XCTAssertTrue(lines.allSatisfy { $0.count <= 48 })
        XCTAssertTrue(frame.contains(">01"))
        XCTAssertTrue(lines.last?.hasPrefix("╚") == true)
    }

    func testRendererCanApplySemanticAnsiColors() {
        let state = TUIState(
            screen: .home,
            query: "qwen 3.7",
            results: [],
            selectedIndex: 0,
            status: "VIDEO · VLC READY · yt-dlp READY"
        )

        let frame = TUIRenderer().render(state: state, width: 96, height: 24, colorMode: .always)

        XCTAssertTrue(frame.contains("\u{001B}["))
        XCTAssertTrue(frame.contains("MACPIPE"))
        XCTAssertTrue(frame.contains("Search YouTube"))
        XCTAssertTrue(frame.contains("\u{001B}[0m"))
    }

    func testHomeRendererKeepsShortcutStripAtBottom() {
        let state = TUIState(screen: .home, status: "VIDEO · VLC READY · yt-dlp READY")

        let frame = TUIRenderer().render(state: state, width: 96, height: 24)
        let lines = frame.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.count, 24)
        XCTAssertTrue(frame.contains("ctrl-c exit"))
    }

    func testHomeRendererClipsLongQueryAndStatusToWidth() {
        let state = TUIState(
            screen: .home,
            query: String(repeating: "very long query ", count: 20),
            results: [],
            selectedIndex: 0,
            status: String(repeating: "READY ", count: 30)
        )

        let frame = TUIRenderer().render(state: state, width: 80, height: 24)
        let lines = frame.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.count, 24)
        XCTAssertTrue(lines.allSatisfy { $0.count <= 80 })
    }

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

    func testRendererWindowsResultsAroundSelectedIndex() {
        let results = (1...12).map { index in
            SearchResult(id: "id\(index)", title: "Video \(index)", uploader: "Channel", duration: 60, thumbnail: nil)
        }
        let state = TUIState(screen: .results, query: "demo", results: results, selectedIndex: 11, status: "12 RESULTS")

        let frame = TUIRenderer().render(state: state, width: 80, height: 14)

        XCTAssertTrue(frame.contains(">12  Video 12"))
        XCTAssertFalse(frame.contains("  01  Video 1"))
    }

    func testResultsRendererKeepsBottomBorderWhenWindowingManyResults() {
        let results = (1...20).map { index in
            SearchResult(id: "id\(index)", title: "Video \(index)", uploader: "Channel", duration: 60, thumbnail: nil)
        }
        let state = TUIState(screen: .results, query: "demo", results: results, selectedIndex: 19, status: "20 RESULTS")

        let frame = TUIRenderer().render(state: state, width: 80, height: 14)
        let lines = frame.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.count, 14)
        XCTAssertTrue(lines.last?.hasPrefix("╚") == true)
    }

    func testPostPlaybackRendererShowsLoopShortcuts() {
        let state = TUIState(
            screen: .postPlayback,
            query: "demo",
            results: [SearchResult(id: "one", title: "One", uploader: "A", duration: 60, thumbnail: nil)],
            selectedIndex: 0,
            status: "PLAYBACK SENT TO VLC · number another · S search · X exit"
        )

        let frame = TUIRenderer().render(state: state, width: 80, height: 24)

        XCTAssertTrue(frame.contains("NUMBER PLAY ANOTHER"))
        XCTAssertTrue(frame.contains("S SEARCH AGAIN"))
        XCTAssertTrue(frame.contains("X EXIT"))
    }

    func testRendererStripsTerminalControlCharactersFromContent() {
        let state = TUIState(
            screen: .results,
            query: "lofi\u{001B}[2J",
            results: [
                SearchResult(id: "abc\u{0007}", title: "Bad\u{001B}[31mTitle\nInjected", uploader: "Uploader\rName", duration: 10, thumbnail: nil)
            ],
            selectedIndex: 0,
            status: "READY\u{001B}]0;owned\u{0007}"
        )

        let frame = TUIRenderer().render(state: state, width: 80, height: 24)

        XCTAssertFalse(frame.contains("\u{001B}"))
        XCTAssertFalse(frame.contains("\u{0007}"))
        XCTAssertFalse(frame.contains("\r"))
        XCTAssertFalse(frame.contains("Injected"))
        XCTAssertTrue(frame.contains("Bad Title"))
        XCTAssertTrue(frame.contains("Uploader Name"))
    }

    func testRendererStripsC1TerminalControlCharactersFromContent() {
        let state = TUIState(
            screen: .results,
            query: "q\u{009B}2J",
            results: [
                SearchResult(id: "abc", title: "Title\u{009D}0;owned\u{009C}", uploader: "Uploader", duration: 10, thumbnail: nil)
            ],
            selectedIndex: 0,
            status: "READY\u{009B}31m"
        )

        let frame = TUIRenderer().render(state: state, width: 80, height: 24)

        XCTAssertFalse(frame.unicodeScalars.contains { $0.value >= 0x80 && $0.value <= 0x9F })
        XCTAssertFalse(frame.contains("owned"))
        XCTAssertTrue(frame.contains("Title"))
    }
}
