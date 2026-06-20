import SwiftUI

/// Notch area overlay — click to expand, click again to collapse.
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
        .onTapGesture {
            if let panel = NSApp.windows.first(where: { $0 is NotchPlayerWindow }) as? NotchPlayerWindow {
                panel.toggleExpanded()
            }
        }
    }

    // MARK: - Collapsed: covers only the notch

    private func collapsedContent(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Left: music icon
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            // Right: equalizer
            EqualizerView()
        }
        .padding(.horizontal, 14)
        .frame(width: width, height: height)
        .background(
            NotchCoverShape()
                .fill(Color.black)
        )
    }

    // MARK: - Expanded: wider panel dropping down

    private func expandedContent(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Top connector (same as collapsed)
            HStack(spacing: 0) {
                if let data = artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                EqualizerView()
            }
            .padding(.horizontal, 14)
            .frame(height: 36)

            // Album art + info
            HStack(spacing: 14) {
                if let data = artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .overlay(Image(systemName: "music.note").font(.system(size: 22)).foregroundColor(.white.opacity(0.4)))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(player.currentTrack?.title ?? "Not Playing")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(player.currentTrack?.artist ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)

            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.2)).frame(height: 3)
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.8))
                            .frame(width: geo.size.width * progressRatio, height: 3)
                    }
                }
                .frame(height: 3)
                HStack {
                    Text(formatTime(player.currentTime)).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text(formatTime(player.duration)).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            // Controls
            HStack(spacing: 32) {
                Button(action: { player.playPrevious() }) {
                    Image(systemName: "backward.fill").font(.system(size: 18)).foregroundColor(.white.opacity(0.8))
                }.buttonStyle(.plain)

                Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26)).foregroundColor(.white)
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

// MARK: - Notch Cover Shape (matches hardware notch)

struct NotchCoverShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 16

        // Top edge — flat
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // Right side — round bottom-right
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                    radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: true)

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                    radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: true)

        // Left side — round top-left
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Equalizer Animation

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
