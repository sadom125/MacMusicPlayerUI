import SwiftUI

/// Dynamic Island style — covers the notch, hover/click to expand.
struct NotchPlayerView: View {
    @ObservedObject var player: PlayerManager
    @Binding var isExpanded: Bool

    private var artworkData: Data? {
        if let data = player.currentTrack?.albumArtData { return data }
        guard let url = player.currentTrack?.url else { return nil }
        return MetadataParser.parseArtworkDirect(from: url)
    }

    var body: some View {
        if isExpanded {
            expandedView
                .transition(.scale(scale: 0.95, anchor: .top).combined(with: .opacity))
        } else {
            collapsedView
                .transition(.scale(scale: 0.95, anchor: .top).combined(with: .opacity))
        }
    }

    // MARK: - Collapsed

    private var collapsedView: some View {
        HStack(spacing: 0) {
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            MusicWaveView()
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(
            NotchShape(topRadius: 10, bottomRadius: 18)
                .fill(Color.black)
        )
    }

    // MARK: - Expanded

    private var expandedView: some View {
        VStack(spacing: 0) {
            // Top connector bar
            HStack(spacing: 0) {
                if let data = artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
                MusicWaveView()
            }
            .padding(.horizontal, 16)
            .frame(height: 30)

            // Album art + info
            HStack(spacing: 16) {
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
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.4))
                        )
                }

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
            .padding(.top, 10)

            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.8))
                            .frame(width: geo.size.width * progressRatio, height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text(formatTime(player.currentTime))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text(formatTime(player.duration))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Controls
            HStack(spacing: 32) {
                Button(action: { player.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button(action: { player.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .background(
            NotchShape(topRadius: 0, bottomRadius: 24)
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
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Music Wave Animation

struct MusicWaveView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 2, height: animating ? CGFloat.random(in: 4...12) : 3)
                    .animation(
                        .easeInOut(duration: 0.35)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.08),
                        value: animating
                    )
            }
        }
        .frame(height: 14)
        .onAppear { animating = true }
    }
}

// MARK: - Notch Shape

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addArc(center: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY - bottomRadius),
                    radius: bottomRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY - bottomRadius),
                    radius: bottomRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topRadius))
        if topRadius > 0 {
            path.addArc(center: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius),
                        radius: topRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: true)
        }
        path.closeSubpath()
        return path
    }
}
