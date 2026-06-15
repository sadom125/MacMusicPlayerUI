import SwiftUI

/// Mini floating player view — compact, always-on-top
struct MiniPlayerView: View {
    @ObservedObject var player: PlayerManager

    var body: some View {
        VStack(spacing: 0) {
            // Header: thumb + info
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.tnAccent.opacity(0.08),
                                    Color.tnPurple.opacity(0.04)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Text("🎵")
                        .font(.system(size: 18))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.03), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(player.currentTrack?.title ?? NSLocalizedString("No track", comment: ""))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                    Text(player.currentTrack?.artist ?? "")
                        .font(.system(size: 11))
                        .foregroundColor(Color.tnAccent)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Lyric line
            Text(player.currentTrack?.title ?? "")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            // Thin progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.03))
                        .frame(height: 2)
                    Rectangle()
                        .fill(Color.tnAccent.opacity(0.4))
                        .frame(width: geo.size.width * CGFloat(player.duration > 0 ? min(player.currentTime / player.duration, 1) : 0), height: 2)
                }
            }
            .frame(height: 2)

            // Controls
            HStack(spacing: 14) {
                Button(action: { player.playPrevious() }) {
                    Text("⏮")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                    Text(player.isPlaying ? "⏸" : "▶")
                        .font(.system(size: 16))
                        .foregroundColor(Color.tnAccent)
                        .frame(width: 36, height: 36)
                        .background(Color.tnAccent.opacity(0.06))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.tnAccent.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: { player.playNext() }) {
                    Text("⏭")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
        .background(
            Color.black.opacity(0.85)
        )
        .background(
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
        .frame(width: 270)
    }
}

/// Bridge NSVisualEffectView for SwiftUI
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
