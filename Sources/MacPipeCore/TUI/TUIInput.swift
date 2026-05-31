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

    public func parse(bytes: [UInt8], state: TUIState) -> TUIAction {
        if state.screen == .home, bytes.count == 1 {
            let scalar = UnicodeScalar(bytes[0])
            if !CharacterSet.controlCharacters.contains(scalar) {
                return .character(Character(scalar))
            }
        }
        return parse(bytes: bytes)
    }

    public func parse(bytes: [UInt8]) -> TUIAction {
        if bytes == [27, 91, 65] { return .moveUp }
        if bytes == [27, 91, 66] { return .moveDown }
        if bytes == [10] || bytes == [13] { return .submit }
        if bytes == [3] || bytes == [4] { return .quit }
        if bytes == [27] { return .escape }
        if bytes == [127] || bytes == [8] { return .backspace }
        guard bytes.count == 1 else { return .unknown }
        let scalar = UnicodeScalar(bytes[0])
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
