import SwiftUI

/// Home overview page showing library stats and recent tracks.
struct HomeView: View {
    @ObservedObject var player: PlayerManager
    @ObservedObject var themeManager = ThemeManager.shared

    private var primaryText: Color { themeManager.isDarkMode ? .white : .black }
    private var secondaryText: Color { themeManager.isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.6) }
    private var tertiaryText: Color { themeManager.isDarkMode ? Color.white.opacity(0.35) : Color.black.opacity(0.35) }
    private var iconColor: Color { themeManager.isDarkMode ? Color.white.opacity(0.5) : Color.black.opacity(0.5) }
    private var cardBg: Color { themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05) }
    private var rowBg: Color { themeManager.isDarkMode ? Color.white.opacity(0.02) : Color.black.opacity(0.03) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                headerSection

                // Library Stats
                statsSection

                // Listening Heatmap
                ListeningHeatmap()

                // Recent Tracks
                recentTracksSection

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

    private var recentTracksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近播放")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(primaryText)

            if player.playlist.isEmpty {
                Text("暂无歌曲")
                    .font(.system(size: 14))
                    .foregroundColor(tertiaryText)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(player.playlist.prefix(10).enumerated()), id: \.element.id) { index, track in
                        TrackRow(track: track, index: index + 1, themeManager: themeManager)
                    }
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

/// Track row for displaying in lists.
private struct TrackRow: View {
    let track: Track
    let index: Int
    var themeManager: ThemeManager = ThemeManager.shared

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

            Text(formatDuration(track.duration))
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

    private func formatDuration(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
