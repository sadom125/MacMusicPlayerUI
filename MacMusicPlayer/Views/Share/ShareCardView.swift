import SwiftUI

/// A styled card view rendered off-screen for generating share images.
/// Layout: album art (left) + song info (right) + lyrics (center) + branding (bottom).
struct ShareCardView: View {
    let title: String
    let artist: String
    let album: String
    let artworkData: Data?
    let lyricsText: String    // current visible lyric line(s)

    /// Card dimensions for the generated image.
    static let cardWidth: CGFloat = 600
    static let cardHeight: CGFloat = 380

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Dark gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.12, green: 0.12, blue: 0.18)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle noise-like overlay (radial gradient glow)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.2, blue: 0.3).opacity(0.3),
                    Color.clear
                ]),
                center: .topTrailing,
                startRadius: 0,
                endRadius: 400
            )

            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Top section: Artwork + Info
                HStack(spacing: 20) {
                    // Album art (circular)
                    albumArtView
                        .frame(width: 120, height: 120)

                    // Song info
                    VStack(alignment: .leading, spacing: 6) {
                        // Song title
                        Text(title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        // Artist
                        if !artist.isEmpty {
                            Text(artist)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }

                        // Album
                        if !album.isEmpty {
                            Text(album)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.45))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)

                Spacer(minLength: 0)

                // Center: Lyrics section
                if !lyricsText.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        // Decorative quote mark
                        Text("\u{201C}")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(Color(red: 0.38, green: 0.69, blue: 1.0).opacity(0.5))
                            .padding(.leading, 28)
                            .padding(.bottom, -8)

                        Text(lyricsText)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.white.opacity(0.92))
                            .lineSpacing(6)
                            .lineLimit(3)
                            .padding(.horizontal, 28)
                    }
                }

                Spacer(minLength: 0)

                // Bottom: Branding
                HStack {
                    Spacer()
                    Text("MacMusicPlayer")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                        .tracking(2)
                    Spacer()
                }
                .padding(.bottom, 20)
            }
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Album Art

    @ViewBuilder
    private var albumArtView: some View {
        if let data = artworkData, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        } else {
            // Placeholder when no artwork
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.22))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                )
        }
    }
}

/// A row in a share-sheet context menu for popover display.
struct ShareOptionRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14))
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
