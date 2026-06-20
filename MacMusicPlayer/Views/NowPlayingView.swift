import SwiftUI

/// Now Playing view with horizontal layout: vinyl record left, lyrics right.
struct NowPlayingView: View {
    let artworkData: Data?
    let lyrics: [LyricLine]
    let currentLineIndex: Int
    var isPlaying: Bool = false

    @ObservedObject var themeManager = ThemeManager.shared
    @State private var rotationAngle: Double = 0
    @State private var rotationTimer: Timer?

    private var tertiaryText: Color { themeManager.isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3) }
    private var placeholderBg: Color { themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }

    var body: some View {
        HStack(spacing: 24) {
            // Left: Vinyl Record
            vinylSection

            // Right: Lyrics
            lyricsSection
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .onAppear { updateRotation() }
        .onChange(of: isPlaying) { _ in updateRotation() }
        .onDisappear { stopRotation() }
    }

    // MARK: - Vinyl Record

    private var vinylSection: some View {
        ZStack {
            // Outer disc (black vinyl)
            Circle()
                .fill(Color.black)
                .frame(width: 320, height: 320)
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)

            // Vinyl grooves
            ForEach(0..<5) { i in
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    .frame(width: CGFloat(280 - i * 20), height: CGFloat(280 - i * 20))
            }

            // Album art (center disc, rotating)
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 180)
                    .clipShape(Circle())
                    .rotationEffect(.degrees(rotationAngle))
            } else {
                // Placeholder
                Circle()
                    .fill(placeholderBg)
                    .frame(width: 180, height: 180)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 50))
                            .foregroundColor(tertiaryText)
                    )
            }

            // Center hole
            Circle()
                .fill(Color.black)
                .frame(width: 12, height: 12)

            // Center dot
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 4, height: 4)
        }
    }

    // MARK: - Rotation Control

    private func updateRotation() {
        if isPlaying {
            startRotation()
        } else {
            stopRotation()
        }
    }

    private func startRotation() {
        rotationTimer?.invalidate()
        // 8 seconds per full rotation, ~0.05° per frame at 60fps
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            rotationAngle += 360.0 / (8.0 * 60.0)  // 0.75° per tick
        }
    }

    private func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
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
