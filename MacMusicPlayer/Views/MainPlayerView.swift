import SwiftUI

/// Main player view assembling all components.
/// Supports two modes: Home overview and Now Playing.
struct MainPlayerView: View {
    @ObservedObject var player: PlayerManager
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var lyrics: [LyricLine] = []
    @State private var lastLyricIndex: Int = -1

    /// Thread-safe artwork cache that auto-evicts under memory pressure.
    private let artworkCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 50
        return cache
    }()
    @AppStorage("bgMode") private var bgMode: String = "albumArt"
    @AppStorage("showPlaylist") private var showPlaylist: Bool = false
    @AppStorage("viewMode") private var viewMode: String = "nowPlaying"

    // 鼠标进入窗口 → 立即显示控制栏。鼠标离开窗口 → 等待 3 秒再隐藏
    @State private var controlsVisible: Bool = false
    /// 控制栏隐藏延迟计时器
    @State private var hideTimer: DispatchWorkItem?

    @State private var showRhythm: Bool = true
    /// 控制栏有未完成的操作时锁定，禁止自动隐藏（分享弹窗、下拉菜单等）
    @State private var controlsLocked: Bool = false

    /// Text of the currently highlighted lyric line, for share screenshot.
    private var currentLyricText: String {
        guard lastLyricIndex >= 0, lastLyricIndex < lyrics.count else { return "" }
        return lyrics[lastLyricIndex].text
    }

    /// Artwork from Track model, falling back to synchronous FLAC scan.
    private var currentArtworkData: Data? {
        guard let track = player.currentTrack else { return nil }
        if let data = track.albumArtData { return data }
        // Check NSCache (auto-evicts under memory pressure, count limit 50)
        let key = track.id.uuidString as NSString
        if let cached = artworkCache.object(forKey: key) { return cached as Data }
        let data = MetadataParser.parseArtworkDirect(from: track.url)
        if let data = data { artworkCache.setObject(data as NSData, forKey: key) }
        return data
    }

    var body: some View {
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
                        showRhythm: $showRhythm,
                        currentLyricLine: currentLyricText,
                        controlsLocked: $controlsLocked
                    )
                    Spacer()
                }
            }

            // Loading Overlay (shown during first launch track scanning)
            if player.isLoading && player.playlist.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在加载音乐库...")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // View Mode Selector (left side, vertically centered)
            viewModeSelector
        }
        .overlay(alignment: .trailing) {
            // Playlist Panel — seamlessly integrated with window background
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
            // No vertical padding — seamlessly edge-to-edge with window background
            .offset(x: showPlaylist ? 0 : 340)
            .opacity(showPlaylist ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showPlaylist)
        }
        .onHover { hovering in
            // 控制栏有未完成操作（弹窗、下拉等）时禁止自动隐藏
            guard !controlsLocked else {
                // Even when locked, ensure controls are visible
                controlsVisible = true
                return
            }

            if hovering {
                // 鼠标进入窗口 → 立即显示
                hideTimer?.cancel()
                hideTimer = nil
                withAnimation(.easeOut(duration: 0.6)) {
                    controlsVisible = true
                }
            } else {
                // 鼠标离开窗口 → 3 秒后隐藏
                hideTimer?.cancel()
                let work = DispatchWorkItem { [self] in
                    // Double-check lock before hiding
                    if !controlsLocked {
                        withAnimation(.easeOut(duration: 0.8)) {
                            controlsVisible = false
                        }
                    }
                }
                hideTimer = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
            }
        }
        .onAppear {
            loadLyrics()
            // Listen for async metadata completion to reload lyrics
            NotificationCenter.default.addObserver(
                forName: .currentTrackMetadataUpdated,
                object: nil,
                queue: .main
            ) { _ in
                self.loadLyrics()
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
        .onChange(of: player.currentTrack) { _ in
            loadLyrics()
            ensureCurrentTrackMetadata()
            if let window = NSApplication.shared.keyWindow as? MainPlayerWindow {
                window.updateTitle()
            }
        }
        // Observe TimeManager directly (not player.currentTime) so only
        // this closure fires every 1s instead of triggering a full body
        // re-evaluation of every PlayerManager-observing view.
        .onReceive(TimeManager.shared.$currentTime) { newTime in
            // Update lyric index every 250ms (matches time observer interval).
            // Binary search is O(log n), so this is negligible CPU cost.
            updateLyricIndex(time: newTime)
        }
    }

    // MARK: - Main Content

    /// Only render the active view — saves memory + CPU by not keeping inactive
    /// view trees (e.g. 300-row TrackEditorView) alive in the background.
    @ViewBuilder
    private var mainContent: some View {
        switch viewMode {
        case "home":
            HomeView(player: player)
        case "editor":
            TrackEditorView(player: player)
        default:
            NowPlayingView(
                artworkData: currentArtworkData,
                lyrics: lyrics,
                currentLineIndex: lastLyricIndex,
                isPlaying: player.isPlaying,
                showRhythm: showRhythm,
                showPlaylist: showPlaylist
            )
            // NOTE: No .id() on NowPlayingView! SwiftUI's natural prop diffing handles
            // lyrics refresh correctly — ForEach(id: \.element.id) in LyricsView sees new
            // UUIDs on track change and rebuilds rows. An .id() would destroy the ScrollView
            // state, causing lyrics scroll position loss (the "position offset" bug).
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

            Button(action: { viewMode = "editor" }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16))
                    .foregroundColor(viewMode == "editor" ? themeManager.accent : inactiveIconColor)
                    .frame(width: 36, height: 36)
                    .background(
                        viewMode == "editor"
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
        // Reset BEFORE loading new lyrics to avoid showing old lyrics/index
        // during the brief window between track change and lyrics parsing.
        lastLyricIndex = -1

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
            lastLyricIndex = -1
            return
        }
        // Guard against stale lastLyricIndex when lyrics array shrinks (e.g. track change)
        if lastLyricIndex >= lyrics.count { lastLyricIndex = -1 }

        // Binary search: find the last lyric line whose time <= current time
        // lyrics are sorted by time (LrcParser sorts them), so O(log n) instead of O(n)
        var lo = 0
        var hi = lyrics.count - 1
        var idx = -1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lyrics[mid].time <= time {
                idx = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }

        if idx != lastLyricIndex {
            lastLyricIndex = idx
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
