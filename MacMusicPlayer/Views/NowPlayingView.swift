import SwiftUI

/// Now Playing view with horizontal layout: album art left, lyrics right.
struct NowPlayingView: View {
    let artworkData: Data?
    let lyrics: [LyricLine]
    let currentLineIndex: Int

    @ObservedObject var themeManager = ThemeManager.shared

    private var tertiaryText: Color { themeManager.isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3) }
    private var placeholderBg: Color { themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }

    var body: some View {
        HStack(spacing: 40) {
            // Left: Album Art
            albumArtSection

            // Right: Lyrics
            lyricsSection
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
    }

    private var albumArtSection: some View {
        Group {
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 320, height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(placeholderBg)
                    .frame(width: 320, height: 320)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(tertiaryText)
                    )
            }
        }
    }

    private var lyricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Lyrics
            if !lyrics.isEmpty {
                LyricsView(lyrics: lyrics, currentLineIndex: currentLineIndex)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // No lyrics placeholder
                VStack {
                    Spacer()
                    Text("暂无歌词")
                        .font(.system(size: 14))
                        .foregroundColor(tertiaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
