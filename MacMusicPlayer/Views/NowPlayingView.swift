import SwiftUI

/// Now Playing view with horizontal layout: vinyl record left, lyrics right.
struct NowPlayingView: View {
    let artworkData: Data?
    var isPlaying: Bool = false
    var showRhythm: Bool = false
    var showPlaylist: Bool = false  // 控制歌词偏移

    @ObservedObject var player: PlayerManager
    @ObservedObject var timeManager = TimeManager.shared
    @ObservedObject var themeManager = ThemeManager.shared

    /// 当前歌词数据 — 在 NowPlayingView 内部管理，不依赖父视图传递
    @State private var displayedLyrics: [LyricLine] = []

    /// 自动 3D 摆动相位 — 用 SwiftUI .repeatForever 驱动，零额外 CPU
    /// 两个独立相位制造 Lissajous 式旋转，感觉像真实唱片在转盘上微微晃动
    @State private var discTiltPhaseX: Bool = false
    @State private var discTiltPhaseY: Bool = false

    /// 当前播放时间对应的歌词行索引 — 用于 LyricsView 定位和高亮。
    private var currentLineIndex: Int {
        let time = timeManager.currentTime
        guard time >= 0, !displayedLyrics.isEmpty else { return -1 }
        // 二分查找最后一个 time <= currentTime 的行
        var lo = 0
        var hi = displayedLyrics.count - 1
        var result = -1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if displayedLyrics[mid].time <= time {
                result = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return result
    }

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
            loadLyrics()
        }
        // 切歌时重新加载歌词（替代之前的 .id() 方案——.id() 会破坏
        // @ObservedObject timeManager 的订阅，导致逐字动画/律动长时间不渲染）
        .onChange(of: player.currentTrack?.id) { _ in
            loadLyrics()
        }
        // 编辑元数据后重新加载歌词
        .onReceive(NotificationCenter.default.publisher(for: .currentTrackMetadataUpdated)) { _ in
            loadLyrics()
        }

    }

    // MARK: - Lyrics Loading

    private func loadLyrics() {
        guard let track = player.currentTrack else {
            displayedLyrics = []
            return
        }

        // 1. Try external .lrc file
        let lrcURL = track.url.deletingPathExtension().appendingPathExtension("lrc")
        if let lrcText = try? String(contentsOf: lrcURL, encoding: .utf8) {
            let parsed = LrcParser.parse(lrcText: lrcText)
            if !parsed.isEmpty {
                displayedLyrics = LrcParser.assignWordsToLines(parsed)
                return
            }
        }

        // 2. Try embedded lyrics
        if let lrcText = track.lyrics, !lrcText.isEmpty {
            let parsed = LrcParser.parse(lrcText: lrcText)
            if !parsed.isEmpty {
                displayedLyrics = LrcParser.assignWordsToLines(parsed)
                return
            }
        }

        // 2b. Synchronous scan — works for FLAC, MP3, M4A, and more
        if let lrcText = MetadataParser.parseLyricsSync(from: track.url), !lrcText.isEmpty {
            let parsed = LrcParser.parse(lrcText: lrcText)
            if !parsed.isEmpty {
                displayedLyrics = LrcParser.assignWordsToLines(parsed)
                return
            }
        }

        // 3. Fallback: show track info
        var fallbackLines: [LyricLine] = []
        fallbackLines.append(LyricLine(time: 0, text: track.title))
        if !track.artist.isEmpty, track.artist != NSLocalizedString("Unknown Artist", comment: "") {
            fallbackLines.append(LyricLine(time: 0, text: track.artist))
        }
        if !track.album.isEmpty, track.album != NSLocalizedString("Unknown Album", comment: "") {
            fallbackLines.append(LyricLine(time: 0, text: track.album))
        }
        if fallbackLines.isEmpty {
            fallbackLines.append(LyricLine(time: 0, text: track.title))
        }
        displayedLyrics = fallbackLines
    }

    // MARK: - Vinyl Record

    private var vinylSection: some View {
        ZStack {
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
            if !displayedLyrics.isEmpty {
                LyricsView(lyrics: displayedLyrics, currentLineIndex: currentLineIndex, currentTime: timeManager.currentTime, isPlaying: isPlaying)
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
    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

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