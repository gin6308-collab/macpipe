import Foundation

/// Simple file logger for debugging
public enum DebugLog {
    private static let logFileURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("macpipe_debug.log")
    }()

    public static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let handle = try? FileHandle(forWritingTo: logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
        if ProcessInfo.processInfo.environment["MACPIPE_DEBUG_STDOUT"] == "1" {
            FileHandle.standardError.write(Data(line.utf8))
        }
    }
}
