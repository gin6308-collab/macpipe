import XCTest
@testable import MacPipeCore

final class TUIReducerTests: XCTestCase {
    func testHomeCharactersBuildSearchQueryAndSubmitStartsSearch() {
        var state = TUIState(screen: .home, status: "READY")
        let reducer = TUIReducer()

        var transition = reducer.reduce(state: state, action: .character("q"))
        state = transition.state
        transition = reducer.reduce(state: state, action: .character("w"))
        state = transition.state
        transition = reducer.reduce(state: state, action: .submit)

        XCTAssertEqual(transition.state.query, "qw")
        XCTAssertEqual(transition.state.screen, .searching)
        XCTAssertEqual(transition.state.status, "SEARCHING YouTube")
        XCTAssertEqual(transition.effect, .search(query: "qw"))
    }

    func testResultsNavigationClampsAndSubmitRequestsSelectedPlayback() {
        let results = [
            SearchResult(id: "one", title: "One", uploader: "A", duration: 60, thumbnail: nil),
            SearchResult(id: "two", title: "Two", uploader: "B", duration: 120, thumbnail: nil)
        ]
        let reducer = TUIReducer()
        var state = TUIState(screen: .results, query: "demo", results: results, selectedIndex: 0, status: "2 RESULTS")

        state = reducer.reduce(state: state, action: .moveDown).state
        state = reducer.reduce(state: state, action: .moveDown).state
        let transition = reducer.reduce(state: state, action: .submit)

        XCTAssertEqual(transition.state.selectedIndex, 1)
        XCTAssertEqual(transition.state.screen, .opening)
        XCTAssertEqual(transition.state.status, "OPENING Two")
        XCTAssertEqual(transition.effect, .play(resultID: "two"))
    }

    func testPostPlaybackLoopCanPlayNumberSearchAgainOrQuit() {
        let results = [
            SearchResult(id: "one", title: "One", uploader: "A", duration: 60, thumbnail: nil),
            SearchResult(id: "two", title: "Two", uploader: "B", duration: 120, thumbnail: nil)
        ]
        let reducer = TUIReducer()
        let state = TUIState(screen: .postPlayback, query: "demo", results: results, selectedIndex: 0, status: "PLAYBACK SENT TO VLC")

        let replay = reducer.reduce(state: state, action: .character("2"))
        let searchAgain = reducer.reduce(state: state, action: .character("s"))
        let quit = reducer.reduce(state: state, action: .character("x"))

        XCTAssertEqual(replay.state.selectedIndex, 1)
        XCTAssertEqual(replay.state.screen, .opening)
        XCTAssertEqual(replay.effect, .play(resultID: "two"))

        XCTAssertEqual(searchAgain.state.screen, .home)
        XCTAssertEqual(searchAgain.state.query, "")
        XCTAssertEqual(searchAgain.state.status, "READY FOR SEARCH")
        XCTAssertEqual(searchAgain.effect, .none)

        XCTAssertEqual(quit.effect, .quit)
    }

    func testEscapeClearsHomeQuery() {
        let reducer = TUIReducer()
        let state = TUIState(screen: .home, query: "qwen", status: "READY FOR SEARCH")

        let transition = reducer.reduce(state: state, action: .escape)

        XCTAssertEqual(transition.state.screen, .home)
        XCTAssertEqual(transition.state.query, "")
        XCTAssertEqual(transition.state.status, "READY FOR SEARCH")
    }

    func testOutOfRangeNumberDoesNotClampToLastResult() {
        let results = [
            SearchResult(id: "one", title: "One", uploader: "A", duration: 60, thumbnail: nil),
            SearchResult(id: "two", title: "Two", uploader: "B", duration: 120, thumbnail: nil)
        ]
        let reducer = TUIReducer()
        let state = TUIState(screen: .postPlayback, query: "demo", results: results, selectedIndex: 0, status: "PLAYBACK SENT TO VLC")

        let transition = reducer.reduce(state: state, action: .character("9"))

        XCTAssertEqual(transition.state.selectedIndex, 0)
        XCTAssertEqual(transition.state.screen, .postPlayback)
        XCTAssertEqual(transition.effect, .none)
    }
}
