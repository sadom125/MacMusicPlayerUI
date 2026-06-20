import SwiftUI

/// Floating control bar at the bottom of the player.
/// Minimalist design matching reference: subtle colors, clean layout, overlapping content.
/// Adapts to light/dark mode.
struct CompactControlBar: View {
    @ObservedObject var player: PlayerManager
    @Binding var isVisible: Bool
    var onMiniPlayerToggle: () -> Void
    var onPlaylistToggle: () -> Void

    @State private var volume: Float = 0.3
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 12) {
            // Top Row: Track Info + Action Buttons
            topRow

            // Bottom Row: Playback Controls + Progress Bar
            bottomRow
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(themeManager.isDarkMode ? 0.1 : 0.15), lineWidth: 0.5)
                )
        )
        .frame(maxWidth: 620)
        .padding(.horizontal, 40)
        .padding(.bottom, 16)
        .offset(y: isVisible ? 0 : 100)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: isVisible)
    }

    // MARK: - Top Row (Track Info + Actions)

    private var topRow: some View {
        HStack(spacing: 16) {
            // Left actions
            HStack(spacing: 12) {
                // Play mode toggle: sequential -> singleLoop -> random -> sequential
                Button(action: {
                    let modes: [PlayMode] = [.sequential, .singleLoop, .random]
                    if let idx = modes.firstIndex(of: player.playMode) {
                        player.playMode = modes[(idx + 1) % modes.count]
                    }
                }) {
                    Image(systemName: playModeIcon)
                        .font(.system(size: 12))
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)
                .help(playModeHelp)

                Button(action: {}) {
                    Image(systemName: "hand.thumbsup")
                        .font(.system(size: 12))
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            // Center: Track Info
            if let track = player.currentTrack {
                VStack(spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 11))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: 200)
            }

            Spacer(minLength: 0)

            // Right actions
            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "star")
                        .font(.system(size: 12))
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Bottom Row (Playback Controls + Progress)

    private var bottomRow: some View {
        HStack(spacing: 14) {
            // Playback Controls
            HStack(spacing: 20) {
                Button(action: { player.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 13))
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)

                Button(action: { player.togglePlayPause() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(primaryTextColor)
                }
                .buttonStyle(.plain)

                Button(action: { player.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13))
                        .foregroundColor(iconColor)
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
            HStack(spacing: 4) {
                Button(action: {
                    volume = volume > 0 ? 0 : 0.3
                    player.volume = volume
                }) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 10))
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)

                Slider(value: Binding(
                    get: { Double(volume) },
                    set: { volume = Float($0); player.volume = volume }
                ), in: 0...1)
                    .frame(width: 48)
                    .tint(themeManager.isDarkMode ? .white.opacity(0.3) : .black.opacity(0.2))
            }

            // Playlist Toggle
            Button(action: onPlaylistToggle) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
            }
            .buttonStyle(.plain)

            // Mini Player Toggle
            Button(action: onMiniPlayerToggle) {
                Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                    .font(.system(size: 11))
                    .foregroundColor(iconColor)
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
