import SwiftUI

/// Full-width top bar with notch hidden — Dynamic Island style.
struct NotchPlayerView: View {
    @ObservedObject var player: PlayerManager
    @Binding var isExpanded: Bool

    private var artworkData: Data? {
        if let data = player.currentTrack?.albumArtData { return data }
        guard let url = player.currentTrack?.url else { return nil }
        return MetadataParser.parseArtworkDirect(from: url)
    }

    var body: some View {
        GeometryReader { geo in
            if isExpanded {
                expandedContent(width: geo.size.width, height: geo.size.height)
            } else {
                collapsedContent(width: geo.size.width, height: geo.size.height)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
    }

    // MARK: - Collapsed: full-width black bar, music icon left, equalizer right

    private func collapsedContent(width: CGFloat, height: CGFloat) -> some View {
        HStack {
            // Left: music icon
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Right: equalizer bars
            EqualizerView()
        }
        .padding(.horizontal, 16)
        .frame(width: width, height: height)
        .background(Color.black)
    }

    // MARK: - Expanded: drops down from top

    private func expandedContent(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Top bar (connector)
            HStack {
                if let data = artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                EqualizerView()
            }
            .padding(.horizontal, 16)
            .frame(height: 34)

            // Expanded content
            HStack(spacing: 16) {
                // Album art
                if let data = artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 64, height: 64)
                        .overlay(Image(systemName: "music.note").font(.system(size: 24)).foregroundColor(.white.opacity(0.4)))
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.currentTrack?.title ?? "Not Playing")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(player.currentTrack?.artist ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.2)).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.8))
                            .frame(width: geo.size.width * progressRatio, height: 4)
                    }
                }
                .frame(height: 4)
                HStack {
                    Text(formatTime(player.currentTime)).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text(formatTime(player.duration)).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Controls
            HStack(spacing: 36) {
                Button(action: { player.playPrevious() }) {
                    Image(systemName: "backward.fill").font(.system(size: 18)).foregroundColor(.white.opacity(0.8))
                }.buttonStyle(.plain)

                Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28)).foregroundColor(.white)
                }.buttonStyle(.plain)

                Button(action: { player.playNext() }) {
                    Image(systemName: "forward.fill").font(.system(size: 18)).foregroundColor(.white.opacity(0.8))
                }.buttonStyle(.plain)
            }
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .frame(width: width, height: height)
        .background(Color.black)
    }

    // MARK: - Helpers

    private var progressRatio: CGFloat {
        guard player.duration > 0 else { return 0 }
        return CGFloat(min(player.currentTime / player.duration, 1))
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

// MARK: - Equalizer (3 bars animation)

struct EqualizerView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 3, height: animating ? CGFloat.random(in: 5...14) : 4)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.12),
                        value: animating
                    )
            }
        }
        .frame(height: 16)
        .onAppear { animating = true }
    }
}
