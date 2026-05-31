import Foundation

public enum TUIEffect: Sendable, Equatable {
    case none
    case search(query: String)
    case play(resultID: String)
    case quit
}

public struct TUITransition: Sendable, Equatable {
    public var state: TUIState
    public var effect: TUIEffect

    public init(state: TUIState, effect: TUIEffect = .none) {
        self.state = state
        self.effect = effect
    }
}

public struct TUIReducer: Sendable {
    public init() {}

    public func reduce(state: TUIState, action: TUIAction) -> TUITransition {
        var next = state

        switch action {
        case .moveUp:
            next.selectedIndex = max(0, state.selectedIndex - 1)
            return TUITransition(state: next)

        case .moveDown:
            let lastIndex = max(0, state.results.count - 1)
            next.selectedIndex = min(lastIndex, state.selectedIndex + 1)
            return TUITransition(state: next)

        case .backspace:
            if state.screen == .home && !next.query.isEmpty {
                next.query.removeLast()
            }
            return TUITransition(state: next)

        case .search:
            next.screen = .home
            next.query = ""
            next.status = "READY FOR SEARCH"
            next.selectedIndex = 0
            return TUITransition(state: next)

        case .submit:
            return submit(state: state)

        case .character(let character):
            return characterInput(character, state: state)

        case .quit:
            return TUITransition(state: state, effect: .quit)

        case .escape:
            next.screen = .home
            next.query = ""
            next.status = "READY FOR SEARCH"
            return TUITransition(state: next)

        case .audio, .open, .description, .related, .help, .unknown:
            return TUITransition(state: next)
        }
    }

    public func receiveResults(state: TUIState, results: [SearchResult]) -> TUIState {
        var next = state
        next.screen = .results
        next.results = results
        next.selectedIndex = 0
        next.status = results.isEmpty ? "NO RESULTS" : "\(results.count) RESULTS"
        return next
    }

    public func markPlaybackSent(state: TUIState) -> TUIState {
        var next = state
        next.screen = .postPlayback
        next.status = "PLAYBACK SENT TO VLC"
        return next
    }

    private func submit(state: TUIState) -> TUITransition {
        switch state.screen {
        case .home:
            let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return TUITransition(state: state) }
            var next = state
            next.query = query
            next.screen = .searching
            next.status = "SEARCHING YouTube"
            return TUITransition(state: next, effect: .search(query: query))
        case .results, .postPlayback:
            return playSelected(state: state)
        case .searching, .opening, .details, .help:
            return TUITransition(state: state)
        }
    }

    private func characterInput(_ character: Character, state: TUIState) -> TUITransition {
        switch state.screen {
        case .home:
            var next = state
            next.query.append(character)
            next.status = "READY FOR SEARCH"
            return TUITransition(state: next)
        case .postPlayback:
            let lower = String(character).lowercased()
            if lower == "s" {
                var next = state
                next.screen = .home
                next.query = ""
                next.selectedIndex = 0
                next.status = "READY FOR SEARCH"
                return TUITransition(state: next)
            }
            if lower == "x" || lower == "q" {
                return TUITransition(state: state, effect: .quit)
            }
            if let number = Int(String(character)), number > 0, state.results.indices.contains(number - 1) {
                var next = state
                next.selectedIndex = number - 1
                return playSelected(state: next)
            }
            return TUITransition(state: state)
        case .results:
            if let number = Int(String(character)), number > 0, state.results.indices.contains(number - 1) {
                var next = state
                next.selectedIndex = number - 1
                return playSelected(state: next)
            }
            return TUITransition(state: state)
        case .searching, .opening, .details, .help:
            return TUITransition(state: state)
        }
    }

    private func playSelected(state: TUIState) -> TUITransition {
        guard let selected = state.selectedResult else { return TUITransition(state: state) }
        var next = state
        next.screen = .opening
        next.status = "OPENING \(selected.title)"
        return TUITransition(state: next, effect: .play(resultID: selected.id))
    }
}
