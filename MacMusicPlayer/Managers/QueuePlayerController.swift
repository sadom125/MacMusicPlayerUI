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

    override init() {
        queuePlayer = AVQueuePlayer()
        super.init()
        setupObservers()
    }

    deinit {
        removeObservers()
        cleanupTempFiles()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        queuePlayer.addObserver(self, forKeyPath: "rate", options: [.new], context: nil)
        queuePlayer.addObserver(self, forKeyPath: "currentItem", options: [.new], context: nil)
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        queuePlayer.removeObserver(self, forKeyPath: "rate")
        queuePlayer.removeObserver(self, forKeyPath: "currentItem")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            onPlaybackStateChanged?(isPlaying)
        } else if keyPath == "currentItem" {
            updateCurrentTrackIndex()
            onTrackChanged?(currentTrack)
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
