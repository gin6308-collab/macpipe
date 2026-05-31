import XCTest
@testable import MacPipeCore

final class SearchQualityTests: XCTestCase {
    func testNormalQualityHidesDurationBasedShortsByDefault() {
        let results = [
            result(id: "short", title: "Qwen 3.7 in 30 seconds", duration: 30),
            result(id: "long", title: "Qwen 3.7 full demo", duration: 600)
        ]

        let evaluated = SearchQualityScorer().filter(results, query: "qwen 3.7", policy: .normal(displayLimit: 5))

        XCTAssertEqual(evaluated.accepted.map(\.id), ["long"])
        XCTAssertTrue(evaluated.hidden.contains { $0.result.id == "short" && $0.rejectionReason?.contains("Shorts") == true })
    }

    func testNormalQualityHidesTitleMarkedShortsByDefault() {
        let results = [
            result(id: "short", title: "Qwen 3.7 demo #shorts", duration: 90),
            result(id: "main", title: "Qwen 3.7 benchmark walkthrough", duration: 700)
        ]

        let evaluated = SearchQualityScorer().filter(results, query: "qwen 3.7", policy: .normal(displayLimit: 5))

        XCTAssertEqual(evaluated.accepted.map(\.id), ["main"])
        XCTAssertTrue(evaluated.hidden.contains { $0.result.id == "short" })
    }

    func testAllowShortsPermitsShorts() {
        let results = [result(id: "short", title: "Qwen 3.7 in 30 seconds #shorts", duration: 30)]

        let evaluated = SearchQualityScorer().filter(results, query: "qwen 3.7", policy: SearchQualityPolicy(mode: .normal, allowShorts: true, displayLimit: 5))

        XCTAssertEqual(evaluated.accepted.map(\.id), ["short"])
    }

    func testRejectsUnknownTitle() {
        let results = [
            result(id: "bad", title: "Unknown", duration: 500),
            result(id: "good", title: "Qwen 3.7 explained", duration: 500)
        ]

        let evaluated = SearchQualityScorer().filter(results, query: "qwen 3.7", policy: .normal(displayLimit: 5))

        XCTAssertEqual(evaluated.accepted.map(\.id), ["good"])
        XCTAssertTrue(evaluated.hidden.contains { $0.result.id == "bad" && $0.rejectionReason?.contains("title") == true })
    }

    func testClickbaitIsDownrankedButNotAlwaysRejected() {
        let clickbait = result(id: "click", title: "Qwen 3.7 WILL SHOCK YOU!!!", duration: 600, viewCount: 100_000)
        let calm = result(id: "calm", title: "Qwen 3.7 technical overview", duration: 600, viewCount: 1_000)

        let evaluated = SearchQualityScorer().filter([clickbait, calm], query: "qwen 3.7", policy: .normal(displayLimit: 5))

        XCTAssertEqual(evaluated.accepted.first?.id, "calm")
        XCTAssertTrue(evaluated.decisions.first { $0.result.id == "click" }?.reasons.contains { $0.contains("clickbait") } == true)
    }

    func testStrictRejectsWeakQueryMatches() {
        let results = [
            result(id: "weak", title: "Random AI news reaction", duration: 500),
            result(id: "strong", title: "Qwen 3.7 Max benchmark", duration: 500)
        ]

        let evaluated = SearchQualityScorer().filter(results, query: "qwen 3.7", policy: .strict(displayLimit: 5))

        XCTAssertEqual(evaluated.accepted.map(\.id), ["strong"])
        XCTAssertTrue(evaluated.hidden.contains { $0.result.id == "weak" && $0.rejectionReason?.contains("query") == true })
    }

    func testLongFormHintsAvoidLongDurationPenalty() {
        let long = result(id: "course", title: "Swift full course", duration: 18_000)

        let withoutHint = SearchQualityScorer().evaluate(long, query: "swift", policy: .normal(displayLimit: 5), originalIndex: 0)
        let withHint = SearchQualityScorer().evaluate(long, query: "swift full course", policy: .normal(displayLimit: 5), originalIndex: 0)

        XCTAssertLessThan(withoutHint.score, withHint.score)
        XCTAssertFalse(withHint.reasons.contains { $0.contains("very long") })
    }

