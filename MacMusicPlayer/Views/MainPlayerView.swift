import SwiftUI

/// Main player view assembling all components as per the design mockup.
/// Layout:
///   - Top: (empty — cover is background)
///   - Center: LyricsView
///   - Bottom: Control bar + PlaylistPanel (collapsible)
struct MainPlayerView: View {
    @ObservedObject var player: PlayerManager
    @State private var showPlaylist: Bool = false
    @State private var lyrics: [LyricLine] = []
    @State private var currentLyricIndex: Int = 0

    var body: some View {
        ZStack {
            // Album art background color wash
            AlbumArtBackground(
                accentColor: dominantColor(),
                isAnimating: player.isPlaying
            )

            VStack(spacing: 0) {
                // Spacer pushes content down
                Spacer()

                // === Lyrics Section ===
                LyricsView(lyrics: lyrics, currentLineIndex: currentLyricIndex)
                    .frame(maxHeight: .infinity)

                Spacer()

                // === Bottom Control Bar ===
                controlBar
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)

                // === Playlist Panel ===
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
        }
        .background(Color.tnBackground)
        .onAppear {
            loadLyrics()
        }
        .onChange(of: player.currentTrack) { _ in
            loadLyrics()
            // Update window title to show current track name
            if let window = NSApplication.shared.keyWindow as? MainPlayerWindow {
                window.updateTitle()
            }
        }
        .onChange(of: player.currentTime) { newTime in
            updateLyricIndex(time: newTime)
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        GeometryReader { geo in
            HStack(spacing: 12) {
                // Playback controls
                HStack(spacing: 8) {
                    controlButton("⏮") { player.playPrevious() }
                    playPauseButton
                    controlButton("⏭") { player.playNext() }
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
                    Text("♪")
                        .font(.system(size: 14))
                        .foregroundColor(showPlaylist ? Color.tnAccent : .white.opacity(0.4))
                        .frame(width: 30, height: 30)
                        .background(showPlaylist ? Color.tnAccent.opacity(0.06) : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(showPlaylist ? Color.tnAccent.opacity(0.12) : Color.white.opacity(0.03), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .frame(height: 44)
        }
        .frame(height: 44)
    }

    /// Play mode button — cycles sequential → singleLoop → random → sequential
    /// Uses SF Symbols for clean macOS-native icons.
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
            .padding(.vertical, 5)
            .background(Color.tnAccent.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.tnAccent.opacity(0.08), lineWidth: 1)
            )
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
            Text(player.isPlaying ? "⏸" : "▶")
                .font(.system(size: 18))
                .foregroundColor(Color.tnAccent)
                .frame(width: 44, height: 44)
                .background(Color.tnAccent.opacity(0.08))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.tnAccent.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func controlButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 34, height: 34)
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

    // MARK: - Dominant Color

    /// Returns a color based on the current track's album art, or a fallback blue.
    private func dominantColor() -> Color {
        guard let data = player.currentTrack?.albumArtData,
              let image = NSImage(data: data) else {
            return Color.tnAccent
        }
        return Color(nsColor: averageColor(from: image))
    }

    private func averageColor(from image: NSImage) -> NSColor {
        // Simple average color from the image
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return NSColor(red: 0.376, green: 0.690, blue: 1.0, alpha: 1)
        }
        let width = min(cgImage.width, 100)
        let height = min(cgImage.height, 100)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return NSColor(red: 0.376, green: 0.690, blue: 1.0, alpha: 1) }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0
        let count = width * height
        for i in 0..<count {
            let offset = i * 4
            r += UInt64(pixelData[offset])
            g += UInt64(pixelData[offset + 1])
            b += UInt64(pixelData[offset + 2])
        }

        return NSColor(
            red: CGFloat(r) / CGFloat(count) / 255,
            green: CGFloat(g) / CGFloat(count) / 255,
            blue: CGFloat(b) / CGFloat(count) / 255,
            alpha: 1
        )
    }
}

