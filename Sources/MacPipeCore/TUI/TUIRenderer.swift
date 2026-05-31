import Foundation

public enum TUIColorMode: Sendable, Equatable {
    case never
    case always
}

public struct TUIRenderer: Sendable {
    public init() {}

    public func render(state: TUIState, width: Int = 80, height: Int = 24, colorMode: TUIColorMode = .never) -> String {
        if state.screen == .home {
            return renderHome(state: state, width: width, height: height, colorMode: colorMode)
        }

        let safeWidth = max(40, width)
        if safeWidth < 60 || height < 13 {
            return renderCompactResults(state: state, width: safeWidth, height: height)
        }
        var lines: [String] = []

        let cleanStatus = sanitizeInlineText(state.status)
        lines.append("╔" + String(repeating: "═", count: safeWidth - 2) + "╗")
        lines.append(padBox(" MACPIPE TERMINAL VIDEO SYSTEM", status: cleanStatus, width: safeWidth))
        lines.append("╠" + String(repeating: "═", count: safeWidth - 2) + "╣")
        let queryText = state.query.isEmpty ? "<press / to search>" : sanitizeInlineText(state.query)
        lines.append(padBox(" QUERY: \(queryText)", status: "", width: safeWidth))
        lines.append("╠" + String(repeating: "═", count: safeWidth - 2) + "╣")

        let visibleCapacity = max(1, height - 13)
        let startIndex = visibleStartIndex(selectedIndex: state.selectedIndex, resultCount: state.results.count, capacity: visibleCapacity)
        let endIndex = min(state.results.count, startIndex + visibleCapacity)
        let visible = Array(state.results[startIndex..<endIndex].enumerated())
        if visible.isEmpty {
            lines.append(padBox(" No results. Press / to search.", status: "", width: safeWidth))
        } else {
            for (offset, result) in visible {
                let idx = startIndex + offset
                let marker = idx == state.selectedIndex ? ">" : " "
                let number = String(format: "%02d", idx + 1)
                let title = sanitizeInlineText(result.title)
                let uploader = sanitizeInlineText(result.uploader)
                let row = " \(marker)\(number)  \(title) · \(result.durationFormatted) · \(uploader)"
                lines.append(padBox(row, status: "", width: safeWidth))
            }
        }

        lines.append("╠" + String(repeating: "═", count: safeWidth - 2) + "╣")
        if let selected = state.selectedResult {
            let title = sanitizeInlineText(selected.title)
            let uploader = sanitizeInlineText(selected.uploader)
            let id = sanitizeInlineText(selected.id)
            lines.append(padBox(" DETAILS: \(title)", status: "", width: safeWidth))
            lines.append(padBox(" CHANNEL: \(uploader)   ID: \(id)", status: "", width: safeWidth))
        } else {
            lines.append(padBox(" DETAILS: select a result", status: "", width: safeWidth))
        }
        while lines.count < max(0, height - 3) {
            lines.append(padBox("", status: "", width: safeWidth))
        }
        lines.append("╠" + String(repeating: "═", count: safeWidth - 2) + "╣")
        let footer = state.screen == .postPlayback
            ? " NUMBER PLAY ANOTHER  S SEARCH AGAIN  X EXIT"
            : " ↑↓ MOVE  ENTER PLAY  / SEARCH  Q QUIT"
        lines.append(padBox(footer, status: "", width: safeWidth))
        lines.append("╚" + String(repeating: "═", count: safeWidth - 2) + "╝")

        return lines.prefix(height).joined(separator: "\n")
    }

