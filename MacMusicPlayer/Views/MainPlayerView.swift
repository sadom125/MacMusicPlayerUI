import SwiftUI

/// Main player view assembling all components as per the design mockup.
/// Layout:
///   - Top: (empty — cover is background)
///   - Center: LyricsView
///   - Bottom: Control bar + PlaylistPanel (collapsible, auto-hides during playback)
struct MainPlayerView: View {
    @ObservedObject var player: PlayerManager
    @State private var showPlaylist: Bool = false
    @State private var lyrics: [LyricLine] = []
    @State private var currentLyricIndex: Int = 0

    // MARK: - Auto-hide controls

    @State private var controlsVisible: Bool = true
    @State private var lastMouseActivity: Date = Date()
    @State private var mouseMonitor: Any? = nil
    @State private var idleTimer: Timer? = nil
    private let idleThreshold: TimeInterval = 3.0
    private let idleCheckInterval: TimeInterval = 0.5

    /// Artwork from Track model, falling back to synchronous FLAC scan.
    private var currentArtworkData: Data? {
        if let data = player.currentTrack?.albumArtData { return data }
        guard let url = player.currentTrack?.url else { return nil }
        return MetadataParser.parseArtworkDirect(from: url)
    }

    /// Background view that fills safely behind the VStack content.
    private var albumArtBackground: some View {
        AlbumArtBackground(
            artworkData: currentArtworkData,
            isAnimating: player.isPlaying
        )
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // === Lyrics Section ===
            LyricsView(lyrics: lyrics, currentLineIndex: currentLyricIndex)
                .frame(maxHeight: .infinity)

            Spacer()

            // === Auto-hiding Bottom Controls ===
            VStack(spacing: 0) {
                // Control bar
                controlBar
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)

                // Playlist panel
                if showPlaylist {
                    PlaylistPanel(
                        tracks: player.playlist,
                        currentTrackID: player.currentTrack?.id,
                        onTrackTap: { index in
                            player.playTrack(at: index)
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .offset(y: controlsVisible ? 0 : 110)
            .opacity(controlsVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.5), value: controlsVisible)
        }
        .background(albumArtBackground)
        .onAppear {
            loadLyrics()
            startMouseTracking()
        }
        .onDisappear {
            stopMouseTracking()
        }
        .onChange(of: player.currentTrack) { _ in
            loadLyrics()
            if let window = NSApplication.shared.keyWindow as? MainPlayerWindow {
                window.updateTitle()
            }
        }
        .onChange(of: player.currentTime) { newTime in
            updateLyricIndex(time: newTime)
        }
    }

    // MARK: - Control Glow
    // MARK: - Mouse Tracking

    private func startMouseTracking() {
        // Monitor mouse movement anywhere in the window
        let monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { event in
            self.onMouseActivity()
            return event
        }
        mouseMonitor = monitor

        // Periodic timer to check idle timeout
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleCheckInterval, repeats: true) { _ in
            let idle = Date().timeIntervalSince(self.lastMouseActivity)
            let shouldHide = self.player.isPlaying && idle > self.idleThreshold
            if self.controlsVisible == shouldHide {
                self.controlsVisible = !shouldHide
            }
        }
    }

    private func stopMouseTracking() {
        if let monitor = mouseMonitor as? AnyObject {
            NSEvent.removeMonitor(monitor)
        }
        mouseMonitor = nil
        idleTimer?.invalidate()
        idleTimer = nil
    }

    private func onMouseActivity() {
        lastMouseActivity = Date()
        if !controlsVisible {
            controlsVisible = true
        }
    }

