import Foundation
import Combine
import AppKit
import MediaPlayer
import AVFoundation

class PlayerManager: NSObject, ObservableObject {
    @Published var playlist: [Track] = []
    @Published var currentTrack: Track? {
        didSet {
            NotificationCenter.default.post(name: .trackChanged, object: nil)
        }
    }
    @Published var isPlaying = false {
        didSet {
            NotificationCenter.default.post(name: .playbackStateChanged, object: nil)
        }
    }
    @Published var isLoading = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private let queueController: QueuePlayerController
    private let playlistStore: PlaylistStore

    var hasPlaylist: Bool { !playlistStore.isEmpty }

    private var currentIndex = 0
    private var timeObserver: Any?
    private var metadataTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - File System Watcher
    private var fileSystemSource: DispatchSourceFileSystemObject?
    private var watchedFolderURL: URL?

    // MARK: - Playback Position Persistence
    private static let lastTrackURLKey = "lastPlayedTrackURL"

    /// Remember which track was playing, but NOT the exact time position.
    func savePlaybackPosition() {
        guard let track = currentTrack else { return }
        UserDefaults.standard.set(track.url.path, forKey: Self.lastTrackURLKey)
    }

    /// Restore to the saved track, starting from the beginning (time 0).
    func restorePlaybackPosition() {
        guard let trackPath = UserDefaults.standard.string(forKey: Self.lastTrackURLKey),
              let idx = playlist.firstIndex(where: { $0.url.path == trackPath }) else { return }

        // Advance to the saved track (queue starts at index 0).
        if idx > 0 {
            for _ in 0..<idx {
                _ = queueController.advanceToNext()
            }
        }

        playlistStore.setCurrentIndex(idx)
        currentIndex = idx
        currentTrack = playlist[idx]
        duration = playlist[idx].duration

        // Seek to the beginning of the track; no offset restore.
        queueController.queuePlayer.seek(to: .zero)
        currentTime = 0
    }

    var volume: Float {
        get { queueController.volume }
        set {
            queueController.volume = newValue
            UserDefaults.standard.set(newValue, forKey: "SavedVolume")
        }
    }

    func volumeUp() {
        volume = min(1.0, volume + 0.05)
    }

    func volumeDown() {
        volume = max(0.0, volume - 0.05)
    }


    @Published var playMode: PlayMode = .sequential {
        didSet {
            UserDefaults.standard.set(playMode.rawValue, forKey: "PlayMode")
            NotificationCenter.default.post(name: .playModeChanged, object: nil)
        }
    }

    override init() {
        queueController = QueuePlayerController()
        playlistStore = PlaylistStore()

        if let savedMode = UserDefaults.standard.string(forKey: "PlayMode"),
           let mode = PlayMode(rawValue: savedMode) {
            playMode = mode
        } else {
            playMode = .sequential
        }

        super.init()

        let savedVolume: Float
        if UserDefaults.standard.object(forKey: "SavedVolume") == nil {
            savedVolume = 0.3
            UserDefaults.standard.set(savedVolume, forKey: "SavedVolume")
        } else {
            savedVolume = UserDefaults.standard.float(forKey: "SavedVolume")
        }

        queueController.onTrackChanged = { [weak self] track in
            guard let self = self else { return }
            self.currentTrack = track

            if let track = track,
               let trackIndex = self.playlistStore.tracks.firstIndex(where: { $0.id == track.id }) {
                self.playlistStore.setCurrentIndex(trackIndex)
                self.currentIndex = trackIndex
            }

            // Update duration from the playing track
            if let t = track {
                self.duration = t.duration
            } else {
                self.duration = 0
            }

            // Add to playback history
            if let track = track {
                PlaybackHistory.shared.addToHistory(track)
            }

            self.updateNowPlayingInfo()
        }

        queueController.onPlaybackStateChanged = { [weak self] playing in
            self?.isPlaying = playing
        }

        queueController.onTrackFinished = { [weak self] finishedTrack in
            self?.handleAutomaticTrackCompletion(finishedTrack)
        }

        queueController.volume = savedVolume

        NotificationCenter.default.addObserver(self,
                                            selector: #selector(refreshMusicLibrary),
                                            name: .refreshMusicLibrary,
                                            object: nil)

        loadSavedMusicFolder()

        // Periodic time observer for current position
        setupTimeObserver()
    }

