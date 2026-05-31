import Foundation

public enum TUIScreen: Sendable, Equatable {
    case home
    case searching
    case results
    case opening
    case postPlayback
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
