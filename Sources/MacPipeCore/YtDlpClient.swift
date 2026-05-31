import Foundation

public enum YtDlpError: Error, LocalizedError {
    case notFound
    case searchFailed(String)
    case extractFailed(String)
    case noResults
    case invalidJson(String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "yt-dlp not found. Install: brew install yt-dlp"
        case .searchFailed(let detail):
            return "Search failed: \(detail)"
        case .extractFailed(let detail):
            return "Extract failed: \(detail)"
        case .noResults:
            return "No results found"
        case .invalidJson(let detail):
            return "Invalid JSON: \(detail)"
        }
    }
}

public final class YtDlpClient: Sendable {
    private let ytDlpPath: String
    private let decoder = JSONDecoder()

    public init() {
        let candidates = ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp"]
        self.ytDlpPath = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/yt-dlp"
    }

    public func search(query: String, maxResults: Int = 20) async throws -> [SearchResult] {
        let limitStr = "1:\(maxResults)"
        let searchStr = "ytsearch\(maxResults):\(query)"
        let args = ["--flat-playlist", "--dump-json", "--no-warnings", "-I", limitStr, searchStr]

        DebugLog.log("search() called, query=\(query)")
        let result = try await Task.detached(priority: .userInitiated) { [ytDlpPath] in
            DebugLog.log("Running yt-dlp on detached task")
            return try Self.runProcess(ytDlpPath: ytDlpPath, args: args)
        }.value

        DebugLog.log("yt-dlp exited: \(result.2), stdout=\(result.0.count)B stderr=\(result.1.prefix(200))")
        guard result.2 == 0 else {
            throw YtDlpError.searchFailed("exit \(result.2): \(result.1.prefix(300))")
        }

        let text = String(data: result.0, encoding: .utf8) ?? ""
        let lines = text.split(separator: "\n").map(String.init)

        var results: [SearchResult] = []
        for line in lines {
            guard !line.isEmpty else { continue }
            do {
                let item = try decoder.decode(YtDlpSearchItem.self, from: Data(line.utf8))
                let thumbUrl = item.thumbnail ?? item.thumbnails?.last?.url
                results.append(SearchResult(
                    id: item.id,
                    title: item.title ?? "Unknown",
                    uploader: item.uploader ?? item.channel ?? "",
                    duration: Int(item.duration ?? 0),
                    thumbnail: thumbUrl,
                    viewCount: item.view_count
                ))
            } catch {
                continue
            }
        }

        DebugLog.log("Parsed \(results.count) results")
        guard !results.isEmpty else { throw YtDlpError.noResults }
        return results
    }

    public func extractInfo(videoId: String) async throws -> StreamInfo {
        let url = "https://www.youtube.com/watch?v=\(videoId)"
        let args = ["--dump-json", "--no-warnings", "--no-playlist", url]

        DebugLog.log("extractInfo() called, id=\(videoId)")
        let result = try await Task.detached(priority: .userInitiated) { [ytDlpPath] in
            return try Self.runProcess(ytDlpPath: ytDlpPath, args: args)
        }.value

        DebugLog.log("yt-dlp exited: \(result.2), stdout=\(result.0.count)B")
        guard result.2 == 0 else {
            throw YtDlpError.extractFailed("exit \(result.2): \(result.1.prefix(300))")
        }

        do {
            let info = try decoder.decode(YtDlpVideoInfo.self, from: result.0)
            let thumbUrl = info.thumbnail ?? info.thumbnails?.last?.url
            return StreamInfo(
                id: info.id,
                title: info.title ?? "Unknown",
                thumbnail: thumbUrl,
                description: info.description,
                formats: info.formats ?? [],
                url: info.url
            )
        } catch {
            throw YtDlpError.invalidJson(error.localizedDescription)
        }
    }

    @Sendable
    private static func runProcess(ytDlpPath: String, args: [String]) throws -> (Data, String, Int32) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ytDlpPath)
        proc.arguments = args

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        proc.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        DebugLog.log("Starting process: \(ytDlpPath) \(args.joined(separator: " "))")

        try proc.run()
        DebugLog.log("Process launched, PID=\(proc.processIdentifier)")

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

        let stderr = String(data: errData, encoding: .utf8) ?? ""
        DebugLog.log("Pipes drained: stdout=\(outData.count)B stderr=\(errData.count)B")

        proc.waitUntilExit()
        DebugLog.log("Process exited: \(proc.terminationStatus)")

        return (outData, stderr, proc.terminationStatus)
    }
}

// MARK: - Private DTOs for yt-dlp JSON

private struct YtDlpSearchItem: Codable, Sendable {
    let id: String
    let title: String?
    let uploader: String?
    let channel: String?
    let duration: Double?
    let view_count: Int?
    let thumbnail: String?
    let thumbnails: [Thumbnail]?

    struct Thumbnail: Codable, Sendable {
        let url: String?
    }
}

private struct YtDlpVideoInfo: Codable, Sendable {
    let id: String
    let title: String?
    let description: String?
    let thumbnail: String?
    let thumbnails: [YtDlpSearchItem.Thumbnail]?
    let formats: [StreamInfo.Format]?
    let url: String?
}
