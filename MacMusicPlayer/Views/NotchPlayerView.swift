import SwiftUI

/// Notch area overlay — click to expand.
struct NotchPlayerView: View {
    @ObservedObject var player: PlayerManager
    @Binding var isExpanded: Bool
    @State private var isHovering = false
    @State private var cachedArtwork: NSImage?

    private var artworkImage: NSImage? {
        if let cached = cachedArtwork { return cached }
        if let data = player.currentTrack?.albumArtData, let img = NSImage(data: data) {
            cachedArtwork = img
            return img
        }
        guard let url = player.currentTrack?.url else { return nil }
        if let data = MetadataParser.parseArtworkDirect(from: url), let img = NSImage(data: data) {
            cachedArtwork = img
            return img
        }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 折叠状态
                collapsedContent(width: geo.size.width, height: geo.size.height)
                    .shadow(color: .white.opacity(isHovering && !isExpanded ? 0.25 : 0), radius: isHovering && !isExpanded ? 10 : 0)
                    .opacity(isExpanded ? 0 : 1)

                // 展开状态
                expandedContent(width: geo.size.width, height: geo.size.height)
                    .opacity(isExpanded ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
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
            EqualizerView(isPlaying: player.isPlaying)
            Spacer()
        }
        .frame(width: width, height: height)
        .background(
            NotchBarShape()
                .fill(Color.black)
        )
    }

    // MARK: - Expanded

    private func expandedContent(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let img = artworkImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.3))
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTrack?.title ?? "Not Playing")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(player.currentTrack?.artist ?? "")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                EqualizerView(isPlaying: player.isPlaying)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.white.opacity(0.7))
                            .frame(width: geo.size.width * progressRatio, height: 3)
                    }
                }
                .frame(height: 3)

                HStack {
                    Text(formatTime(player.currentTime))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text(formatTime(player.duration))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            HStack(spacing: 28) {
                Button(action: { player.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
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
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .frame(width: width, height: height)
        .background(
            NotchExpandedBg(radius: 16)
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

// MARK: - Equalizer Animation (Wave-based, fluid)

class EqualizerState: ObservableObject {
    @Published var bars: [CGFloat] = [4, 4, 4, 4]
    var isPlaying = false
    private var tick: Double = 0
    private static var timerKey = "equalizerTimer"

    func startTimer() {
        stopTimer()
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .milliseconds(100))
        source.setEventHandler { [weak self] in
            guard let self = self, self.isPlaying else { return }
            self.tick += 0.1
            // 双正弦波叠加 + 有机噪声，模拟真实音乐跳动
            let newBars = (0..<4).map { i in
                let phase = self.tick + Double(i) * 0.7
                let wave1 = sin(phase * 3.0) * 0.4
                let wave2 = sin(phase * 1.8 + 1.2) * 0.3
                let noise = Double.random(in: -0.1...0.1)
                let combined = 0.5 + wave1 + wave2 + noise
                let h = 4 + combined * 10
                return CGFloat(max(3, min(16, h)))
            }
            self.bars = newBars
        }
        objc_setAssociatedObject(self, &Self.timerKey, source, .OBJC_ASSOCIATION_RETAIN)
        source.resume()
    }

    func stopTimer() {
        if let source = objc_getAssociatedObject(self, &Self.timerKey) as? DispatchSourceTimer {
            source.cancel()
        }
        objc_setAssociatedObject(self, &Self.timerKey, nil, .OBJC_ASSOCIATION_RETAIN)
    }
}

struct EqualizerView: View {
    var isPlaying: Bool = true
    @StateObject private var state = EqualizerState()

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 3, height: state.bars[i])
                    .animation(
                        .spring(response: 0.12, dampingFraction: 0.55)
                            .delay(Double(i) * 0.04),
                        value: state.bars[i]
                    )
            }
        }
        .frame(height: 16)
        .onAppear {
            state.isPlaying = isPlaying
            state.startTimer()
        }
        .onDisappear {
            state.stopTimer()
        }
        .onChange(of: isPlaying) { v in
            state.isPlaying = v
            if !v {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    state.bars = [4, 4, 4, 4]
                }
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
