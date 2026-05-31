import SwiftUI
import AVKit
import MacPipeCore

struct ContentView: View {
    @State private var searchQuery: String = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var selectedResult: SearchResult?
    @State private var searchTask: Task<Void, Never>?

    @State private var playerModel = PlayerModel()
    private let ytDlp = YtDlpClient()

    var body: some View {
        NavigationSplitView {
            // Sidebar: search + results
            VStack(spacing: 0) {
                searchField
                Divider()
                resultsList
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 350)
        } detail: {
            // Detail: player
            detailView
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search YouTube...", text: $searchQuery)
                .textFieldStyle(.plain)
                .onSubmit {
                    performSearch()
                }
            if isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    results = []
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
    }

    // MARK: - Results List

    private var resultsList: some View {
        Group {
            if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .frame(maxHeight: .infinity)
            } else if results.isEmpty && !isSearching {
                VStack {
                    Image(systemName: "play.rectangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Search for videos")
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(results, selection: $selectedResult) { result in
                    SearchResultRow(result: result)
                        .contextMenu {
                            Button("Play Video") {
                                Task { await playerModel.playVideo(result) }
                            }
                            Button("Play Audio Only") {
                                Task { await playerModel.playVideo(result) }
                                // Small delay to let it start, then switch to audio
                                Task {
                                    try? await Task.sleep(for: .seconds(2))
                                    playerModel.switchToAudioOnly()
                                }
                            }
                        }
                        .onTapGesture(count: 2) {
                            Task { await playerModel.playVideo(result) }
                        }
                }
                .listStyle(.inset)
                .onChange(of: selectedResult) { _, new in
                    if let r = new {
                        Task { await playerModel.playVideo(r) }
                    }
                }
            }
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        if playerModel.isLoading {
            VStack {
                ProgressView("Loading...")
                    .controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = playerModel.errorMessage {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let player = playerModel.player {
            VStack(spacing: 0) {
                // Title bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playerModel.currentTitle)
                            .font(.headline)
                            .lineLimit(2)
                    }
                    Spacer()
                    // Audio/Video toggle
                    Button {
                        if playerModel.playbackMode == .video {
                            playerModel.switchToAudioOnly()
                        } else {
                            playerModel.switchToVideo()
                        }
                    } label: {
                        Label(
                            playerModel.playbackMode == .video ? "Video" : "Audio",
                            systemImage: playerModel.playbackMode == .video ? "video" : "music.note"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        playerModel.togglePlayPause()
                    } label: {
                        Image(systemName: playerModel.isPlaying ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                // Player area
                if playerModel.playbackMode == .video {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Audio-only mode
                    VStack(spacing: 20) {
                        Spacer()
                        if let thumb = playerModel.currentThumbnail, let url = URL(string: thumb) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 300)
                                        .cornerRadius(8)
                                        .shadow(radius: 10)
                                case .failure:
                                    Image(systemName: "music.note")
                                        .font(.system(size: 80))
                                        .foregroundStyle(.secondary)
                                default:
                                    ProgressView()
                                }
                            }
                        }
                        Text(playerModel.currentTitle)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background)
                }
            }
        } else {
            // Empty state
            VStack(spacing: 16) {
                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.system(size: 60))
                    .foregroundStyle(.tertiary)
                Text("Select a video to play")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Double-click a search result, or right-click for options")
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Search

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        searchTask?.cancel()
        searchTask = Task {
            isSearching = true
            errorMessage = nil

            do {
                DebugLog.log("Search starting for query: \(self.searchQuery)")
                let searchResults = try await ytDlp.search(query: searchQuery, maxResults: 20)
                DebugLog.log("Search returned \(searchResults.count) results")
                try Task.checkCancellation()
                results = searchResults
            } catch is CancellationError {
                // Ignore
            } catch {
                DebugLog.log("Search FAILED: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }

            isSearching = false
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail
            if let thumbStr = result.thumbnail, let url = URL(string: thumbStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "play.rectangle")
                            .foregroundStyle(.secondary)
                    default:
                        ProgressView()
                    }
                }
                .frame(width: 120, height: 68)
                .clipped()
                .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 120, height: 68)
                    .cornerRadius(4)
                    .overlay {
                        Image(systemName: "play.rectangle")
                            .foregroundStyle(.tertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                Text(result.uploader)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(result.durationFormatted)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
