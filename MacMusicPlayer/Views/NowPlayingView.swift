import SwiftUI

/// Now Playing view with horizontal layout: vinyl record left, lyrics right.
struct NowPlayingView: View {
    let artworkData: Data?
    let lyrics: [LyricLine]
    let currentLineIndex: Int
    var isPlaying: Bool = false
    var showRhythm: Bool = false
    var showPlaylist: Bool = false  // 控制歌词偏移

    /// Observe TimeManager directly so this view's body re-evaluates for
    /// time changes without triggering parent (MainPlayerView) or sibling
    /// (CompactControlBar) re-evaluation.
    @ObservedObject var timeManager = TimeManager.shared

    @ObservedObject var themeManager = ThemeManager.shared

    /// 自动 3D 摆动相位 — 用 SwiftUI .repeatForever 驱动，零额外 CPU
    /// 两个独立相位制造 Lissajous 式旋转，感觉像真实唱片在转盘上微微晃动
    @State private var discTiltPhaseX: Bool = false
    @State private var discTiltPhaseY: Bool = false

    private var tertiaryText: Color { themeManager.isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3) }
    private var placeholderBg: Color { themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }

    var body: some View {
        HStack(spacing: 16) {
            // Left: Vinyl Record + Rhythm
            VStack(spacing: 12) {
                vinylSection
                    .offset(x: 20, y: -10)

                if showRhythm {
                    MusicRhythmView(isPlaying: isPlaying)
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
                }
            }

            // Right: Lyrics
            lyricsSection
                .offset(x: showPlaylist ? -80 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showPlaylist)
        }
        .padding(.leading, 80)
        .padding(.trailing, 40)
        .padding(.vertical, 40)
        .onAppear {
            // Start auto 3D tilt oscillation — no NSTrackingArea needed,
            // no CPU overhead, purely GPU-driven animation.
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                discTiltPhaseX = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.875) {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    discTiltPhaseY = true
                }
            }
        }
    }

    // MARK: - Vinyl Record

    private var vinylSection: some View {
        // Auto-oscillating tilt derived from SwiftUI animation phases.
        // Map: false→-4°, true→+4° for a smooth ±4° sway on each axis.
        let tiltX: Double = (discTiltPhaseX ? 4.0 : -4.0)
        let tiltY: Double = (discTiltPhaseY ? 3.0 : -3.0)
        return ZStack {
            // Outer disc (black vinyl)
            Circle()
                .fill(Color.black)
                .frame(width: 320, height: 320)
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)

            // Vinyl grooves — subtle parallax offset for depth
            ForEach(0..<5) { i in
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    .frame(width: CGFloat(280 - i * 20), height: CGFloat(280 - i * 20))
            }

            // Album art (center disc) — isolated in a TimelineView so only this tiny
            // subview rebuilds each tick, NOT the entire vinylSection ZStack.
            RotatingArtView(artworkData: artworkData, isPlaying: isPlaying)

            // Center hole
            Circle()
                .fill(Color.black)
                .frame(width: 12, height: 12)

            // Center dot
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 4, height: 4)
        }
    }

    private var lyricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Lyrics
            if !lyrics.isEmpty {
                LyricsView(lyrics: lyrics, currentLineIndex: currentLineIndex, currentTime: timeManager.currentTime, isPlaying: isPlaying)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // No lyrics placeholder
                VStack {
                    Spacer()
                    Text("暂无歌词")
                        .font(.system(size: 14))
                        .foregroundColor(tertiaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Disc Rotation (placeholder keeps center alignment)

    private var placeholderCenter: some View {
        Circle()
            .fill(placeholderBg)
            .frame(width: 180, height: 180)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 50))
                    .foregroundColor(tertiaryText)
            )
    }
}

// MARK: - Rotating Art (SwiftUI + Timer)

/// Pure SwiftUI rotating artwork — Timer.publish drives rotationAngle.
/// Isolated as a separate struct with @State, so only this tiny subview's
/// body re-evaluates on each tick — parent vinylSection/NowPlayingView
/// are NOT affected. NSImage is cached via @State to avoid re-decoding
/// the image 60 times per second.
private struct RotatingArtView: View {
    let artworkData: Data?
    let isPlaying: Bool

    @State private var rotationAngle: Double = 0
    @State private var cachedImage: NSImage?
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let img = cachedImage {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 180)
                    .clipShape(Circle())
                    .rotationEffect(.degrees(rotationAngle))
            } else {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 180, height: 180)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 50))
                            .foregroundColor(Color.white.opacity(0.3))
                    )
            }
        }
        .onReceive(timer) { _ in
            guard isPlaying else { return }
            rotationAngle = (rotationAngle + 0.75).truncatingRemainder(dividingBy: 360.0)
        }
        .onChange(of: artworkData) { newData in
            if let data = newData {
                cachedImage = NSImage(data: data)
            } else {
                cachedImage = nil
            }
        }
        .onAppear {
            if let data = artworkData {
                cachedImage = NSImage(data: data)
            }
        }
    }
}

// MARK: - Music Rhythm Animation

class RhythmState: ObservableObject {
    @Published var bars: [CGFloat] = Array(repeating: 6, count: 18)
    var isPlaying = false
    private var timerSource: DispatchSourceTimer?

    func startTimer() {
        stopTimer()
        // Use background queue so the timer doesn't compete with 60fps vinyl rotation
        // on the main queue. Only the @Published update is dispatched to main.
        let source = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        source.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(5))
        source.setEventHandler { [weak self] in
            guard let self = self, self.isPlaying else { return }
            let newBars = (0..<18).map { _ in CGFloat.random(in: 6...48) }
            DispatchQueue.main.async {
                self.bars = newBars
            }
        }
        source.resume()
        timerSource = source
    }

    func stopTimer() {
        timerSource?.cancel()
        timerSource = nil
    }

    deinit {
        stopTimer()
    }
}

struct MusicRhythmView: View {
    var isPlaying: Bool = false
    @StateObject private var state = RhythmState()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<18, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.8), .orange.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: state.bars[i])
                    .animation(.spring(response: 0.12, dampingFraction: 0.55).delay(Double(i) * 0.018), value: state.bars[i])
            }
        }
        .frame(width: 320, height: 50)
        .onAppear {
            state.isPlaying = isPlaying
            if isPlaying {
                state.startTimer()
            }
        }
        .onChange(of: isPlaying) { v in
            state.isPlaying = v
            if v {
                state.startTimer()
            } else {
                state.stopTimer()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    state.bars = Array(repeating: 6, count: 18)
                }
            }
        }
    }
}