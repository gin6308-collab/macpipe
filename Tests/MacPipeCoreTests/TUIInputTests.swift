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

    func testHomeParserTreatsShortcutLettersAsQueryText() {
        let parser = TUIInputParser()
        let state = TUIState(screen: .home, query: "")

        XCTAssertEqual(parser.parse(bytes: Array("q".utf8), state: state), .character("q"))
        XCTAssertEqual(parser.parse(bytes: Array("a".utf8), state: state), .character("a"))
        XCTAssertEqual(parser.parse(bytes: Array("x".utf8), state: state), .character("x"))
    }

    func testParsesEnterEscapeBackspace() {
        let parser = TUIInputParser()
        XCTAssertEqual(parser.parse(bytes: [10]), .submit)
        XCTAssertEqual(parser.parse(bytes: [3]), .quit)
        XCTAssertEqual(parser.parse(bytes: [4]), .quit)
        XCTAssertEqual(parser.parse(bytes: [27]), .escape)
        XCTAssertEqual(parser.parse(bytes: [127]), .backspace)
    }
}
