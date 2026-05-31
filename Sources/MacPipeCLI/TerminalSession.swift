import Foundation
import Darwin

struct TerminalSession {
    private let out = FileHandle.standardOutput

    func enterAlternateScreen() {
        write("\u{001B}[?1049h\u{001B}[?25l")
    }

    func leaveAlternateScreen() {
        write("\u{001B}[?25h\u{001B}[?1049l")
    }

    func clear() {
        write("\u{001B}[2J\u{001B}[H")
    }

    func draw(_ frame: String) {
        clear()
        write(frame)
        write("\u{001B}[0m")
    }

    func currentSize(defaultWidth: Int = 96, defaultHeight: Int = 24) -> (width: Int, height: Int) {
        var size = winsize()
        guard ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 else {
            return (defaultWidth, defaultHeight)
        }
        let width = Int(size.ws_col)
        let height = Int(size.ws_row)
        guard width > 0, height > 0 else {
            return (defaultWidth, defaultHeight)
        }
        return (width, height)
    }

    func write(_ text: String) {
        if let data = text.data(using: .utf8) {
            out.write(data)
        }
    }

    static func enableRawMode() throws -> termios {
        var original = termios()
        guard tcgetattr(STDIN_FILENO, &original) == 0 else {
            throw CliError.invalidArguments("Could not read terminal mode")
        }

        var raw = original
        raw.c_lflag &= ~UInt(ECHO | ICANON | ISIG | IEXTEN)
        raw.c_iflag &= ~UInt(IXON | ICRNL | BRKINT | INPCK | ISTRIP)
        raw.c_oflag &= ~UInt(OPOST)
        raw.c_cflag |= UInt(CS8)
        raw.c_cc.16 = 0 // VMIN: allow timed reads for lone Esc vs arrow sequences
        raw.c_cc.17 = 1 // VTIME: 0.1s timeout

        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == 0 else {
            throw CliError.invalidArguments("Could not enter raw terminal mode")
        }
        return original
    }

    static func restoreMode(_ mode: termios) {
        var restored = mode
        _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &restored)
    }
}
