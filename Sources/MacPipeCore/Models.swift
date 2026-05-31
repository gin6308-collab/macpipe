import Foundation

public struct SearchResult: Codable, Identifiable, Hashable, Sendable {
    public let id: String          // video ID
    public let title: String
    public let uploader: String
    public let duration: Int       // seconds
    public let thumbnail: String?  // URL string
    public let viewCount: Int?

    public var durationFormatted: String {
        let hrs = duration / 3600
        let mins = (duration % 3600) / 60
        let secs = duration % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }

    public init(id: String, title: String, uploader: String, duration: Int, thumbnail: String?, viewCount: Int? = nil) {
        self.id = id
        self.title = title
        self.uploader = uploader
        self.duration = duration
        self.thumbnail = thumbnail
        self.viewCount = viewCount
    }
}

public struct StreamInfo: Codable, Sendable {
    public let id: String
    public let title: String
    public let thumbnail: String?
    public let description: String?

    public struct Format: Codable, Sendable {
        public let format_id: String
        public let ext: String
        public let url: String
        public let acodec: String?
        public let vcodec: String?
        public let filesize: Int?
        public let tbr: Double?
        public let abr: Double?
        public let vbr: Double?
        public let format_note: String?
        public let `protocol`: String?

        public var isAudioOnly: Bool {
            (vcodec == "none" || vcodec == nil) && acodec != "none"
        }
        public var isVideoWithAudio: Bool {
            vcodec != "none" && vcodec != nil && acodec != "none" && acodec != nil
        }
        public var isHLS: Bool {
            `protocol`?.contains("m3u8") ?? false
        }
    }

    public let formats: [Format]
    public let url: String?

    public var bestAudioFormat: Format? {
        formats.filter { $0.isAudioOnly }.max(by: { ($0.abr ?? 0) < ($1.abr ?? 0) })
    }

    public var bestVideoFormat: Format? {
        formats.filter { $0.isVideoWithAudio && !$0.isHLS }.max(by: { ($0.tbr ?? 0) < ($1.tbr ?? 0) })
    }

    public var playableUrl: String? {
        bestVideoFormat?.url ?? url
    }

    public var audioUrl: String? {
        bestAudioFormat?.url
    }

    public init(id: String, title: String, thumbnail: String?, description: String?, formats: [Format], url: String?) {
        self.id = id
        self.title = title
        self.thumbnail = thumbnail
        self.description = description
        self.formats = formats
        self.url = url
    }
}
