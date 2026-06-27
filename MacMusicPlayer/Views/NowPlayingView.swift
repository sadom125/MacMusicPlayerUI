import SwiftUI

/// Now Playing view with horizontal layout: vinyl record left, lyrics right.
struct NowPlayingView: View {
    let artworkData: Data?
    let lyrics: [LyricLine]
    let currentLineIndex: Int
    let currentTime: TimeInterval  // 当前播放时间，用于逐字高亮
    var isPlaying: Bool = false
    var showRhythm: Bool = false
    var showPlaylist: Bool = false  // 控制歌词偏移

    @ObservedObject var themeManager = ThemeManager.shared

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
    }

    // MARK: - Vinyl Record

    private var vinylSection: some View {
        ZStack {
            // Outer disc (black vinyl)
            Circle()
                .fill(Color.black)
                .frame(width: 320, height: 320)
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)

            // Vinyl grooves
            ForEach(0..<5) { i in
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    .frame(width: CGFloat(280 - i * 20), height: CGFloat(280 - i * 20))
            }

            // Album art (center disc, rotating via TimelineView)
            if let data = artworkData, let nsImage = NSImage(data: data) {
                TimelineView(.periodic(from: .now, by: 1.0 / 60.0)) { context in
                    let elapsed = context.date.timeIntervalSinceReferenceDate
                    let angle = isPlaying ? (elapsed.truncatingRemainder(dividingBy: 8.0) / 8.0) * 360.0 : 0

                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 180, height: 180)
                        .clipShape(Circle())
                        .rotationEffect(.degrees(angle))
                }
            } else {
                // Placeholder
                Circle()
                    .fill(placeholderBg)
                    .frame(width: 180, height: 180)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 50))
                            .foregroundColor(tertiaryText)
                    )
            }

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
                LyricsView(lyrics: lyrics, currentLineIndex: currentLineIndex, currentTime: currentTime, isPlaying: isPlaying)
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
}

// MARK: - Music Rhythm Animation

class RhythmState: ObservableObject {
    @Published var bars: [CGFloat] = Array(repeating: 6, count: 18)
    var isPlaying = false
    private static var timerKey = "rhythmTimer"

    func startTimer() {
        stopTimer()
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .milliseconds(110))
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            if self.isPlaying {
                self.bars = (0..<18).map { _ in CGFloat.random(in: 6...42) }
            }
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
            state.startTimer()
        }
        .onChange(of: isPlaying) { v in
            state.isPlaying = v
            if !v {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    state.bars = Array(repeating: 6, count: 18)
                }
            }
        }
    }
}