    private func setupTimeObserver() {
        // 1s interval — 250ms was overkill for UI refresh rate.
        // Time updates still happen via the 20fps TimelineView for visuals.
        // We skip updates when paused to avoid unnecessary SwiftUI re-renders.
        let interval = CMTime(seconds: 1.0, preferredTimescale: 10)
        timeObserver = queueController.queuePlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            guard self.isPlaying else { return }

            let secs = CMTimeGetSeconds(time)
            self.currentTime = secs.isFinite ? secs : 0

            // Always read real duration from AVPlayer (most accurate)
            if let playerDuration = self.queueController.currentItemDuration,
               playerDuration > 0, playerDuration.isFinite {
                if abs(self.duration - playerDuration) > 0.5 {
                    self.duration = playerDuration
                    self.syncDurationToCurrentTrack(playerDuration)
                }
            }
        }
    }

    deinit {
        // stopAndCleanup() may have already removed these
        if let observer = timeObserver {
            queueController.queuePlayer.removeTimeObserver(observer)
        }
        metadataTasks.values.forEach { $0.cancel() }
    }

    private func loadSavedMusicFolder() {
    }

    func requestMusicFolderAccess() {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.allowsMultipleSelection = false
            openPanel.prompt = NSLocalizedString("Select Music Folder", comment: "Open panel prompt for selecting music folder")

            if openPanel.runModal() == .OK {
                if let url = openPanel.url {
                    let name = url.lastPathComponent

                    NotificationCenter.default.post(
                        name: .addNewLibrary,
                        object: nil,
                        userInfo: ["name": name, "path": url.path]
                    )
                }
            }
        }
    }

    func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        if let currentTrack = queueController.currentTrack ?? currentTrack {
            nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrack.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = currentTrack.artist
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = queueController.isPlaying ? 1.0 : 0.0

            // Use stored duration first, fall back to AVPlayer
            let dur = currentTrack.duration > 0 ? currentTrack.duration : (queueController.currentItemDuration ?? 0)
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = dur

            if let elapsed = queueController.currentItemElapsedTime {
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
            }

            // Add album art if available — skip MPMediaItemArtwork to avoid
            // autorelease pool issues when its handler is called on background threads
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func loadLibrary(_ library: MusicLibrary) {
        queueController.clearQueue()
        currentTrack = nil
        isPlaying = false
        currentIndex = 0

        playlist = []
        isLoading = true

        loadTracksFromMusicFolder(URL(fileURLWithPath: library.path))
    }

    func loadTracksFromMusicFolder(_ folderURL: URL) {
        // Run heavy file enumeration + parsing on a background queue so the window
        // can appear immediately instead of blocking the main thread at launch.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let fileManager = FileManager.default

            guard let enumerator = fileManager.enumerator(at: folderURL,
                                                        includingPropertiesForKeys: [.isRegularFileKey],
                                                        options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
                print("Failed to enumerate folder contents")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            var newPlaylist: [Track] = []

            for case let fileURL as URL in enumerator {
                if self.isAudioFile(fileURL) {
                    let fileName = fileURL.deletingPathExtension().lastPathComponent

                    var title = fileName
                    var artist = NSLocalizedString("Unknown Artist", comment: "Default artist name when parsing filenames")

                    // Support both "歌名 - 歌手" and "歌名-歌手" formats
                    if let range = fileName.range(of: " - ") {
                        title = String(fileName[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                        artist = String(fileName[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    } else if let range = fileName.range(of: "-") {
                        title = String(fileName[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                        artist = String(fileName[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    }

                    let track = Track(
                        id: UUID(),
                        title: title,
                        artist: artist,
                        album: NSLocalizedString("Unknown Album", comment: "Default album name"),
                        albumArtData: nil,
                        duration: 0,
                        url: fileURL,
                        lyrics: nil
                    )
                    newPlaylist.append(track)
                }
            }

            // Kick off async metadata parsing in background — limit to 8 concurrent tasks
            let semaphore = AsyncSemaphore(limit: 8)
            for track in newPlaylist {
                let capturedURL = track.url
                let capturedTrack = track
                // Use .background priority so metadata parsing doesn't compete with
                // the 60fps disc rotation animation or other UI work.
                self.metadataTasks[track.id] = Task(priority: .background) { [weak self] in
                    guard let self else { return }
                    await semaphore.wait()
                    guard let meta = await MetadataParser.parse(from: capturedURL) else {
                        await semaphore.signal()
                        return
                    }
                    await semaphore.signal()
                    self.updateTrackDirect(capturedTrack, with: meta)
                }
            }

            // Parse first track's artwork & lyrics synchronously so UI has data immediately
            if var firstTrack = newPlaylist.first {
                let artwork = MetadataParser.parseArtworkDirect(from: firstTrack.url)
                let lyrics = MetadataParser.parseLyricsDirect(from: firstTrack.url)
                if artwork != nil || lyrics != nil {
                    firstTrack = Track(
                        id: firstTrack.id,
                        title: firstTrack.title,
                        artist: firstTrack.artist,
                        album: firstTrack.album,
                        albumArtData: artwork,
                        duration: firstTrack.duration,
                        url: firstTrack.url,
                        lyrics: lyrics
                    )
                    newPlaylist[0] = firstTrack
                }
            }

            DispatchQueue.main.async {
                let sortedTracks = newPlaylist.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

                self.playlistStore.setTracks(sortedTracks)

                self.playlist = sortedTracks
                self.isLoading = false

                if !sortedTracks.isEmpty {
                    self.currentIndex = 0
                    self.currentTrack = sortedTracks[0]
                    self.duration = sortedTracks[0].duration > 0 ? sortedTracks[0].duration : 0
                    self.playlistStore.setCurrentIndex(0)
                    self.queueController.setQueue(sortedTracks, startingAt: 0)
                } else {
                    self.currentTrack = nil
                    self.currentIndex = 0
                    self.duration = 0
                }

                NotificationCenter.default.post(name: .playlistUpdated, object: nil)

                // Restore last playback position
                self.restorePlaybackPosition()

                // Start file system watcher after loading
                self.startFileSystemWatcher(for: folderURL)
            }
        }
    }

    // MARK: - Silent Refresh (no playback interruption)

    /// Silently scan the folder and add/remove tracks without stopping playback.
    func silentRefreshLibrary() {
        guard let folderURL = watchedFolderURL else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let fileManager = FileManager.default

            guard let enumerator = fileManager.enumerator(at: folderURL,
                                                        includingPropertiesForKeys: [.isRegularFileKey],
                                                        options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return }

            // Collect current audio files on disk
            var diskFiles: Set<String> = []
            for case let fileURL as URL in enumerator {
                if self.isAudioFile(fileURL) {
                    diskFiles.insert(fileURL.standardized.path)
                }
            }

            let currentURLs = Set(self.playlist.map { $0.url.standardized.path })

            // Find new and removed files
            let newURLs = diskFiles.subtracting(currentURLs)
            let removedURLs = currentURLs.subtracting(diskFiles)

            guard !newURLs.isEmpty || !removedURLs.isEmpty else { return }

            DispatchQueue.main.async {
                // Remember what was playing
                let playingTrackID = self.currentTrack?.id
                let wasPlaying = self.isPlaying
                let savedTime = self.currentTime

                // Remove deleted tracks
                if !removedURLs.isEmpty {
                    self.playlist.removeAll { removedURLs.contains($0.url.standardized.path) }
                    self.playlistStore.setTracks(self.playlist)

                    // If the current track was removed, stop playback
                    if let playingID = playingTrackID,
                       !self.playlist.contains(where: { $0.id == playingID }) {
                        self.queueController.clearQueue()
                        self.currentTrack = nil
                        self.isPlaying = false
                        self.currentIndex = 0
                    }
                }

                // Add new tracks
                var newTracks: [Track] = []
                for pathString in newURLs {
                    let fileURL = URL(fileURLWithPath: pathString)
                    let fileName = fileURL.deletingPathExtension().lastPathComponent
                    var title = fileName
                    var artist = NSLocalizedString("Unknown Artist", comment: "Default artist name when parsing filenames")

                    if let range = fileName.range(of: " - ") {
                        title = String(fileName[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                        artist = String(fileName[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    } else if let range = fileName.range(of: "-") {
                        title = String(fileName[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                        artist = String(fileName[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    }

                    let track = Track(
                        id: UUID(),
                        title: title,
                        artist: artist,
                        album: NSLocalizedString("Unknown Album", comment: "Default album name"),
                        albumArtData: nil,
                        duration: 0,
                        url: fileURL,
                        lyrics: nil
                    )
                    newTracks.append(track)

                    // Async metadata parsing
                    let trackID = track.id
                    let capturedURL = fileURL
                    let capturedTrack = track
                    self.metadataTasks[trackID] = Task { [weak self] in
                        guard let self else { return }
                        guard let meta = await MetadataParser.parse(from: capturedURL) else { return }
                        self.updateTrackDirect(capturedTrack, with: meta)
                    }
                }

                // Merge: existing + new, then sort
                let merged = self.playlist + newTracks
                let sorted = merged.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                self.playlist = sorted
                self.playlistStore.setTracks(sorted)

                // Rebuild queue while preserving current track
                if let playingID = playingTrackID,
                   let newIdx = sorted.firstIndex(where: { $0.id == playingID }) {
                    self.currentIndex = newIdx
                    self.currentTrack = sorted[newIdx]
                    self.playlistStore.setCurrentIndex(newIdx)
                    self.queueController.setQueue(sorted, startingAt: newIdx)
                    // Seek back to where we were
                    if wasPlaying {
                        self.queueController.queuePlayer.seek(to: CMTime(seconds: savedTime, preferredTimescale: 10))
                        self.queueController.play()
                    }
                } else if !sorted.isEmpty && self.currentTrack == nil {
                    self.currentIndex = 0
                    self.currentTrack = sorted[0]
                    self.playlistStore.setCurrentIndex(0)
                    self.queueController.setQueue(sorted, startingAt: 0)
                }

                NotificationCenter.default.post(name: .playlistUpdated, object: nil)
            }
        }
    }

    // MARK: - File System Watcher

    private func startFileSystemWatcher(for folderURL: URL) {
        stopFileSystemWatcher()

        let fd = open(folderURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )

        var debounceWorkItem: DispatchWorkItem?

        source.setEventHandler { [weak self] in
            // Debounce: wait 1.5s after last event before refreshing
            debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.silentRefreshLibrary()
            }
            debounceWorkItem = work
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5, execute: work)
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileSystemSource = source
        watchedFolderURL = folderURL
    }

    private func stopFileSystemWatcher() {
        fileSystemSource?.cancel()
        fileSystemSource = nil
        watchedFolderURL = nil
    }

    /// Sync AVPlayer's accurate duration back to the Track model.
    private func syncDurationToCurrentTrack(_ playerDuration: TimeInterval) {
        guard let track = self.currentTrack,
              let idx = self.playlist.firstIndex(where: { $0.id == track.id }),
              abs(track.duration - playerDuration) > 0.5 else { return }
        let updated = Track(
            id: track.id, title: track.title, artist: track.artist,
            album: track.album, albumArtData: track.albumArtData,
            duration: playerDuration, url: track.url, lyrics: track.lyrics
        )
        self.playlist[idx] = updated
        self.currentTrack = updated
    }

    /// Replace a placeholder track with one containing real metadata from ID3 parsing.
    private func updateTrack(trackID: UUID, with meta: MetadataParser.Metadata) {
        guard let idx = playlist.firstIndex(where: { $0.id == trackID }) else { return }
        let old = playlist[idx]
        let updated = Track(
            id: old.id,
            title: meta.title,
            artist: meta.artist,
            album: meta.album,
            albumArtData: meta.artworkData,
            duration: meta.duration,
            url: old.url,
            lyrics: meta.lyrics
        )

        DispatchQueue.main.async { [self] in
            playlist[idx] = updated

            // Also update in playlistStore
            if let storeIdx = playlistStore.tracks.firstIndex(where: { $0.id == trackID }) {
                var storeTracks = playlistStore.tracks
                storeTracks[storeIdx] = updated
                playlistStore.setTracks(storeTracks)
            }

            // If this is the current track, update it
            if currentTrack?.id == trackID {
                currentTrack = updated
                duration = meta.duration
                if isPlaying {
                    updateNowPlayingInfo()
                }
            }
        }
    }

    /// Update track directly using captured Track reference (avoids playlist lookup race condition).
    private func updateTrackDirect(_ original: Track, with meta: MetadataParser.Metadata) {
        let updated = Track(
            id: original.id,
            title: meta.title,
            artist: meta.artist,
            album: meta.album,
            albumArtData: meta.artworkData,
            duration: meta.duration,
            url: original.url,
            lyrics: meta.lyrics
        )

        DispatchQueue.main.async { [self] in
            // Update in playlist by ID
            if let idx = playlist.firstIndex(where: { $0.id == original.id }) {
                playlist[idx] = updated
            }

            // Update in playlistStore
            if let storeIdx = playlistStore.tracks.firstIndex(where: { $0.id == original.id }) {
                var storeTracks = playlistStore.tracks
                storeTracks[storeIdx] = updated
                playlistStore.setTracks(storeTracks)
            }

            // If this is the current track, update it
            if currentTrack?.id == original.id {
                currentTrack = updated
                duration = meta.duration
                if isPlaying {
                    updateNowPlayingInfo()
                }
                // Notify views to reload lyrics/artwork now that metadata is available
                NotificationCenter.default.post(name: .currentTrackMetadataUpdated, object: nil)
            }
        }
    }

    /// Public method for views to update track metadata (e.g. sync artwork load).
    func updateTrackFromUI(_ track: Track, with meta: MetadataParser.Metadata) {
        updateTrackDirect(track, with: meta)
    }

    private func isAudioFile(_ url: URL) -> Bool {
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff", "dff", "dsf"]
        return audioExtensions.contains(url.pathExtension.lowercased())
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard let track = currentTrack else {
            print(NSLocalizedString("No current track to play", comment: ""))
            return
        }

        queueController.play()

        print(NSLocalizedString("Started playing", comment: "") + ": \(track.title)")

        updateNowPlayingInfo()
    }

    func pause() {
        queueController.pause()
        savePlaybackPosition()
        print(NSLocalizedString("Paused playback", comment: ""))
        updateNowPlayingInfo()
    }

    func stop() {
        queueController.stop()
        updateNowPlayingInfo()
    }

    /// Full cleanup for app termination — stops playback, cancels all tasks, removes observers.
    func stopAndCleanup() {
        // Cancel all background metadata parsing tasks
        metadataTasks.values.forEach { $0.cancel() }
        metadataTasks.removeAll()

        // Remove the periodic time observer BEFORE shutting down the player
        if let observer = timeObserver {
            queueController.queuePlayer.removeTimeObserver(observer)
            timeObserver = nil
        }

        // Shut down the queue controller — invalidates KVO first, then stops/clears
        queueController.shutdown()

        // Clear NowPlaying info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to time: TimeInterval) {
        // Only clamp to duration when we have a valid duration;
        // duration may be 0 initially for DSD/DFF files before metadata parses.
        let clamped: TimeInterval
        if duration > 0 {
            clamped = max(0, min(time, duration))
        } else {
            clamped = max(0, time)
        }

        // 立即更新 currentTime，让歌词和进度条即时响应
        currentTime = clamped

        let cmTime = CMTime(seconds: clamped, preferredTimescale: 1000)
        queueController.queuePlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func seek(by delta: TimeInterval) {
        seek(to: currentTime + delta)
    }

    func playTrack(at index: Int) {
        guard index >= 0 && index < playlistStore.tracks.count else { return }

        savePlaybackPosition()

        let tracks = playlistStore.tracks
        queueController.setQueue(tracks, startingAt: index)
        playlistStore.setCurrentIndex(index)
        currentIndex = index
        currentTrack = tracks[index]
        duration = tracks[index].duration
        queueController.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func clearQueue() {
        queueController.clearQueue()
        currentTrack = nil
        isPlaying = false
        currentIndex = 0
        duration = 0
        currentTime = 0
        updateNowPlayingInfo()
    }

    func playNext() {
        guard !playlistStore.isEmpty else { return }

        // Save current position before switching tracks
        savePlaybackPosition()

        guard let nextIndex = playlistStore.nextIndex(for: playMode) else {
            return
        }

        playlistStore.setCurrentIndex(nextIndex)

        switch playMode {
        case .sequential:
            if queueController.advanceToNext() {
                currentIndex = nextIndex
            } else {
                queueController.setQueue(playlistStore.tracks, startingAt: 0)
                playlistStore.setCurrentIndex(0)
                currentIndex = 0
                queueController.play()
            }
        case .singleLoop:
            queueController.stop()
            queueController.play()
        case .random:
            queueController.setQueue(playlistStore.tracks, startingAt: nextIndex)
            currentIndex = nextIndex
            queueController.play()
        }

        currentTrack = playlistStore.currentTrack
        if let t = currentTrack { duration = t.duration }

        updateNowPlayingInfo()
    }

    func playPrevious() {
        guard !playlistStore.isEmpty else { return }

        // Save current position before switching tracks
        savePlaybackPosition()

        switch playMode {
        case .sequential, .random:
            guard let previousIndex = playlistStore.previousIndex() else { return }

            queueController.setQueue(playlistStore.tracks, startingAt: previousIndex)
            playlistStore.setCurrentIndex(previousIndex)
            currentIndex = previousIndex
            queueController.play()

            currentTrack = playlistStore.currentTrack
            if let t = currentTrack { duration = t.duration }
        case .singleLoop:
            queueController.stop()
            queueController.play()
        }

        updateNowPlayingInfo()
    }


    @MainActor
    @objc func refreshMusicLibrary() {
        silentRefreshLibrary()
    }


    func feelingLucky() {
        guard !playlistStore.isEmpty else { return }

        var randomIndex = Int.random(in: 0..<playlistStore.count)
        if playlistStore.count > 1 {
            while randomIndex == playlistStore.currentIndex {
                randomIndex = Int.random(in: 0..<playlistStore.count)
            }
        }

        playTrack(at: randomIndex)
    }

    private func handleAutomaticTrackCompletion(_ finishedTrack: Track?) {
        guard !playlistStore.isEmpty else { return }

        switch playMode {
        case .sequential:
            guard
                let finishedTrack,
                let finishedIndex = playlistStore.tracks.firstIndex(where: { $0.id == finishedTrack.id })
            else { return }

            if finishedIndex == playlistStore.count - 1 {
                let nextIndex = (finishedIndex + 1) % playlistStore.count
                queueController.setQueue(playlistStore.tracks, startingAt: nextIndex)
                queueController.play()
                updateNowPlayingInfo()
            }

        case .singleLoop:
            guard
                let finishedTrack,
                let finishedIndex = playlistStore.tracks.firstIndex(where: { $0.id == finishedTrack.id })
            else { return }

            playlistStore.setCurrentIndex(finishedIndex)
            currentIndex = finishedIndex
            currentTrack = playlistStore.currentTrack
            if let t = currentTrack { duration = t.duration }

            queueController.setQueue(playlistStore.tracks, startingAt: finishedIndex)
            queueController.play()
            updateNowPlayingInfo()

        case .random:
            guard let nextIndex = playlistStore.nextIndex(for: playMode) else { return }

            queueController.setQueue(playlistStore.tracks, startingAt: nextIndex)
            playlistStore.setCurrentIndex(nextIndex)
            currentIndex = nextIndex
            queueController.play()

            currentTrack = playlistStore.currentTrack
            if let t = currentTrack { duration = t.duration }
            updateNowPlayingInfo()
        }
    }
}

// MARK: - Async Semaphore (limits concurrent async tasks)

/// A simple async semaphore for limiting concurrent Swift concurrency tasks.
actor AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.count = limit
    }

    func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            count += 1
        }
    }
}