    /// Switch to mini player with smooth animation
    private func switchToMiniPlayer() {
        guard let fullWindow = NSApplication.shared.windows.first(where: { $0 is MainPlayerWindow }) else { return }
        let sourceFrame = fullWindow.frame

        // Create mini player without showing it yet
        let miniWindow = MiniPlayerWindow.show(playerManager: player, showWindow: false)
        (NSApplication.shared.delegate as? AppDelegate)?.miniPlayerWindow = miniWindow
        miniWindow.delegate = NSApplication.shared.delegate as? NSWindowDelegate

        // Target is the top-right position set by MiniPlayerWindow.show
        let targetFrame = miniWindow.frame

        // Start at full window position, invisible
        miniWindow.setFrame(sourceFrame, display: false)
        miniWindow.alphaValue = 0.0

        // Hide full window first, then animate mini in
        fullWindow.orderOut(nil)

        miniWindow.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true

            miniWindow.animator().setFrame(targetFrame, display: true)
            miniWindow.animator().alphaValue = 1.0
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        GeometryReader { geo in
            HStack(spacing: 14) {
                // Playback controls
                HStack(spacing: 10) {
                    controlButton(icon: "backward.fill", size: 16) { player.playPrevious() }
                    playPauseButton
                    controlButton(icon: "forward.fill", size: 16) { player.playNext() }
                }

                // Progress — hidden when window is too narrow
                if geo.size.width >= 420 {
                    ProgressSlider(
                        currentTime: Binding(
                            get: { player.currentTime },
                            set: { player.currentTime = $0 }
                        ),
                        duration: player.duration,
                        onSeek: { time in player.seek(to: time) }
                    )
                }

                Spacer(minLength: 4)

                // Play mode toggle
                playModeButton

                // Playlist toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showPlaylist.toggle()
                    }
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(showPlaylist ? Color.tnAccent : .white.opacity(0.5))
                        .frame(width: 34, height: 34)
                        .background(
                            showPlaylist
                                ? Color.tnAccent.opacity(0.08)
                                : Color.white.opacity(0.04)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Mini player toggle
                Button(action: switchToMiniPlayer) {
                    Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Switch to mini player")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(height: 52)
            .background(
                // Glass effect for control bar
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 52)
    }

    /// Play mode button — cycles sequential → singleLoop → random → sequential
    private var playModeButton: some View {
        Button(action: {
            let modes: [PlayMode] = [.sequential, .singleLoop, .random]
            let currentIdx = modes.firstIndex(of: player.playMode) ?? 0
            let next = modes[(currentIdx + 1) % modes.count]
            player.playMode = next
        }) {
            HStack(spacing: 5) {
                Image(systemName: playModeIcon(player.playMode))
                    .font(.system(size: 12, weight: .medium))
                Text(playModeLabel(player.playMode))
                    .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func playModeIcon(_ mode: PlayMode) -> String {
        switch mode {
        case .sequential: return "repeat"
        case .singleLoop: return "repeat.1"
        case .random:     return "shuffle"
        }
    }

    private func playModeLabel(_ mode: PlayMode) -> String {
        switch mode {
        case .sequential: return "列表循环"
        case .singleLoop: return "单曲循环"
        case .random:     return "随机播放"
        }
    }

    private var playPauseButton: some View {
        Button(action: {
            player.isPlaying ? player.pause() : player.play()
        }) {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18))
                .foregroundColor(Color.tnAccent)
                .frame(width: 48, height: 48)
                .background(Color.tnAccent.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func controlButton(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Lyrics

    private func loadLyrics() {
        guard let track = player.currentTrack else {
            lyrics = []
            currentLyricIndex = 0
            return
        }

        // 1. Try external .lrc file alongside the audio file
        let lrcURL = track.url.deletingPathExtension().appendingPathExtension("lrc")
        if let lrcText = try? String(contentsOf: lrcURL, encoding: .utf8) {
            let parsed = LrcParser.parse(lrcText: lrcText)
            if !parsed.isEmpty {
                lyrics = parsed
                currentLyricIndex = 0
                return
            }
        }

        // 2. Try embedded lyrics from audio file metadata (e.g. FLAC Vorbis LYRICS tag)
        if let lrcText = track.lyrics, !lrcText.isEmpty {
            let parsed = LrcParser.parse(lrcText: lrcText)
            if !parsed.isEmpty {
                lyrics = parsed
                currentLyricIndex = 0
                return
            }
        }

        // 2b. Direct synchronous scan of raw FLAC Vorbis comments for LYRICS tag
        if let lrcText = MetadataParser.parseLyricsDirect(from: track.url), !lrcText.isEmpty {
            let parsed = LrcParser.parse(lrcText: lrcText)
            if !parsed.isEmpty {
                lyrics = parsed
                currentLyricIndex = 0
                return
            }
        }

        // 3. Fallback: show track info
        var fallbackLines: [LyricLine] = []
        fallbackLines.append(LyricLine(time: 0, text: track.title))
        if !track.artist.isEmpty, track.artist != NSLocalizedString("Unknown Artist", comment: "") {
            fallbackLines.append(LyricLine(time: 0, text: track.artist))
        }
        if !track.album.isEmpty, track.album != NSLocalizedString("Unknown Album", comment: "") {
            fallbackLines.append(LyricLine(time: 0, text: track.album))
        }
        if fallbackLines.isEmpty {
            fallbackLines.append(LyricLine(time: 0, text: track.title))
        }
        lyrics = fallbackLines
        currentLyricIndex = 0
    }

    private func updateLyricIndex(time: TimeInterval) {
        guard !lyrics.isEmpty else {
            if currentLyricIndex != 0 { currentLyricIndex = 0 }
            return
        }
        // Find the last lyric line whose time <= current time
        var idx = 0
        for i in 0..<lyrics.count {
            if lyrics[i].time <= time {
                idx = i
            }
        }
        // Only update when index actually changes (avoids unnecessary re-renders)
        if idx != currentLyricIndex {
            currentLyricIndex = idx
        }
    }
}


