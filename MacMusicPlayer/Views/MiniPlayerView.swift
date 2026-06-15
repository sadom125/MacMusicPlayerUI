import SwiftUI

/// Mini floating player view — compact, always-on-top
struct MiniPlayerView: View {
    @ObservedObject var player: PlayerManager
    @State private var cachedLyrics: [LyricLine] = []
    @State private var cachedTrackID: UUID? = nil

    /// Current active lyric line for display
    private var currentLyricText: String {
        guard !cachedLyrics.isEmpty, let track = player.currentTrack else {
            return player.currentTrack?.title ?? ""
        }
        let time = player.currentTime
        var lineText = track.title
        for i in 0..<cachedLyrics.count {
            if cachedLyrics[i].time <= time {
                lineText = cachedLyrics[i].text
            }
        }
        return lineText
    }

    /// Album art data with sync fallback
    private var artworkData: Data? {
        if let data = player.currentTrack?.albumArtData { return data }
        guard let url = player.currentTrack?.url else { return nil }
        return MetadataParser.parseArtworkDirect(from: url)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top section: album art + info
            HStack(spacing: 10) {
                // Album art thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.031, green: 0.031, blue: 0.055))
                        .frame(width: 40, height: 40)

                    if let data = artworkData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipped()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

                // Track info
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.currentTrack?.title ?? "No track")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                    Text(player.currentTrack?.artist ?? "")
                        .font(.system(size: 11))
                        .foregroundColor(Color.tnAccent)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Return to full player button
                Button(action: returnToFullPlayer) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Return to full player")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Current lyric line
            Text(currentLyricText)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                        .frame(
                            width: geo.size.width * progressRatio,
                            height: 2
                        )
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
        .frame(width: 300)
        .onTapGesture(count: 2) {
            returnToFullPlayer()
        }
        .onAppear {
            loadLyricsForCurrentTrack()
        }
        .onChange(of: player.currentTrack?.id) { _ in
            loadLyricsForCurrentTrack()
        }
    }

    // MARK: - Helpers

    private func loadLyricsForCurrentTrack() {
        guard let track = player.currentTrack else {
            cachedLyrics = []
            cachedTrackID = nil
            return
        }
        // Try Track model, then direct scan
        if let lrcText = track.lyrics ?? MetadataParser.parseLyricsDirect(from: track.url),
           !lrcText.isEmpty {
            cachedLyrics = LrcParser.parse(lrcText: lrcText)
        } else {
            cachedLyrics = []
        }
        cachedTrackID = track.id
    }

    private var progressRatio: CGFloat {
        guard player.duration > 0 else { return 0 }
        return CGFloat(min(player.currentTime / player.duration, 1))
    }

    private func returnToFullPlayer() {
        // Close mini player
        NSApplication.shared.windows
            .first(where: { $0 is MiniPlayerWindow })?
            .close()
        // Show full player
        (NSApplication.shared.delegate as? AppDelegate)?.showMainWindow()
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
