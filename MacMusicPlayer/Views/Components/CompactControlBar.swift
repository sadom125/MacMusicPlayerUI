import SwiftUI

/// Floating control bar at the bottom of the player.
/// Minimalist design matching reference: subtle colors, clean layout, overlapping content.
/// Adapts to light/dark mode.
struct CompactControlBar: View {
    @ObservedObject var player: PlayerManager
    @Binding var isVisible: Bool
    var onMiniPlayerToggle: () -> Void
    var onPlaylistToggle: () -> Void
    @Binding var showRhythm: Bool
    /// Current lyric line text for share screenshot, empty if none.
    var currentLyricLine: String = ""
    /// 控制栏交互锁定 — 有弹窗/下拉等操作时禁止父视图自动隐藏
    @Binding var controlsLocked: Bool

    @State private var volume: Float = 0.3
    @State private var showSharePopover: Bool = false
    @State private var likeBurstCount: Int = 0
    @State private var starBurstCount: Int = 0
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared

    private var isFavorited: Bool {
        guard let track = player.currentTrack else { return false }
        return favoritesManager.isFavorite(track)
    }

    private func toggleFavorite() {
        guard let track = player.currentTrack else { return }
        favoritesManager.toggle(track)
    }

    var body: some View {
        VStack(spacing: 14) {
            // Top Row: Track Info + Action Buttons
            topRow

            // Bottom Row: Playback Controls + Progress Bar
            bottomRow
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(themeManager.isDarkMode ? 0.1 : 0.15), lineWidth: 0.5)
                )
        )
        .frame(maxWidth: 720)
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
        .offset(y: isVisible ? 0 : 100)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95, anchor: .bottom)
    }

    // MARK: - Top Row (Track Info + Actions)

    private var topRow: some View {
        HStack(spacing: 20) {
            // Left actions
            HStack(spacing: 16) {
                // Play mode toggle: sequential -> singleLoop -> random -> sequential
                Button(action: {
                    let modes: [PlayMode] = [.sequential, .singleLoop, .random]
                    if let idx = modes.firstIndex(of: player.playMode) {
                        player.playMode = modes[(idx + 1) % modes.count]
                    }
                }) {
                    Image(systemName: playModeIcon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help(playModeHelp)

                Button(action: {
                    likeBurstCount += 1
                }) {
                    Image(systemName: "hand.thumbsup")
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help("点赞")
                .background(
                    Group {
                        if likeBurstCount > 0 {
                            LikeBurstAnimation()
                                .id(likeBurstCount)
                                .offset(y: -20)
                                .frame(width: 200, height: 200, alignment: .center)
                        }
                    },
                    alignment: .center
                )
            }

            Spacer(minLength: 0)

            // Center: Track Info
            if let track = player.currentTrack {
                VStack(spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: 220)
            }

            Spacer(minLength: 0)

            // Right actions
            HStack(spacing: 16) {
                Button(action: { showSharePopover = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSharePopover, arrowEdge: .bottom) {
                    SharePopoverView(
                        track: player.currentTrack,
                        currentLyricLine: currentLyricLine,
                        onShareInfo: { track in
                            showSharePopover = false
                            ShareManager.shareSongInfo(track)
                        },
                        onShareScreenshot: { track in
                            showSharePopover = false
                            ShareManager.shareLyricsCard(track, currentLyricLine: currentLyricLine)
                        }
                    )
                    .onAppear { controlsLocked = true }
                    .onDisappear { controlsLocked = false }
                }

                Button(action: {
                    let before = isFavorited
                    toggleFavorite()
                    if !before {
                        starBurstCount += 1
                    }
                }) {
                    Image(systemName: isFavorited ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundColor(isFavorited ? .yellow : iconColor)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help(isFavorited ? "取消收藏" : "收藏")
                .background(
                    Group {
                        if starBurstCount > 0 {
                            StarBurstAnimation()
                                .id(starBurstCount)
                                .offset(y: -20)
                                .frame(width: 200, height: 200, alignment: .center)
                        }
                    },
                    alignment: .center
                )
            }
        }
    }

    // MARK: - Bottom Row (Playback Controls + Progress)

    private var bottomRow: some View {
        HStack(spacing: 16) {
            // Playback Controls
            HStack(spacing: 26) {
                Button(action: { player.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button(action: { player.togglePlayPause() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(primaryTextColor)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                Button(action: { player.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

            // Progress Slider
            ProgressSlider(
                currentTime: Binding(
                    get: { player.currentTime },
                    set: { player.currentTime = $0 }
                ),
                duration: player.duration,
                onSeek: { time in player.seek(to: time) }
            )

            // Volume
            HStack(spacing: 6) {
                Button(action: {
                    volume = volume > 0 ? 0 : 0.3
                    player.volume = volume
                }) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 13))
                        .foregroundColor(iconColor)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Slider(value: Binding(
                    get: { Double(volume) },
                    set: { volume = Float($0); player.volume = volume }
                ), in: 0...1)
                    .frame(width: 60)
                    .tint(themeManager.isDarkMode ? .white.opacity(0.3) : .black.opacity(0.2))
            }

            // Playlist Toggle
            Button(action: onPlaylistToggle) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            // Rhythm Toggle
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showRhythm.toggle() } }) {
                Image(systemName: "waveform")
                    .font(.system(size: 15))
                    .foregroundColor(showRhythm ? .red : iconColor)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            volume = player.volume
        }
    }

    // MARK: - Theme-adaptive colors (glass effect)

    private var iconColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.5)
    }

    private var primaryTextColor: Color {
        themeManager.isDarkMode ? .white : .black
    }

    private var secondaryTextColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6)
    }

    private var volumeIcon: String {
        if volume <= 0 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private var playModeIcon: String {
        switch player.playMode {
        case .sequential: return "repeat"
        case .singleLoop: return "repeat.1"
        case .random: return "shuffle"
        }
    }

    private var playModeHelp: String {
        switch player.playMode {
        case .sequential: return "列表循环"
        case .singleLoop: return "单曲循环"
        case .random: return "随机播放"
        }
    }
}
