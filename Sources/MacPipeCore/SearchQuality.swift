import Foundation

public enum SearchQualityMode: String, Codable, Sendable, Equatable {
    case off
    case normal
    case strict
}

public enum SearchContentMode: String, Codable, Sendable, Equatable {
    case general
    case education
    case entertainment
}

public struct SearchQualityPolicy: Codable, Sendable, Equatable {
    public var mode: SearchQualityMode
    public var contentMode: SearchContentMode
    public var allowShorts: Bool
    public var displayLimit: Int

    public init(mode: SearchQualityMode, contentMode: SearchContentMode = .general, allowShorts: Bool = false, displayLimit: Int) {
        self.mode = mode
        self.contentMode = contentMode
        self.allowShorts = allowShorts
        self.displayLimit = displayLimit
    }

    public static func normal(displayLimit: Int) -> SearchQualityPolicy {
        SearchQualityPolicy(mode: .normal, displayLimit: displayLimit)
    }

    public static func strict(displayLimit: Int) -> SearchQualityPolicy {
        SearchQualityPolicy(mode: .strict, displayLimit: displayLimit)
    }

    public static func off(displayLimit: Int) -> SearchQualityPolicy {
        SearchQualityPolicy(mode: .off, allowShorts: true, displayLimit: displayLimit)
    }

    public var fetchLimit: Int {
        mode == .off ? displayLimit : max(displayLimit * 4, 20)
    }
}

public struct QualityDecision: Sendable, Equatable {
    public let result: SearchResult
    public let accepted: Bool
    public let score: Int
    public let reasons: [String]
    public let rejectionReason: String?
    public let originalIndex: Int
}

public struct SearchQualityEvaluation: Sendable, Equatable {
    public let decisions: [QualityDecision]

    public var acceptedDecisions: [QualityDecision] { decisions.filter(\.accepted) }
    public var hidden: [QualityDecision] { decisions.filter { !$0.accepted } }
    public var accepted: [SearchResult] { acceptedDecisions.map(\.result) }
}

public struct SearchQualityScorer: Sendable {
    public init() {}

    public func filter(_ results: [SearchResult], query: String, policy: SearchQualityPolicy) -> SearchQualityEvaluation {
        if policy.mode == .off {
            let limited = Array(results.prefix(policy.displayLimit))
            return SearchQualityEvaluation(decisions: limited.enumerated().map { index, result in
                QualityDecision(result: result, accepted: true, score: 0, reasons: ["quality off"], rejectionReason: nil, originalIndex: index)
            })
        }

        var seenIDs = Set<String>()
        var seenTitles = Set<String>()
        var decisions: [QualityDecision] = []

        for (index, result) in results.enumerated() {
            var decision = evaluate(result, query: query, policy: policy, originalIndex: index)
            let normalizedTitle = normalize(result.title)
            if decision.accepted {
                if seenIDs.contains(result.id) {
                    decision = rejected(result: result, score: decision.score, reasons: decision.reasons, reason: "duplicate video ID", originalIndex: index)
                } else if seenTitles.contains(normalizedTitle) {
                    decision = rejected(result: result, score: decision.score, reasons: decision.reasons, reason: "duplicate title", originalIndex: index)
                } else {
                    seenIDs.insert(result.id)
                    seenTitles.insert(normalizedTitle)
                }
            }
            decisions.append(decision)
        }

        let accepted = decisions
            .filter(\.accepted)
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.originalIndex < rhs.originalIndex
            }
            .prefix(policy.displayLimit)

