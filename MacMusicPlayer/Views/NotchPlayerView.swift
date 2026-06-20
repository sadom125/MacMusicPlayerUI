import SwiftUI

/// Dynamic Island style music controls — collapsed black pill + expanded panel.
struct NotchPlayerView: View {
    @ObservedObject var player: PlayerManager
    @State private var isExpanded = false

    private var artworkData: Data? {
        if let data = player.currentTrack?.albumArtData { return data }
        guard let url = player.currentTrack?.url else { return nil }
        return MetadataParser.parseArtworkDirect(from: url)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isExpanded {
                expandedView
            } else {
                collapsedView
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
        .onTapGesture {
            withAnimation {
                isExpanded.toggle()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NotchPlayerExpandChanged"),
                    object: nil,
                    userInfo: ["expanded": isExpanded]
                )
            }
        }
    }

    // MARK: - Collapsed (black pill covering notch, album art on left)

    private var collapsedView: some View {
        HStack(spacing: 0) {
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
        )
    }

    // MARK: - Expanded (full player info)

    private var expandedView: some View {
        HStack(spacing: 14) {
            // Album art
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.4))
                    )
            }

            // Track info
            VStack(alignment: .leading, spacing: 3) {
                Text(player.currentTrack?.title ?? "Not Playing")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(player.currentTrack?.artist ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Controls
            HStack(spacing: 20) {
                Button(action: { player.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button(action: { player.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(width: 460, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black)
        )
    }
}