    private func renderHome(state: TUIState, width: Int, height: Int, colorMode: TUIColorMode) -> String {
        let safeWidth = max(40, width)
        if safeWidth < 72 || height < 16 {
            return renderCompactHome(state: state, width: safeWidth, height: height, colorMode: colorMode)
        }
        let wordmark = [
            "███╗   ███╗ █████╗  ██████╗██████╗ ██╗██████╗ ███████╗",
            "████╗ ████║██╔══██╗██╔════╝██╔══██╗██║██╔══██╗██╔════╝",
            "██╔████╔██║███████║██║     ██████╔╝██║██████╔╝█████╗",
            "██║╚██╔╝██║██╔══██║██║     ██╔═══╝ ██║██╔═══╝ ██╔══╝",
            "██║ ╚═╝ ██║██║  ██║╚██████╗██║     ██║██║     ███████╗"
        ]
        let accent = style("▌", .accent, colorMode)
        let placeholder = state.query.isEmpty ? "Search YouTube... \"qwen 3.7\"" : "Search YouTube... \"\(sanitizeInlineText(state.query))\""
        let status = sanitizeInlineText(state.status.isEmpty ? "VIDEO · VLC READY · yt-dlp READY" : state.status)
        let mediaStrip = "SOURCE YouTube    PLAYER VLC    MODE Stream    QUEUE Empty"

        var lines: [String] = []
        lines.append("")
        for line in wordmark {
            lines.append(center(style(line, .title, colorMode), width: safeWidth))
        }
        lines.append("")
        lines.append(center(style("MACPIPE", .metadata, colorMode), width: safeWidth))
        lines.append("")
        lines.append(panelLine(accent: accent, text: style(placeholder, .input, colorMode), width: safeWidth))
        lines.append(panelLine(accent: accent, text: "", width: safeWidth))
        lines.append(panelLine(accent: accent, text: style(mediaStrip, .metadata, colorMode), width: safeWidth))
        lines.append(panelLine(accent: accent, text: style(status, .status, colorMode), width: safeWidth))
        lines.append("")
        while lines.count < max(0, height - 1) {
            lines.append("")
        }
        if lines.count > max(0, height - 1) {
            lines = Array(lines.prefix(max(0, height - 1)))
        }
        let shortcuts = [
            style("enter", .shortcutKey, colorMode) + style(" search", .shortcutLabel, colorMode),
            style("esc", .shortcutKey, colorMode) + style(" clear", .shortcutLabel, colorMode),
            style("paste", .shortcutKey, colorMode) + style(" query", .shortcutLabel, colorMode),
            style("ctrl-c", .shortcutKey, colorMode) + style(" exit", .shortcutLabel, colorMode)
        ].joined(separator: "   ")
        lines.append(center(shortcuts, width: safeWidth))
        return lines.prefix(height).joined(separator: "\n")
    }

    private func renderCompactResults(state: TUIState, width: Int, height: Int) -> String {
        var lines: [String] = []
        lines.append("╔" + String(repeating: "═", count: width - 2) + "╗")
        lines.append(padBox(" MACPIPE", status: sanitizeInlineText(state.status), width: width))
        lines.append("╠" + String(repeating: "═", count: width - 2) + "╣")
        let queryText = state.query.isEmpty ? "<search>" : sanitizeInlineText(state.query)
        lines.append(padBox(" Q: \(queryText)", status: "", width: width))
        lines.append("╠" + String(repeating: "═", count: width - 2) + "╣")

        let footerLineCount = 3
        let resultCapacity = max(1, height - lines.count - footerLineCount)
        let startIndex = visibleStartIndex(selectedIndex: state.selectedIndex, resultCount: state.results.count, capacity: resultCapacity)
        let endIndex = min(state.results.count, startIndex + resultCapacity)
        let visible = Array(state.results[startIndex..<endIndex].enumerated())
        if visible.isEmpty {
            lines.append(padBox(" No results", status: "", width: width))
        } else {
            for (offset, result) in visible {
                let idx = startIndex + offset
                let marker = idx == state.selectedIndex ? ">" : " "
                let number = String(format: "%02d", idx + 1)
                let title = sanitizeInlineText(result.title)
                let row = " \(marker)\(number) \(title)"
                lines.append(padBox(row, status: "", width: width))
            }
        }

        while lines.count < max(0, height - footerLineCount) {
            lines.append(padBox("", status: "", width: width))
        }
        lines.append("╠" + String(repeating: "═", count: width - 2) + "╣")
        let footer = state.screen == .postPlayback ? " 1-9 play  S search  X exit" : " ↑↓ move  enter play  / search  q quit"
        lines.append(padBox(footer, status: "", width: width))
        lines.append("╚" + String(repeating: "═", count: width - 2) + "╝")
        return lines.prefix(height).joined(separator: "\n")
    }

    private func renderCompactHome(state: TUIState, width: Int, height: Int, colorMode: TUIColorMode) -> String {
        let query = state.query.isEmpty ? "qwen 3.7" : sanitizeInlineText(state.query)
        let status = sanitizeInlineText(state.status.isEmpty ? "VIDEO · VLC READY · yt-dlp READY" : state.status)
        var lines = [
            "╔" + String(repeating: "═", count: width - 2) + "╗",
            padBox(" MACPIPE", status: "TUI", width: width),
            "╠" + String(repeating: "═", count: width - 2) + "╣",
            padBox(" Search YouTube: \(query)", status: "", width: width),
            padBox(" Source YouTube · Player VLC", status: "", width: width),
            padBox(" \(status)", status: "", width: width)
        ]
        while lines.count < max(0, height - 3) {
            lines.append(padBox("", status: "", width: width))
        }
        lines.append("╠" + String(repeating: "═", count: width - 2) + "╣")
        lines.append(padBox(" enter search  esc clear  ctrl-c exit", status: "", width: width))
        lines.append("╚" + String(repeating: "═", count: width - 2) + "╝")
        return lines.prefix(height).joined(separator: "\n")
    }

