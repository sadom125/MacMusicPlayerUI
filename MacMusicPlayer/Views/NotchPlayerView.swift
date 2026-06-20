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

    private var primaryText: Color { .white }
    private var iconColor: Color { .white.opacity(0.8) }

    var body: some View {
        HStack(spacing: 12) {
            // Mini album disc
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 28, height: 28)
                if let data = artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 3, height: 3)
            }

            // Track info
            Text(player.currentTrack?.title ?? "Not Playing")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(primaryText)
                .lineLimit(1)

            Spacer(minLength: 4)

            // Previous
            Button(action: { player.playPrevious() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            // Play/Pause
            Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundColor(primaryText)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            // Next
            Button(action: { player.playNext() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .onTapGesture {
            // Open main player when tapped
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.showMainWindow()
            }
        }
    }
}
