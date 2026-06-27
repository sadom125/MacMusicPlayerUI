import SwiftUI

/// Mini floating player — capsule design with album disc, info, and controls.
struct MiniPlayerView: View {
    @ObservedObject var player: PlayerManager
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var cachedLyrics: [LyricLine] = []
    @State private var cachedTrackID: UUID? = nil

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

    private var artworkData: Data? {
        if let data = player.currentTrack?.albumArtData { return data }
        guard let url = player.currentTrack?.url else { return nil }
        return MetadataParser.parseArtworkDirect(from: url)
    }

    // MARK: - Theme Colors

    private var primaryText: Color { themeManager.isDarkMode ? .white.opacity(0.9) : .black.opacity(0.85) }
    private var secondaryText: Color { themeManager.isDarkMode ? .white.opacity(0.45) : .black.opacity(0.45) }
    private var iconColor: Color { themeManager.isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var playBtnBg: Color { themeManager.isDarkMode ? .white.opacity(0.15) : .black.opacity(0.08) }
    private var progressBg: Color { themeManager.isDarkMode ? .white.opacity(0.12) : .black.opacity(0.08) }
    private var progressFill: Color { themeManager.isDarkMode ? .white.opacity(0.5) : .black.opacity(0.45) }
    private var separatorColor: Color { themeManager.isDarkMode ? .white.opacity(0.08) : .black.opacity(0.06) }

    var body: some View {
        VStack(spacing: 0) {
            // Main row: disc + info + expand button
            HStack(spacing: 12) {
                // Mini vinyl disc
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 40, height: 40)
                    if let data = artworkData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                            )
                    }
                    // Center dot
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 3, height: 3)
                }

                // Track info
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.currentTrack?.title ?? "No track")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(primaryText)
                        .lineLimit(1)
                    Text(player.currentTrack?.artist ?? "")
                        .font(.system(size: 10))
                        .foregroundColor(secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Expand button
                Button(action: returnToFullPlayer) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(progressBg).frame(height: 2)
                    Rectangle().fill(progressFill)
                        .frame(width: geo.size.width * progressRatio, height: 2)
                        .animation(.linear(duration: 0.3), value: progressRatio)
                }
            }
            .frame(height: 2)

            // Controls row
            HStack(spacing: 0) {
                Button(action: { player.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 13))
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundColor(primaryText)
                        .frame(width: 36, height: 36)
                        .background(playBtnBg)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { player.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13))
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .frame(width: 280, height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
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
        guard let miniPanel = NSApplication.shared.windows.first(where: { $0 is MiniPlayerWindow }) else { return }
        let miniFrame = miniPanel.frame

        guard let mainWindow = NSApplication.shared.windows.first(where: { $0 is MainPlayerWindow }) as? MainPlayerWindow else {
            (NSApplication.shared.delegate as? AppDelegate)?.showMainWindow()
            return
        }

        mainWindow.updateContent(MainPlayerView(player: player))

        mainWindow.titleVisibility = .visible
        mainWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        mainWindow.isMovableByWindowBackground = false
        mainWindow.level = .normal
        mainWindow.collectionBehavior = [.canJoinAllSpaces]

        let fullWidth: CGFloat = 1200
        let fullHeight: CGFloat = 750
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let targetFrame = NSRect(
            x: screenFrame.midX - fullWidth / 2,
            y: screenFrame.midY - fullHeight / 2,
            width: fullWidth,
            height: fullHeight
        )

        let savedOpacity = UserDefaults.standard.double(forKey: "windowOpacity")
        let targetOpacity: CGFloat = savedOpacity > 0 ? CGFloat(savedOpacity) : 1.0

        // Start at mini position, invisible
        mainWindow.setFrame(miniFrame, display: false)
        mainWindow.alphaValue = 0.0
        mainWindow.makeKeyAndOrderFront(nil)
        mainWindow.updateTitle()

        // Spring animation from mini to full
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.5
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
                ctx.allowsImplicitAnimation = true

                mainWindow.animator().setFrame(targetFrame, display: true)
                mainWindow.animator().alphaValue = targetOpacity
            } completionHandler: {
                miniPanel.orderOut(nil)
            }
        }
    }
}
