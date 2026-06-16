import SwiftUI

/// Mini floating player view — compact, always-on-top
struct MiniPlayerView: View {
    @ObservedObject var player: PlayerManager
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var cachedLyrics: [LyricLine] = []
    @State private var cachedTrackID: UUID? = nil

    /// Current active lyric line for display
    private var currentLyricText: String {
        guard !cachedLyrics.isEmpty, let track = player.currentTrack else {
            return player.currentTrack?.title ?? ""
        }
        let time = player.currentTime
        var lineText = track.title
        for i in 0..<cachedLyrics.count {
            if cachedLyrics[i].time <= time {
                lineText = cachedLyrics[i].text
            }
        }
        return lineText
    }

    /// Album art data with sync fallback
    private var artworkData: Data? {
        if let data = player.currentTrack?.albumArtData { return data }
        guard let url = player.currentTrack?.url else { return nil }
        return MetadataParser.parseArtworkDirect(from: url)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // SwiftUI material — follows rounded corners automatically
            Rectangle()
                .fill(.ultraThinMaterial)
                .allowsHitTesting(false)

            // Dark tint overlay for depth — light enough for glass to show through
            Rectangle()
                .fill(Color(red: 0.031, green: 0.031, blue: 0.055).opacity(0.35))
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top section: album art + info
                HStack(spacing: 10) {
                    // Album art thumbnail
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.031, green: 0.031, blue: 0.055))
                            .frame(width: 44, height: 44)

                        if let data = artworkData, let nsImage = NSImage(data: data) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipped()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Track info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentTrack?.title ?? "No track")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                        Text(player.currentTrack?.artist ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.accent)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    // Return to full player button
                    Button(action: returnToFullPlayer) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PressableButtonStyle(scaleDown: 0.82))
                    .help("Return to full player")
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)

                // Current lyric line
                Text(currentLyricText)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)

                // Thin progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.03))
                            .frame(height: 2)
                        Rectangle()
                            .fill(themeManager.accent.opacity(0.4))
                            .frame(
                                width: geo.size.width * progressRatio,
                                height: 2
                            )
                    }
                }
                .frame(height: 2)

                // Controls — larger touch targets
                HStack(spacing: 20) {
                    Button(action: { player.playPrevious() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(PressableButtonStyle(scaleDown: 0.82))

                    Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(themeManager.accent)
                            .frame(width: 48, height: 48)
                            .background(themeManager.accent.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle(scaleDown: 0.88))

                    Button(action: { player.playNext() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(PressableButtonStyle(scaleDown: 0.82))
                }
                .padding(.vertical, 10)
            }

        }
        .frame(width: 300, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(count: 2) {
            returnToFullPlayer()
        }
        .onAppear {
            loadLyricsForCurrentTrack()
        }
        .onChange(of: player.currentTrack?.title) { _ in
            loadLyricsForCurrentTrack()
        }
    }

    // MARK: - Helpers

    private func loadLyricsForCurrentTrack() {
        guard let track = player.currentTrack else {
            cachedLyrics = []
            cachedTrackID = nil
            return
        }
        // Try Track model, then direct scan
        if let lrcText = track.lyrics ?? MetadataParser.parseLyricsDirect(from: track.url),
           !lrcText.isEmpty {
            cachedLyrics = LrcParser.parse(lrcText: lrcText)
        } else {
            cachedLyrics = []
        }
        cachedTrackID = track.id
    }

    private var progressRatio: CGFloat {
        guard player.duration > 0 else { return 0 }
        return CGFloat(min(player.currentTime / player.duration, 1))
    }

    private func returnToFullPlayer() {
        // Get mini player window frame for animation start point
        guard let miniPanel = NSApplication.shared.windows.first(where: { $0 is MiniPlayerWindow }) else { return }
        let miniFrame = miniPanel.frame

        guard let mainWindow = NSApplication.shared.windows.first(where: { $0 is MainPlayerWindow }) as? MainPlayerWindow else {
            (NSApplication.shared.delegate as? AppDelegate)?.showMainWindow()
            return
        }

        // Reuse the existing hosting view (preserves glass background)
        mainWindow.updateContent(MainPlayerView(player: player))

        // Configure full window style
        mainWindow.titleVisibility = .visible
        mainWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        mainWindow.isMovableByWindowBackground = false
        mainWindow.level = .normal
        mainWindow.collectionBehavior = [.canJoinAllSpaces]

        // Check if playlist was open and use expanded width
        let playlistWasOpen = UserDefaults.standard.bool(forKey: "showPlaylist")
        let fullWidth: CGFloat = playlistWasOpen ? 1180 : 900
        let fullHeight: CGFloat = 650
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let targetX = screenFrame.midX - fullWidth / 2
        let targetY = screenFrame.midY - fullHeight / 2
        let targetFrame = NSRect(x: targetX, y: targetY, width: fullWidth, height: fullHeight)

        // Restore saved window opacity
        let savedOpacity = UserDefaults.standard.double(forKey: "windowOpacity")
        let targetOpacity = savedOpacity > 0 ? CGFloat(savedOpacity) : 1.0

        // Start full window at mini player position/size, then animate to centered target
        mainWindow.setFrame(miniFrame, display: false)
        mainWindow.alphaValue = 0.0
        mainWindow.makeKeyAndOrderFront(nil)
        mainWindow.updateTitle()

        // Force glass view redraw to avoid black flash
        mainWindow.displayIfNeeded()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true

            mainWindow.animator().setFrame(targetFrame, display: true)
            mainWindow.animator().alphaValue = targetOpacity
        } completionHandler: {
            miniPanel.orderOut(nil)
            // Force glass re-render after animation
            mainWindow.displayIfNeeded()
        }
    }
}

/// Bridge NSVisualEffectView for SwiftUI