    func testViewCountMildlyBoostsWhenPresent() {
        let low = result(id: "low", title: "Qwen 3.7 demo", duration: 500, viewCount: 100)
        let high = result(id: "high", title: "Qwen 3.7 walkthrough", duration: 500, viewCount: 100_000)

        let evaluated = SearchQualityScorer().filter([low, high], query: "qwen 3.7", policy: .normal(displayLimit: 5))

        XCTAssertEqual(evaluated.accepted.first?.id, "high")
    }

    func testMissingViewCountDoesNotRejectCandidate() {
        let candidate = result(id: "noviews", title: "Qwen 3.7 explained", duration: 500, viewCount: nil)

        let evaluated = SearchQualityScorer().filter([candidate], query: "qwen 3.7", policy: .normal(displayLimit: 5))

        XCTAssertEqual(evaluated.accepted.map(\.id), ["noviews"])
    }

    func testDeduplicatesRepeatedIDsAndNormalizedTitles() {
        let results = [
            result(id: "same", title: "Qwen 3.7 demo", duration: 500),
            result(id: "same", title: "Qwen 3.7 demo reupload", duration: 500),
            result(id: "other", title: "QWEN 3.7 DEMO!!!", duration: 500),
            result(id: "unique", title: "Qwen 3.7 benchmark", duration: 500)
        ]

        let evaluated = SearchQualityScorer().filter(results, query: "qwen 3.7", policy: .normal(displayLimit: 10))

        XCTAssertEqual(Set(evaluated.accepted.map(\.id)), Set(["same", "unique"]))
    }

    func testOriginalRankBreaksTies() {
        let first = result(id: "first", title: "Qwen 3.7 demo", duration: 500)
        let second = result(id: "second", title: "Qwen 3.7 demo walkthrough", duration: 500)

        let evaluated = SearchQualityScorer().filter([first, second], query: "qwen 3.7", policy: .normal(displayLimit: 5))

        XCTAssertEqual(evaluated.accepted.first?.id, "first")
    }

    func testEducationModePrefersInstructionalResultsOverClickbaitEntertainment() {
        let reaction = result(id: "reaction", title: "Qwen 3.7 INSANE reaction!!!", uploader: "AI Reactions", duration: 520, viewCount: 500_000)
        let lesson = result(id: "lesson", title: "Qwen 3.7 explained tutorial for developers", uploader: "DeepLearning University", duration: 900, viewCount: 20_000)

        let evaluated = SearchQualityScorer().filter(
            [reaction, lesson],
            query: "qwen 3.7",
            policy: SearchQualityPolicy(mode: .normal, contentMode: .education, displayLimit: 5)
        )

        XCTAssertEqual(evaluated.accepted.first?.id, "lesson")
        XCTAssertTrue(evaluated.decisions.first { $0.result.id == "lesson" }?.reasons.contains { $0.contains("education") } == true)
    }

    func testEntertainmentModePrefersEntertainmentResultsOverInstructionalResults() {
        let lesson = result(id: "lesson", title: "Mario speedrun tutorial explained", uploader: "Game School", duration: 720, viewCount: 100_000)
        let funny = result(id: "funny", title: "Mario speedrun funny moments compilation", uploader: "Party Arcade", duration: 620, viewCount: 80_000)

        let evaluated = SearchQualityScorer().filter(
            [lesson, funny],
            query: "mario speedrun",
            policy: SearchQualityPolicy(mode: .normal, contentMode: .entertainment, displayLimit: 5)
        )

        XCTAssertEqual(evaluated.accepted.first?.id, "funny")
        XCTAssertTrue(evaluated.decisions.first { $0.result.id == "funny" }?.reasons.contains { $0.contains("entertainment") } == true)
    }

    private func result(id: String, title: String, uploader: String = "Channel", duration: Int, thumbnail: String? = "https://example.com/thumb.jpg", viewCount: Int? = nil) -> SearchResult {
        SearchResult(id: id, title: title, uploader: uploader, duration: duration, thumbnail: thumbnail, viewCount: viewCount)
    }
}
