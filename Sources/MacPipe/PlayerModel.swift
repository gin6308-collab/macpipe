import Foundation
import AVKit
import Observation
import MacPipeCore

enum PlaybackMode {
    case video
    case audioOnly
}

@Observable
@MainActor
final class PlayerModel {
    var player: AVPlayer?
    var currentTitle: String = ""
    var currentThumbnail: String?
    var playbackMode: PlaybackMode = .video
    var streamUrl: String?
    var audioUrl: String?
    var isPlaying: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    private let ytDlp = YtDlpClient()

    func playVideo(_ result: SearchResult) async {
        isLoading = true
        errorMessage = nil

        do {
            let info = try await ytDlp.extractInfo(videoId: result.id)

            currentTitle = info.title
            currentThumbnail = info.thumbnail
            streamUrl = info.playableUrl
            audioUrl = info.audioUrl

            // Default to video mode
            playbackMode = .video
            if let urlStr = info.playableUrl, let url = URL(string: urlStr) {
                player = AVPlayer(url: url)
                player?.play()
                isPlaying = true
            } else {
                errorMessage = "No playable stream found"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func switchToAudioOnly() {
        guard let audioUrlStr = audioUrl, let url = URL(string: audioUrlStr) else {
            errorMessage = "No audio-only stream available"
            return
        }

        let currentTime = player?.currentTime() ?? CMTime.zero
        let wasPlaying = isPlaying

        player = AVPlayer(url: url)
        if let time = Optional(currentTime), time.seconds > 0 {
            player?.seek(to: time)
        }
        playbackMode = .audioOnly
        if wasPlaying {
            player?.play()
            isPlaying = true
        }
    }

    func switchToVideo() {
        guard let streamUrlStr = streamUrl, let url = URL(string: streamUrlStr) else {
            errorMessage = "No video stream available"
            return
        }

        let currentTime = player?.currentTime() ?? CMTime.zero
        let wasPlaying = isPlaying

        player = AVPlayer(url: url)
        if let time = Optional(currentTime), time.seconds > 0 {
            player?.seek(to: time)
        }
        playbackMode = .video
        if wasPlaying {
            player?.play()
            isPlaying = true
        }
    }

    func togglePlayPause() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        playbackMode = .video
    }
}
