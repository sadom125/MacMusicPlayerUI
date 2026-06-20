import SwiftUI

/// Notch area overlay — click to expand.
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
        .animation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0), value: isExpanded)
        .contentShape(Rectangle())
        .onTapGesture {
            if let panel = NSApp.windows.first(where: { $0 is NotchPlayerWindow }) as? NotchPlayerWindow {
                panel.toggleExpanded()
            }
        }
    }

    // MARK: - Collapsed

    private func collapsedContent(width: CGFloat, height: CGFloat) -> some View {
        HStack {
            Spacer()
            EqualizerView()
            Spacer()
        }
        .frame(width: width, height: height)
        .background(
            NotchBarShape()
                .fill(Color.black)
                .edgesIgnoringSafeArea(.all)
        )
    }

    // MARK: - Expanded

    private func expandedContent(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                if let data = artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.3))
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(player.currentTrack?.title ?? "Not Playing")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(player.currentTrack?.artist ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                EqualizerView()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            VStack(spacing: 5) {
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
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text(formatTime(player.duration))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            HStack(spacing: 40) {
                Button(action: { player.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button(action: { player.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .frame(width: width, height: height)
        .background(
            NotchExpandedBg(radius: 22)
                .fill(Color.black)
                .edgesIgnoringSafeArea(.all)
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
    @State private var animate = false

    var body: some View {
        HStack(spacing: 2.5) {
            BarView(delay: 0.0, animate: $animate)
            BarView(delay: 0.1, animate: $animate)
            BarView(delay: 0.2, animate: $animate)
            BarView(delay: 0.15, animate: $animate)
        }
        .frame(height: 16)
        .onAppear { animate = true }
    }
}

struct BarView: View {
    let delay: Double
    @Binding var animate: Bool
    @State private var height: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white)
            .frame(width: 3, height: height)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.35)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    height = CGFloat.random(in: 6...14)
                }
            }
    }
}

// MARK: - Notch Bar Shape (flat top, rounded bottom)

struct NotchBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 10

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                    radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                    radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
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
                    radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
    }
}
