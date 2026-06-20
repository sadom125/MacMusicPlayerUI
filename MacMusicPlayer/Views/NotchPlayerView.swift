import SwiftUI

/// Compact music controls displayed at the MacBook notch area (Dynamic Island style).
struct NotchPlayerView: View {
    @ObservedObject var player: PlayerManager
    @ObservedObject var themeManager = ThemeManager.shared

    private var artworkData: Data? {
        if let data = player.currentTrack?.albumArtData { return data }
        guard let url = player.currentTrack?.url else { return nil }
        return MetadataParser.parseArtworkDirect(from: url)
    }

    private var primaryText: Color { themeManager.isDarkMode ? .white.opacity(0.9) : .black.opacity(0.85) }
    private var secondaryText: Color { themeManager.isDarkMode ? .white.opacity(0.45) : .black.opacity(0.45) }
    private var iconColor: Color { themeManager.isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6) }

    var body: some View {
        HStack(spacing: 10) {
            // Mini album disc
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 26, height: 26)
                if let data = artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.4))
                        )
                }
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 2, height: 2)
            }

            // Track info
            Text(player.currentTrack?.title ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(primaryText)
                .lineLimit(1)

            // Controls
            HStack(spacing: 12) {
                Button(action: { player.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 10))
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)

                Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundColor(primaryText)
                }
                .buttonStyle(.plain)

                Button(action: { player.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 10))
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 17)
                .fill(.ultraThinMaterial)
                .opacity(0.85)
        )
    }
}
