import Foundation
import AVFoundation

class QueuePlayerController: NSObject, PlaybackControlling {
    let queuePlayer: AVQueuePlayer
    private var playerItems: [AVPlayerItem] = []
    private var tracks: [Track] = []
    private var currentTrackIndex: Int = 0
    private var tempWAVFiles: [URL] = [] // Track temporary WAV files for cleanup

    var onTrackChanged: ((Track?) -> Void)?
    var onPlaybackStateChanged: ((Bool) -> Void)?
    var onTrackFinished: ((Track?) -> Void)?

    var isPlaying: Bool {
        queuePlayer.rate > 0
    }

    var currentTrack: Track? {
        guard currentTrackIndex < tracks.count else { return nil }
        return tracks[currentTrackIndex]
    }

    var volume: Float {
        get { queuePlayer.volume }
        set { queuePlayer.volume = newValue }
    }

    var currentItemDuration: TimeInterval? {
        guard let duration = queuePlayer.currentItem?.asset.duration else { return nil }
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite ? seconds : nil
    }

    var currentItemElapsedTime: TimeInterval? {
        let currentTime = queuePlayer.currentTime()
        let seconds = CMTimeGetSeconds(currentTime)
        return seconds.isFinite ? seconds : nil
    }

    private var rateObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?

    override init() {
        queuePlayer = AVQueuePlayer()
        super.init()
        setupObservers()
    }

    /// Shutdown for app termination — invalidate KVO BEFORE stopping to prevent
    /// callbacks from firing during cleanup (which causes autorelease pool crashes).
    func shutdown() {
        // 1. Nil callbacks first — prevents any KVO callback from doing work
        onTrackChanged = nil
        onPlaybackStateChanged = nil
        onTrackFinished = nil

        // 2. Invalidate KVO observations — must happen BEFORE stop/clearQueue
        //    because removeAllItems() triggers currentItem KVO on a background thread
        rateObservation?.invalidate()
        rateObservation = nil
        currentItemObservation?.invalidate()
        currentItemObservation = nil

        // 3. Remove notification observer
        NotificationCenter.default.removeObserver(self)

        // 4. Now safe to stop and clear — no KVO will fire
        queuePlayer.pause()
        queuePlayer.removeAllItems()
        playerItems.removeAll()
        tracks.removeAll()

        // 5. Clean up temp files
        cleanupTempFiles()
    }

    deinit {
        // NSKeyValueObservation auto-invalidates on dealloc — no manual remove needed
        rateObservation = nil
        currentItemObservation = nil
        NotificationCenter.default.removeObserver(self)
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        rateObservation = queuePlayer.observe(\.rate, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.onPlaybackStateChanged?(self?.isPlaying ?? false)
            }
        }

        currentItemObservation = queuePlayer.observe(\.currentItem, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateCurrentTrackIndex()
                self?.onTrackChanged?(self?.currentTrack)
            }
        }
    }

    @objc private func playerItemDidFinish(_ notification: Notification) {
        guard let finishedItem = notification.object as? AVPlayerItem,
              let index = playerItems.firstIndex(of: finishedItem),
              index < tracks.count else {
            return
        }

        onTrackFinished?(tracks[index])
    }

    private func updateCurrentTrackIndex() {
        guard let currentItem = queuePlayer.currentItem,
              let index = playerItems.firstIndex(of: currentItem) else {
            return
        }
        currentTrackIndex = index
    }


    func play() {
        queuePlayer.play()
    }

    func pause() {
        queuePlayer.pause()
    }

    func stop() {
        queuePlayer.pause()
        queuePlayer.seek(to: .zero)
    }

    func clearQueue() {
        queuePlayer.removeAllItems()
        playerItems.removeAll()
        tracks.removeAll()
        currentTrackIndex = 0
        cleanupTempFiles()
    }

    func setQueue(_ tracks: [Track], startingAt index: Int) {
        clearQueue()

        guard !tracks.isEmpty else { return }

        self.tracks = tracks

        var newPlayerItems: [AVPlayerItem] = []
        newPlayerItems.reserveCapacity(tracks.count)

        for track in tracks {
            let playerItem = createPlayerItem(from: track)
            newPlayerItems.append(playerItem)
        }

        guard !newPlayerItems.isEmpty else { return }

        playerItems = newPlayerItems

        let boundedIndex = max(0, min(index, playerItems.count - 1))
        currentTrackIndex = boundedIndex

        let orderedIndices = Array(boundedIndex..<playerItems.count) + Array(0..<boundedIndex)

        for trackIndex in orderedIndices {
            let playerItem = playerItems[trackIndex]
            queuePlayer.insert(playerItem, after: queuePlayer.items().last)
        }
    }

    func advanceToNext() -> Bool {
        guard currentTrackIndex < tracks.count - 1 else { return false }
        queuePlayer.advanceToNextItem()
        return true
    }

    private func createPlayerItem(from track: Track) -> AVPlayerItem {
        // DFF/DSF (DSD) files need ffmpeg conversion to PCM for AVFoundation playback
        let ext = track.url.pathExtension.lowercased()
        if ext == "dff" || ext == "dsf" {
            if let wavURL = convertDSDToWAV(track.url) {
                tempWAVFiles.append(wavURL)
                return AVPlayerItem(url: wavURL)
            }
            NSLog("[QueuePlayer] Failed to convert DSD file: %@", track.url.lastPathComponent)
        }
        return AVPlayerItem(url: track.url)
    }

    /// Convert DFF/DSF to temporary WAV using ffmpeg
    private func convertDSDToWAV(_ sourceURL: URL) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempName = "lx_dsd_\(UUID().uuidString).wav"
        let tempURL = tempDir.appendingPathComponent(tempName)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        process.arguments = [
            "-y",              // Overwrite output
            "-i", sourceURL.path,
            "-acodec", "pcm_s16le",  // 16-bit PCM
            "-ar", "176400",   // DSD64 → 176.4kHz PCM
            "-ac", "2",        // Stereo
            tempURL.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: tempURL.path) {
                NSLog("[QueuePlayer] Converted DSD to WAV: %@", tempURL.lastPathComponent)
                return tempURL
            }
        } catch {
            NSLog("[QueuePlayer] ffmpeg error: %@", error.localizedDescription)
        }
        return nil
    }

    /// Clean up temporary WAV files
    private func cleanupTempFiles() {
        for file in tempWAVFiles {
            try? FileManager.default.removeItem(at: file)
        }
        tempWAVFiles.removeAll()
    }
}