        let acceptedKeys = Set(accepted.map { $0.result.id + "@\($0.originalIndex)" })
        let hiddenDecisions = decisions.compactMap { decision -> QualityDecision? in
            guard decision.accepted else { return decision }
            let key = decision.result.id + "@\(decision.originalIndex)"
            if acceptedKeys.contains(key) { return nil }
            return QualityDecision(
                result: decision.result,
                accepted: false,
                score: decision.score,
                reasons: decision.reasons,
                rejectionReason: "below quality cutoff",
                originalIndex: decision.originalIndex
            )
        }
        return SearchQualityEvaluation(decisions: Array(accepted) + hiddenDecisions)
    }

    public func evaluate(_ result: SearchResult, query: String, policy: SearchQualityPolicy, originalIndex: Int) -> QualityDecision {
        if result.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rejected(result: result, score: 0, reasons: [], reason: "missing video ID", originalIndex: originalIndex)
        }

        let title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty || normalize(title) == "unknown" {
            return rejected(result: result, score: 0, reasons: [], reason: "missing or unknown title", originalIndex: originalIndex)
        }

        var score = max(0, 30 - originalIndex * 2)
        var reasons: [String] = ["youtube rank \(originalIndex + 1)"]
        let queryTerms = significantTerms(query)
        let titleTerms = Set(significantTerms(title))
        let uploaderTerms = Set(significantTerms(result.uploader))
        let matchedTitleTerms = queryTerms.filter { titleTerms.contains($0) }
        let matchedUploaderTerms = queryTerms.filter { uploaderTerms.contains($0) }

        let shorts = isShorts(result)
        if shorts && !policy.allowShorts {
            return rejected(result: result, score: score, reasons: reasons + ["shorts signal"], reason: "Shorts hidden by quality policy", originalIndex: originalIndex)
        }

        if isMostlySymbols(title) {
            return rejected(result: result, score: score, reasons: reasons, reason: "spammy title", originalIndex: originalIndex)
        }

        if !queryTerms.isEmpty {
            if matchedTitleTerms.count == queryTerms.count {
                score += 35
                reasons.append("full title match")
            } else if matchedTitleTerms.count > 0 {
                score += 12 + matchedTitleTerms.count * 4
                reasons.append("partial title match")
            } else if policy.mode == .strict {
                return rejected(result: result, score: score, reasons: reasons, reason: "weak query match", originalIndex: originalIndex)
            } else {
                score -= 12
                reasons.append("weak query match")
            }

            if !matchedUploaderTerms.isEmpty {
                score += 8
                reasons.append("uploader match")
            }
        }

        if result.duration > 0 {
            switch result.duration {
            case 61...(2 * 60 * 60):
                score += 12
                reasons.append("normal duration")
            case (2 * 60 * 60 + 1)...:
                if hasLongFormHint(query) {
                    score += 6
                    reasons.append("long-form query")
                } else {
                    score -= policy.mode == .strict ? 18 : 10
                    reasons.append("very long duration")
                }
            default:
                break
            }
        } else {
            score -= policy.mode == .strict ? 10 : 4
            reasons.append("unknown duration")
        }

        if result.thumbnail != nil {
            score += 4
            reasons.append("has thumbnail")
        }

        if result.uploader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score -= policy.mode == .strict ? 10 : 4
            reasons.append("missing uploader")
        }

        if let viewCount = result.viewCount {
            switch viewCount {
            case 100_000...:
                score += 8
                reasons.append("high views")
            case 10_000...:
                score += 5
                reasons.append("solid views")
            case 1_000...:
                score += 2
                reasons.append("some views")
            default:
                break
            }
        }

        let clickbaitPenalty = clickbaitPenalty(title)
        if clickbaitPenalty > 0 {
            score -= clickbaitPenalty
            reasons.append("clickbait penalty")
        }

        let contentAdjustment = scoreContentMode(result: result, query: query, policy: policy)
        if contentAdjustment.score != 0 {
            score += contentAdjustment.score
            reasons.append(contentsOf: contentAdjustment.reasons)
        }

        return QualityDecision(result: result, accepted: true, score: score, reasons: reasons, rejectionReason: nil, originalIndex: originalIndex)
    }

    private func scoreContentMode(result: SearchResult, query: String, policy: SearchQualityPolicy) -> (score: Int, reasons: [String]) {
        switch policy.contentMode {
        case .general:
            return (0, [])
        case .education:
            return scoreEducationMode(result: result, query: query)
        case .entertainment:
            return scoreEntertainmentMode(result: result, query: query)
        }
    }

    private func scoreEducationMode(result: SearchResult, query: String) -> (score: Int, reasons: [String]) {
        let text = normalize("\(result.title) \(result.uploader)")
        let educationalTerms = [
            "explain", "explained", "explainer", "tutorial", "lesson", "lecture", "course", "class", "learn", "learning",
            "guide", "walkthrough", "deep dive", "workshop", "seminar", "university", "college", "school", "academy",
            "khan", "mit", "stanford", "harvard", "freecodecamp", "crash course", "developer", "developers", "engineering"
        ]
        let entertainmentTerms = ["reaction", "reacts", "funny", "moments", "compilation", "prank", "meme", "memes", "trailer", "official music video", "music video"]
        var score = 0
        var reasons: [String] = []
        if educationalTerms.contains(where: { text.contains($0) }) {
            score += 24
            reasons.append("education mode boost")
        }
        if entertainmentTerms.contains(where: { text.contains($0) }) {
            score -= 14
            reasons.append("education mode entertainment penalty")
        }
        if hasLongFormHint(query) || hasLongFormHint(result.title) {
            score += 6
            reasons.append("education long-form signal")
        }
        return (score, reasons)
    }

    private func scoreEntertainmentMode(result: SearchResult, query: String) -> (score: Int, reasons: [String]) {
        let text = normalize("\(result.title) \(result.uploader)")
        let entertainmentTerms = [
            "official", "music video", "trailer", "teaser", "reaction", "reacts", "funny", "moments", "compilation", "highlights",
            "live", "performance", "concert", "comedy", "sketch", "meme", "memes", "gaming", "gameplay", "speedrun", "challenge"
        ]
        let educationalTerms = ["tutorial", "lesson", "lecture", "course", "class", "explained", "explainer", "guide", "university", "academy", "workshop"]
        var score = 0
        var reasons: [String] = []
        if entertainmentTerms.contains(where: { text.contains($0) }) {
            score += 22
            reasons.append("entertainment mode boost")
        }
        if educationalTerms.contains(where: { text.contains($0) }) {
            score -= 10
            reasons.append("entertainment mode education penalty")
        }
        if result.duration > 0 && result.duration <= 20 * 60 {
            score += 4
            reasons.append("entertainment duration signal")
        }
        return (score, reasons)
    }

    private func rejected(result: SearchResult, score: Int, reasons: [String], reason: String, originalIndex: Int) -> QualityDecision {
        QualityDecision(result: result, accepted: false, score: score, reasons: reasons, rejectionReason: reason, originalIndex: originalIndex)
    }

    private func isShorts(_ result: SearchResult) -> Bool {
        let normalized = normalize(result.title)
        if result.duration > 0 && result.duration < 61 { return true }
        return normalized.contains("#shorts") || normalized.contains("youtube shorts") || normalized.contains("ytshorts")
    }

    private func clickbaitPenalty(_ title: String) -> Int {
        let normalized = normalize(title)
        let phrases = ["watch till end", "gone wrong", "shocking", "wont believe", "won t believe", "will shock you", "no one is talking"]
        var penalty = phrases.contains { normalized.contains($0) } ? 32 : 0
        if title.filter({ $0 == "!" || $0 == "?" }).count >= 3 { penalty += 8 }
        let letters = title.filter(\.isLetter)
        if letters.count >= 8 {
            let uppercase = letters.filter(\.isUppercase).count
            if Double(uppercase) / Double(letters.count) > 0.65 { penalty += 10 }
        }
        return penalty
    }

    private func isMostlySymbols(_ title: String) -> Bool {
        let scalars = Array(title.unicodeScalars)
        guard !scalars.isEmpty else { return true }
        let lettersAndNumbers = scalars.filter { CharacterSet.alphanumerics.contains($0) }.count
        return lettersAndNumbers < 3 || Double(lettersAndNumbers) / Double(scalars.count) < 0.25
    }

    private func hasLongFormHint(_ query: String) -> Bool {
        let normalized = normalize(query)
        let hints = ["lecture", "podcast", "interview", "radio", "ambient", "mix", "full course", "course", "tutorial", "livestream", "stream"]
        return hints.contains { normalized.contains($0) }
    }

    private func significantTerms(_ text: String) -> [String] {
        normalize(text)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 2 && !stopWords.contains($0) }
    }

    private func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let allowed = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "#" { return Character(scalar) }
            return " "
        }
        return String(allowed).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var stopWords: Set<String> {
        ["the", "and", "for", "with", "this", "that", "from", "into", "over", "why", "how", "what", "are", "you", "your", "new"]
    }
}
