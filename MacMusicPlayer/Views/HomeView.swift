import SwiftUI

/// Home overview page showing library stats and favorites.
struct HomeView: View {
    @ObservedObject var player: PlayerManager
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @State private var isFavoritesExpanded: Bool = true

    private var primaryText: Color { themeManager.isDarkMode ? .white : .black }
    private var secondaryText: Color { themeManager.isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.6) }
    private var tertiaryText: Color { themeManager.isDarkMode ? Color.white.opacity(0.35) : Color.black.opacity(0.35) }
    private var iconColor: Color { themeManager.isDarkMode ? Color.white.opacity(0.5) : Color.black.opacity(0.5) }
    private var cardBg: Color { themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05) }
    private var rowBg: Color { themeManager.isDarkMode ? Color.white.opacity(0.02) : Color.black.opacity(0.03) }

    private var favoriteTracks: [Track] {
        favoritesManager.getFavoriteTracks(from: player.playlist)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                headerSection

                // Library Stats
                statsSection

                // Listening Heatmap
                ListeningHeatmap()

                // Favorites Section (collapsible)
                favoritesSection

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .id(themeManager.isDarkMode) // Force view rebuild on theme change
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("首页")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(primaryText)

            Text("\(player.playlist.count) 首歌曲")
                .font(.system(size: 14))
                .foregroundColor(secondaryText)
        }
    }

    private var statsSection: some View {
        HStack(spacing: 20) {
            StatCard(
                title: "歌曲总数",
                value: "\(player.playlist.count)",
                icon: "music.note.list"
            )

            StatCard(
                title: "当前播放",
                value: player.currentTrack?.title ?? "无",
                icon: "play.circle.fill"
            )
        }
    }

    // MARK: - Favorites Section (Collapsible)

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header button — tap to collapse/expand
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isFavoritesExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Text("我的收藏")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(primaryText)

                    Text("\(favoriteTracks.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(tertiaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(rowBg)
                        )

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(iconColor)
                        .rotationEffect(.degrees(isFavoritesExpanded ? 0 : -90))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFavoritesExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Content — collapsible
            if isFavoritesExpanded {
                if favoritesManager.count == 0 || favoriteTracks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "star")
                            .font(.system(size: 32))
                            .foregroundColor(tertiaryText)
                        Text("还没有收藏的歌曲")
                            .font(.system(size: 14))
                            .foregroundColor(tertiaryText)
                        Text("点击播放控制栏的星标即可收藏")
                            .font(.system(size: 12))
                            .foregroundColor(tertiaryText.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(rowBg)
                    )
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(favoriteTracks.enumerated()), id: \.element.id) { index, track in
                            Button(action: {
                                if let trackIndex = player.playlist.firstIndex(where: { $0.id == track.id }) {
                                    player.playTrack(at: trackIndex)
                                }
                            }) {
                                FavoriteTrackRow(
                                    track: track,
                                    index: index + 1,
                                    isFavorite: true,
                                    themeManager: themeManager,
                                    onToggleFavorite: {
                                        favoritesManager.toggle(track)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

/// Stat card for displaying library statistics.
private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    @ObservedObject var themeManager = ThemeManager.shared

    private var primaryText: Color { themeManager.isDarkMode ? .white : .black }
    private var secondaryText: Color { themeManager.isDarkMode ? Color.white.opacity(0.4) : Color.black.opacity(0.4) }
    private var iconColor: Color { themeManager.isDarkMode ? Color.white.opacity(0.5) : Color.black.opacity(0.5) }
    private var cardBg: Color { themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                Spacer()
            }

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(primaryText)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBg)
        )
    }
}

/// Track row for favorites — includes a star button to unfavorite.
private struct FavoriteTrackRow: View {
    let track: Track
    let index: Int
    let isFavorite: Bool
    var themeManager: ThemeManager
    var onToggleFavorite: (() -> Void)?

    private var primaryText: Color { themeManager.isDarkMode ? Color.white.opacity(0.8) : Color.black.opacity(0.8) }
    private var secondaryText: Color { themeManager.isDarkMode ? Color.white.opacity(0.4) : Color.black.opacity(0.4) }
    private var tertiaryText: Color { themeManager.isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3) }
    private var rowBg: Color { themeManager.isDarkMode ? Color.white.opacity(0.02) : Color.black.opacity(0.03) }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(tertiaryText)
                .frame(width: 24, alignment: .trailing)

            // Album art thumbnail
            if let data = track.albumArtData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.low)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 14))
                    .foregroundColor(primaryText)
                    .lineLimit(1)

                if !track.artist.isEmpty {
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundColor(secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Unfavorite button
            Button(action: { onToggleFavorite?() }) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.yellow)
            }
            .buttonStyle(.plain)
            .help("取消收藏")

            Text(track.duration.formatDuration)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(tertiaryText)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowBg)
        )
    }
}