    private func visibleStartIndex(selectedIndex: Int, resultCount: Int, capacity: Int) -> Int {
        guard resultCount > 0 else { return 0 }
        let clampedSelection = min(max(0, selectedIndex), resultCount - 1)
        if clampedSelection < capacity { return 0 }
        return min(clampedSelection - capacity + 1, max(0, resultCount - capacity))
    }

    private enum SemanticStyle {
        case title
        case accent
        case input
        case status
        case shortcutKey
        case shortcutLabel
        case metadata
    }

    private func style(_ text: String, _ semanticStyle: SemanticStyle, _ colorMode: TUIColorMode) -> String {
        guard colorMode == .always else { return text }
        let code: String
        switch semanticStyle {
        case .title: code = "38;2;225;225;225"
        case .accent: code = "38;2;73;145;255"
        case .input: code = "38;2;155;155;160"
        case .status: code = "38;2;102;205;170"
        case .shortcutKey: code = "38;2;235;235;235"
        case .shortcutLabel: code = "38;2;130;130;138"
        case .metadata: code = "38;2;120;170;205"
        }
        return "\u{001B}[\(code)m\(text)\u{001B}[0m"
    }

    private func center(_ text: String, width: Int) -> String {
        let padding = max(0, (width - visibleCount(text)) / 2)
        return String(repeating: " ", count: padding) + text
    }

    private func panelLine(accent: String, text: String, width: Int) -> String {
        let panelWidth = min(max(48, width - 20), width)
        let leftPadding = max(0, (width - panelWidth) / 2)
        let availableWidth = max(0, width - leftPadding)
        let content = "\(accent)  \(text)"
        return String(repeating: " ", count: leftPadding) + clipVisible(content, width: availableWidth)
    }

    private func clipVisible(_ text: String, width: Int) -> String {
        guard width > 0 else { return "" }
        var output = ""
        var visible = 0
        var iterator = text.unicodeScalars.makeIterator()
        while let scalar = iterator.next() {
            if scalar.value == 0x1B {
                var sequence = String(scalar)
                guard let introducer = iterator.next() else {
                    output.append(sequence)
                    continue
                }
                sequence.append(String(introducer))
                if introducer.value == 0x5B { // CSI: ESC [ params final-byte
                    while let next = iterator.next() {
                        sequence.append(String(next))
                        if next.value >= 0x40 && next.value <= 0x7E { break }
                    }
                }
                output.append(sequence)
                continue
            }
            guard visible < width else { break }
            output.append(String(scalar))
            visible += 1
        }
        return output
    }

    private func visibleCount(_ text: String) -> Int {
        var count = 0
        var iterator = text.unicodeScalars.makeIterator()
        while let scalar = iterator.next() {
            if scalar.value == 0x1B {
                guard let introducer = iterator.next() else { continue }
                if introducer.value == 0x5B { // CSI: ESC [ params final-byte
                    while let next = iterator.next() {
                        if next.value >= 0x40 && next.value <= 0x7E { break }
                    }
                }
            } else {
                count += 1
            }
        }
        return count
    }

    private func sanitizeInlineText(_ text: String) -> String {
        var result = ""
        var iterator = text.unicodeScalars.makeIterator()
        while let scalar = iterator.next() {
            switch scalar.value {
            case 0x1B:
                result.append(" ")
                guard let next = iterator.next() else { break }
                if next.value == 0x5B { // CSI
                    while let csi = iterator.next() {
                        if csi.value >= 0x40 && csi.value <= 0x7E { break }
                    }
                } else if next.value == 0x5D { // OSC
                    while let osc = iterator.next() {
                        if osc.value == 0x07 { break }
                    }
                }
            case 0x0A:
                return result.trimmingCharacters(in: .whitespacesAndNewlines)
            case 0x0D, 0x09:
                result.append(" ")
            case 0x00...0x1F, 0x7F:
                continue
            case 0x9B: // 8-bit CSI
                result.append(" ")
                while let csi = iterator.next() {
                    if csi.value >= 0x40 && csi.value <= 0x7E { break }
                }
            case 0x9D: // 8-bit OSC
                result.append(" ")
                while let osc = iterator.next() {
                    if osc.value == 0x07 || osc.value == 0x9C { break }
                }
            case 0x80...0x9F:
                continue
            default:
                result.append(String(scalar))
            }
        }
        return result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
    }

    private func padBox(_ left: String, status: String, width: Int) -> String {
        let contentWidth = width - 2
        let combined: String
        if status.isEmpty {
            combined = left
        } else {
            let gap = max(1, contentWidth - left.count - status.count)
            combined = left + String(repeating: " ", count: gap) + status
        }
        let clipped = String(combined.prefix(contentWidth))
        return "║" + clipped + String(repeating: " ", count: max(0, contentWidth - clipped.count)) + "║"
    }
}
