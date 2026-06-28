import SwiftUI

/// Centered lyrics display — no 3D transforms, no compositing layers.
/// Depth achieved purely with font size + opacity for maximum performance.
/// Word-level highlighting on the active line when timestamps are available.
struct LyricsView: View {
    let lyrics: [LyricLine]
    let currentLineIndex: Int
    let currentTime: TimeInterval
    var isPlaying: Bool = false

    @ObservedObject var themeManager = ThemeManager.shared
    /// Track last scroll index to detect large jumps (skip animation)
    @State private var lastScrollLineIndex: Int = -1

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    Color.clear.frame(height: 100)

                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        LyricLineView(
                            line: line,
                            isActive: index == currentLineIndex,
                            isNear: currentLineIndex >= 0 && abs(index - currentLineIndex) <= 2,
                            currentTime: index == currentLineIndex ? currentTime : -1,
                            isPlaying: isPlaying,
                            isDarkMode: themeManager.isDarkMode
                        )
                        .equatable()
                        .id(index)
                        .frame(maxWidth: .infinity)
                    }

                    Color.clear.frame(height: 100)
                }
            }
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.08),
                        .init(color: .black, location: 0.85),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // Scroll to initial position when view first appears (safety net for
            // track changes where .onChange doesn't fire for the initial value).
            .onAppear {
                if currentLineIndex >= 0 {
                    lastScrollLineIndex = currentLineIndex
                    proxy.scrollTo(currentLineIndex, anchor: .center)
                }
            }
            .onChange(of: currentLineIndex) { newIndex in
                guard newIndex >= 0 else { return }
                let prev = lastScrollLineIndex >= 0 ? lastScrollLineIndex : newIndex
                lastScrollLineIndex = newIndex

                // Only animate small jumps (< 3 lines). Large jumps (track change,
                // manual seek) scroll immediately to avoid long animation churn.
                if abs(newIndex - prev) <= 3 {
                    withAnimation(.easeOut(duration: 0.08)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                } else {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}

/// Individual lyric line — no 3D transforms, no extra compositing layers.
/// Uses font size + opacity for depth. Receives isDarkMode directly instead
/// of observing ThemeManager (avoids per-line ObservableObject subscription).
struct LyricLineView: View, Equatable {
    let line: LyricLine
    let isActive: Bool
    let isNear: Bool
    let currentTime: TimeInterval
    var isPlaying: Bool = false
    let isDarkMode: Bool

    /// When paused, return the "display" time for the current line (last word time)
    private var displayTime: TimeInterval {
        guard currentTime >= 0 else { return -1 }
        return isPlaying ? currentTime : (line.words.last?.time ?? currentTime)
    }

    static func == (lhs: LyricLineView, rhs: LyricLineView) -> Bool {
        guard lhs.line.id == rhs.line.id,
              lhs.isActive == rhs.isActive,
              lhs.isNear == rhs.isNear,
              lhs.isPlaying == rhs.isPlaying,
              lhs.isDarkMode == rhs.isDarkMode else {
            return false
        }
        // Only active line needs time-based re-evaluation (word highlighting)
        if lhs.isActive && lhs.currentTime != rhs.currentTime {
            return false
        }
        return true
    }

    var body: some View {
        if isActive && !line.words.isEmpty {
            wordHighlightedText
        } else {
            Text(line.text)
                .font(isActive ? .system(size: 22, weight: .medium)
                    : isNear ? .system(size: 17)
                    : .system(size: 15))
                .foregroundColor(foreground)
                .lineSpacing(12)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
    }

    /// 逐字高亮 — 柔和渐变效果
    private var wordHighlightedText: some View {
        HStack(spacing: 0) {
            ForEach(Array(line.words.enumerated()), id: \.element.id) { index, word in
                Text(word.text)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .opacity(wordOpacity(word: word, at: index, in: line.words, with: displayTime))
                    .scaleEffect(wordScale(word: word, at: index, in: line.words, with: displayTime))
            }
        }
        .lineSpacing(12)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    /// 计算每个字的透明度 — 当前字最亮，前后渐变
    private func wordOpacity(word: LyricWord, at index: Int, in words: [LyricWord], with time: TimeInterval) -> Double {
        guard time >= 0 else { return 0.3 }
        let timeDiff = time - word.time
        if timeDiff < 0 { return 0.3 }
        let duration: TimeInterval = (index + 1 < words.count)
            ? max(words[index + 1].time - word.time, 0.05)
            : 0.4
        if timeDiff < duration {
            let progress = timeDiff / duration
            return 0.3 + 0.7 * (1.0 - progress * 0.3)
        }
        return 0.7
    }

    /// 计算每个字的缩放 — 当前字稍微放大
    private func wordScale(word: LyricWord, at index: Int, in words: [LyricWord], with time: TimeInterval) -> CGFloat {
        guard time >= 0 else { return 1.0 }
        let timeDiff = time - word.time
        if timeDiff < 0 { return 1.0 }
        let duration: TimeInterval = (index + 1 < words.count)
            ? max(words[index + 1].time - word.time, 0.05)
            : 0.4
        if timeDiff < duration {
            return 1.05 - (timeDiff / duration) * 0.03
        }
        return 1.0
    }

    private var foreground: Color {
        let base = isDarkMode ? Color.white : Color.black
        if isActive { return base }
        if isNear { return base.opacity(0.6) }
        return base.opacity(0.25)
    }
}

// MARK: - Data Model

struct LyricLine: Identifiable {
    let id = UUID()
    let time: TimeInterval
    let text: String
    let words: [LyricWord]

    init(time: TimeInterval, text: String, words: [LyricWord] = []) {
        self.time = time
        self.text = text
        self.words = words
    }
}

struct LyricWord: Identifiable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

/// LRC parser — supports both line-level and word-level timestamps
struct LrcParser {
    static func parse(lrcText: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let pattern = #"\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = lrcText as NSString

        regex?.enumerateMatches(in: lrcText, range: NSRange(location: 0, length: nsString.length)) { match, _, _ in
            guard let match = match else { return }
            let min = nsString.substring(with: match.range(at: 1))
            let sec = nsString.substring(with: match.range(at: 2))
            let ms  = nsString.substring(with: match.range(at: 3))
            let text = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)

            guard let minutes = Double(min), let seconds = Double(sec) else { return }
            let fraction = Double(ms) ?? 0
            let divisor: Double = ms.count == 2 ? 100.0 : 1000.0
            let time = minutes * 60 + seconds + fraction / divisor

            if !text.isEmpty {
                let words = parseWords(from: text, lineTime: time)
                lines.append(LyricLine(time: time, text: text, words: words))
            }
        }

        return lines.sorted { $0.time < $1.time }
    }

    private static func parseWords(from text: String, lineTime: TimeInterval) -> [LyricWord] {
        var words: [LyricWord] = []
        let pattern = #"\[(\d{2}):(\d{2})\.(\d{2,3})\]([^[]"*)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsText = text as NSString

        regex?.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
            guard let match = match else { return }
            let min = nsText.substring(with: match.range(at: 1))
            let sec = nsText.substring(with: match.range(at: 2))
            let ms  = nsText.substring(with: match.range(at: 3))
            let wordText = nsText.substring(with: match.range(at: 4))

            guard let minutes = Double(min), let seconds = Double(sec) else { return }
            let fraction = Double(ms) ?? 0
            let divisor: Double = ms.count == 2 ? 100.0 : 1000.0
            let time = minutes * 60 + seconds + fraction / divisor

            for char in wordText {
                words.append(LyricWord(time: time, text: String(char)))
            }
        }

        return words
    }

    static func assignWordsToLines(_ lines: [LyricLine]) -> [LyricLine] {
        guard lines.count > 0 else { return lines }

        return lines.enumerated().map { index, line in
            if !line.words.isEmpty { return line }

            let nextTime: TimeInterval
            if index < lines.count - 1 {
                nextTime = lines[index + 1].time
            } else {
                nextTime = line.time + 3.0
            }
            let duration = max(nextTime - line.time, 0.5)

            let chars = Array(line.text).filter { !$0.isWhitespace }
            guard !chars.isEmpty else { return line }

            let interval = duration / Double(chars.count)
            let words = chars.enumerated().map { charIndex, char in
                LyricWord(time: line.time + Double(charIndex) * interval, text: String(char))
            }

            return LyricLine(time: line.time, text: line.text, words: words)
        }
    }
}
