import SwiftUI

/// Notch area overlay — matches DynamicLakePro design.
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
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
        .onTapGesture {
            if let panel = NSApp.windows.first(where: { $0 is NotchPlayerWindow }) as? NotchPlayerWindow {
                panel.toggleExpanded()
            }
        }
    }

    // MARK: - Collapsed

    private func collapsedContent(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
            }

            Spacer()

            if player.isPlaying {
                EqualizerView()
            }
        }
        .padding(.horizontal, 16)
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
                .padding(.vertical, 0)
        )
        .clipped()
    }

    // MARK: - Expanded

    private func expandedContent(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Content area
            HStack(spacing: 14) {
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
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.3))
                        )
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.currentTrack?.title ?? "Not Playing")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(player.currentTrack?.artist ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                if player.isPlaying {
                    EqualizerView()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)

            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.7))
                            .frame(width: geo.size.width * progressRatio, height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text(formatTime(player.currentTime))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text(formatTime(player.duration))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)

            // Controls
            HStack(spacing: 36) {
                Button(action: { player.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button(action: { player.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .frame(width: width, height: height)
        .background(
            NotchExpandedBg(radius: 20)
                .fill(Color.black)
        )
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

// MARK: - Equalizer Animation

struct EqualizerView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 3, height: animating ? CGFloat.random(in: 5...14) : 4)
                    .animation(
                        .easeInOut(duration: 0.35)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.08),
                        value: animating
                    )
            }
        }
        .frame(height: 16)
        .onAppear { animating = true }
    }
}

// MARK: - Bottom-Only Rounded Rectangle

struct NotchExpandedBg: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: true)
        path.closeSubpath()
        return path
    }
}
