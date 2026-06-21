import SwiftUI

/// Main player view assembling all components.
/// Supports two modes: Home overview and Now Playing.
struct MainPlayerView: View {
    @ObservedObject var player: PlayerManager
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var lyrics: [LyricLine] = []
    @State private var lastLyricIndex: Int = -1
    @State private var artworkFallbackCache: [UUID: Data?] = [:]
    @AppStorage("bgMode") private var bgMode: String = "albumArt"
    @AppStorage("showPlaylist") private var showPlaylist: Bool = false
    @AppStorage("viewMode") private var viewMode: String = "nowPlaying"

    // Auto-hide controls
    @State private var controlsVisible: Bool = true
    @State private var lastMouseActivity: Date = Date()
    @State private var mouseMonitor: Any? = nil
    @State private var idleTimer: Timer? = nil
    private let idleThreshold: TimeInterval = 3.0
    private let idleCheckInterval: TimeInterval = 0.5

    // Window height for full-size playlist panel
    @State private var windowHeight: CGFloat = 750
    @State private var showRhythm: Bool = false

    /// Artwork from Track model, falling back to synchronous FLAC scan.
    private var currentArtworkData: Data? {
        guard let track = player.currentTrack else { return nil }
        if let data = track.albumArtData { return data }
        if let cached = artworkFallbackCache[track.id] { return cached }
        let data = MetadataParser.parseArtworkDirect(from: track.url)
        artworkFallbackCache[track.id] = data
        return data
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Window-level glass background
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                // Dynamic gradient overlay based on album art
                AlbumArtBackground(
                    artworkData: bgMode == "none" ? nil : currentArtworkData,
                    trackID: player.currentTrack?.id,
                    isAnimating: player.isPlaying,
                    solidColor: solidBgColor
                )
                .ignoresSafeArea()

                // Main Content (with bottom padding for control bar)
                mainContent
                    .padding(.bottom, 120)

                // Control Bar (centered at bottom, overlapping content)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        CompactControlBar(
                            player: player,
                            isVisible: $controlsVisible,
                            onMiniPlayerToggle: { switchToMiniPlayer() },
                            onPlaylistToggle: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    showPlaylist.toggle()
                                }
                            },
                            showRhythm: $showRhythm
                        )
                        Spacer()
                    }
                }

                // View Mode Selector (left side, vertically centered)
                viewModeSelector
            }
            .overlay(alignment: .trailing) {
                // Playlist Panel — floating card with padding, rounded corners
                SidePlaylistPanel(
                    tracks: player.playlist,
                    currentTrackID: player.currentTrack?.id,
                    onTrackTap: { index in
                        player.playTrack(at: index)
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            showPlaylist = false
                        }
                    }
                )
                .frame(width: 300)
                .padding(.vertical, 20)
                .shadow(color: .black.opacity(0.25), radius: 20, x: -5, y: 0)
                .offset(x: showPlaylist ? 0 : 340)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showPlaylist)
            }
            .onAppear {
                windowHeight = geo.size.height
            }
            .onChange(of: geo.size) { newSize in
                windowHeight = newSize.height
            }
        }
        .onAppear {
            loadLyrics()
            startMouseTracking()
            // Listen for async metadata completion to reload lyrics
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("CurrentTrackMetadataUpdated"),
                object: nil,
                queue: .main
            ) { _ in
                self.loadLyrics()
            }
        }
        .onDisappear {
            stopMouseTracking()
        }
        .onChange(of: player.currentTrack) { _ in
            loadLyrics()
            ensureCurrentTrackMetadata()
            if let window = NSApplication.shared.keyWindow as? MainPlayerWindow {
                window.updateTitle()
            }
        }
        .onChange(of: player.currentTime) { newTime in
            updateLyricIndex(time: newTime)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if viewMode == "home" {
            HomeView(player: player)
        } else {
            NowPlayingView(
                artworkData: currentArtworkData,
                lyrics: lyrics,
                currentLineIndex: lastLyricIndex,
                currentTime: player.currentTime,
                isPlaying: player.isPlaying,
                showRhythm: showRhythm,
                showPlaylist: showPlaylist
            )
        }
    }

    // MARK: - View Mode Selector

    private var viewModeSelector: some View {
        let inactiveIconColor: Color = themeManager.isDarkMode ? Color.white.opacity(0.5) : Color.black.opacity(0.5)
        let inactiveBg: Color = themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05)

        return VStack(spacing: 16) {
            Button(action: { viewMode = "home" }) {
                Image(systemName: "house.fill")
                    .font(.system(size: 16))
                    .foregroundColor(viewMode == "home" ? themeManager.accent : inactiveIconColor)
                    .frame(width: 36, height: 36)
                    .background(
                        viewMode == "home"
                            ? themeManager.accent.opacity(0.15)
                            : inactiveBg
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button(action: { viewMode = "nowPlaying" }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(viewMode == "nowPlaying" ? themeManager.accent : inactiveIconColor)
                    .frame(width: 36, height: 36)
                    .background(
                        viewMode == "nowPlaying"
                            ? themeManager.accent.opacity(0.15)
                            : inactiveBg
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var solidBgColor: Color? {
        guard bgMode.hasPrefix("solid:") else { return nil }
        let hex = String(bgMode.dropFirst("solid:".count))
        return Color(hex: hex)
    }

    // MARK: - Metadata Refresh

    /// Ensure the current track has artwork loaded. If artwork is nil (async parsing
    /// hasn't finished yet), parse synchronously so the UI shows it immediately.
    private func ensureCurrentTrackMetadata() {
        guard let track = player.currentTrack else { return }
        guard track.albumArtData == nil else { return }

        // Parse artwork synchronously in background, then update track
        Task.detached(priority: .userInitiated) {
            guard let meta = await MetadataParser.parse(from: track.url) else { return }
            await MainActor.run {
                self.player.updateTrackFromUI(track, with: meta)
            }
        }
    }

    // MARK: - Lyrics Loading

    private func loadLyrics() {
        guard let track = player.currentTrack else {
            lyrics = []
            return
        }

        // 1. Try external .lrc file
        let lrcURL = track.url.deletingPathExtension().appendingPathExtension("lrc")
        if let lrcText = try? String(contentsOf: lrcURL, encoding: .utf8) {
            let parsed = LrcParser.parse(lrcText: lrcText)
            if !parsed.isEmpty {
                lyrics = LrcParser.assignWordsToLines(parsed)
                updateLyricIndex(time: player.currentTime)
                return
            }
        }

        // 2. Try embedded lyrics
        if let lrcText = track.lyrics, !lrcText.isEmpty {
            let parsed = LrcParser.parse(lrcText: lrcText)
            if !parsed.isEmpty {
                lyrics = LrcParser.assignWordsToLines(parsed)
                updateLyricIndex(time: player.currentTime)
                return
            }
        }

        // 2b. Direct synchronous scan
        if let lrcText = MetadataParser.parseLyricsDirect(from: track.url), !lrcText.isEmpty {
            let parsed = LrcParser.parse(lrcText: lrcText)
            if !parsed.isEmpty {
                lyrics = LrcParser.assignWordsToLines(parsed)
                updateLyricIndex(time: player.currentTime)
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
        updateLyricIndex(time: player.currentTime)
    }

    private func updateLyricIndex(time: TimeInterval) {
        guard !lyrics.isEmpty else {
            if lastLyricIndex != -1 { lastLyricIndex = -1 }
            return
        }
        // Guard against stale lastLyricIndex when lyrics array shrinks (e.g. track change)
        if lastLyricIndex >= lyrics.count { lastLyricIndex = -1 }
        let startIdx = (time > (lastLyricIndex >= 0 ? lyrics[lastLyricIndex].time : -1))
            ? lastLyricIndex >= 0 ? lastLyricIndex : 0
            : 0

        var idx = -1
        for i in startIdx..<lyrics.count {
            if lyrics[i].time <= time { idx = i } else { break }
        }
        if idx == -1 && startIdx > 0 {
            for i in 0..<min(startIdx, lyrics.count) {
                if lyrics[i].time <= time { idx = i } else { break }
            }
        }
        if idx != lastLyricIndex {
            lastLyricIndex = idx
        }
    }

    // MARK: - Mouse Tracking

    private func startMouseTracking() {
        let monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { event in
            self.onMouseActivity()
            return event
        }
        mouseMonitor = monitor

        idleTimer = Timer.scheduledTimer(withTimeInterval: idleCheckInterval, repeats: true) { _ in
            let idle = Date().timeIntervalSince(self.lastMouseActivity)
            let shouldHide = self.player.isPlaying && idle > self.idleThreshold
            DispatchQueue.main.async {
                if self.controlsVisible && shouldHide {
                    self.controlsVisible = false
                } else if !self.controlsVisible && !shouldHide {
                    self.controlsVisible = true
                }
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

    // MARK: - Mini Player Switch

    private func switchToMiniPlayer() {
        guard let fullWindow = NSApplication.shared.windows.first(where: { $0 is MainPlayerWindow }) else { return }

        UserDefaults.standard.set(fullWindow.isZoomed, forKey: "wasZoomedBeforeMini")

        if fullWindow.isZoomed {
            fullWindow.zoom(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.performMiniPlayerSwitch(fullWindow: fullWindow)
            }
        } else {
            performMiniPlayerSwitch(fullWindow: fullWindow)
        }
    }

    private func performMiniPlayerSwitch(fullWindow: NSWindow) {
        let sourceFrame = fullWindow.frame

        if let existingMini = (NSApplication.shared.delegate as? AppDelegate)?.miniPlayerWindow {
            existingMini.close()
        }

        let miniWindow = MiniPlayerWindow.show(playerManager: player, showWindow: false)
        (NSApplication.shared.delegate as? AppDelegate)?.miniPlayerWindow = miniWindow
        miniWindow.delegate = NSApplication.shared.delegate as? NSWindowDelegate

        let targetFrame = miniWindow.frame

        miniWindow.setFrame(sourceFrame, display: false)
        miniWindow.alphaValue = 0.0

        // Fade out main window
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            fullWindow.animator().alphaValue = 0.0
        } completionHandler: {
            fullWindow.orderOut(nil)
            fullWindow.alphaValue = 1.0

            // Show mini window with spring animation
            miniWindow.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
                ctx.allowsImplicitAnimation = true

                miniWindow.animator().setFrame(targetFrame, display: true)
                miniWindow.animator().alphaValue = 1.0
            }
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
