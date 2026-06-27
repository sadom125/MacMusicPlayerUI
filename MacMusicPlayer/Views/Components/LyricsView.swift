import SwiftUI

/// Centered, immersive lyrics display.
/// Active line is highlighted with larger font and breathing glow.
/// Past lines fade to near-invisible.
/// Supports word-level highlighting when word timestamps are available.
struct LyricsView: View {
    let lyrics: [LyricLine]
    let currentLineIndex: Int
    let currentTime: TimeInterval  // 当前播放时间，用于逐字高亮
    var isPlaying: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // Top spacer so active line can be centered
                    Color.clear.frame(height: 100)

                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        LyricLineView(
                            line: line,
                            isActive: index == currentLineIndex,
                            proximity: proximity(index),
                            currentTime: currentTime,
                            isPlaying: isPlaying
                        )
                        .id(index)
                        .frame(maxWidth: .infinity)
                    }

                    // Bottom spacer
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
            .onChange(of: currentLineIndex) { newIndex in
                guard newIndex >= 0 else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private func proximity(_ index: Int) -> Proximity {
        let diff = index - currentLineIndex
        if currentLineIndex < 0 { return .far }
        if diff == 0 { return .active }
        if abs(diff) <= 2 { return .near }
        return .far
    }

    enum Proximity { case active, near, far }
}

/// Individual lyric line with pre-computed style, avoids full ForEach re-evaluation.
/// Supports word-level highlighting when word timestamps are available.
struct LyricLineView: View {
    let line: LyricLine
    let isActive: Bool
    let proximity: LyricsView.Proximity
    let currentTime: TimeInterval
    var isPlaying: Bool = false

    @State private var breathe: Bool = false
    @ObservedObject var themeManager = ThemeManager.shared

    /// When paused, return the "display" time for the current line (last word time)
    /// so the lyrics render at the final sung position instead of recomputing every frame.
    private var displayTime: TimeInterval {
        isPlaying ? currentTime : (line.words.last?.time ?? currentTime)
    }

    var body: some View {
        // Use word-level highlighting if words are available, otherwise fall back to line-level
        if isActive && !line.words.isEmpty {
            wordHighlightedText
        } else {
            Text(line.text)
                .font(isActive ? .system(size: 22, weight: .semibold) : .system(size: 16))
                .foregroundColor(foreground)
                .lineSpacing(12)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
    }

    /// 逐字高亮文本 — 柔和渐变效果
    private var wordHighlightedText: some View {
        HStack(spacing: 0) {
            ForEach(Array(line.words.enumerated()), id: \.element.id) { index, word in
                let opacity = wordOpacity(word: word, at: index, in: line.words, with: displayTime)
                let scale = wordScale(word: word, at: index, in: line.words, with: displayTime)
                Text(word.text)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    .opacity(opacity)
                    .scaleEffect(scale)
            }
        }
        .lineSpacing(12)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    /// 计算每个字的透明度 — 当前字最亮，前后渐变
    /// Optimized: uses estimated per-character duration derived from the next word's
    /// time offset, falling back to a fixed 0.4s per character when next-word info is
    /// unavailable. Avoids repeated next-word array lookups.
    private func wordOpacity(word: LyricWord, at index: Int, in words: [LyricWord], with time: TimeInterval) -> Double {
        let timeDiff = time - word.time

        // Not yet reached this word
        if timeDiff < 0 { return 0.3 }

        // Estimate per-character duration: use next word's offset or default 0.4s
        let duration: TimeInterval
        if index + 1 < words.count {
            duration = max(words[index + 1].time - word.time, 0.05)
        } else {
            duration = 0.4
        }

        if timeDiff < duration {
            let progress = timeDiff / duration
            return 0.3 + 0.7 * (1.0 - progress * 0.3)
        }

        return 0.7
    }

    /// 计算每个字的缩放 — 当前字稍微放大
    /// Optimized: uses estimated per-character duration, avoiding backward-scan.
    private func wordScale(word: LyricWord, at index: Int, in words: [LyricWord], with time: TimeInterval) -> CGFloat {
        let timeDiff = time - word.time

        if timeDiff < 0 { return 1.0 }

        let duration: TimeInterval
        if index + 1 < words.count {
            duration = max(words[index + 1].time - word.time, 0.05)
        } else {
            duration = 0.4
        }

        if timeDiff < duration {
            let progress = timeDiff / duration
            return 1.05 - progress * 0.03
        }

        return 1.0
    }

    private var foreground: Color {
        let isDark = themeManager.isDarkMode
        switch proximity {
        case .active: return isDark ? .white : .black
        case .near:   return isDark ? .white.opacity(0.6) : .black.opacity(0.6)
        case .far:    return isDark ? .white.opacity(0.25) : .black.opacity(0.25)
        }
    }
}

// MARK: - Data Model

struct LyricLine: Identifiable {
    let id = UUID()
    let time: TimeInterval   // seconds from start
    let text: String
    let words: [LyricWord]   // 逐字时间戳，用于逐字高亮

    /// 便捷初始化，默认 words 为空
    init(time: TimeInterval, text: String, words: [LyricWord] = []) {
        self.time = time
        self.text = text
        self.words = words
    }
}

struct LyricWord: Identifiable {
    let id = UUID()
    let time: TimeInterval   // 这个字开始的时间
    let text: String         // 单个字或字符
}

/// LRC parser — supports both line-level and word-level timestamps
/// Line format: "[mm:ss.xx]text"
/// Word format: "[mm:ss.xx]字[mm:ss.xx]字..." (each character has its own timestamp)
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
                // Try to parse word-level timestamps
                let words = parseWords(from: text, lineTime: time)
                lines.append(LyricLine(time: time, text: text, words: words))
            }
        }

        return lines.sorted { $0.time < $1.time }
    }

    /// Parse word-level timestamps: "[00:01.00]字[00:01.20]字..."
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

            // Add each character as a separate word
            for char in wordText {
                words.append(LyricWord(time: time, text: String(char)))
            }
        }

        // If no word-level timestamps found, return empty (will fall back to line-level)
        return words
    }

    /// Auto-generate word timestamps by distributing time evenly across characters
    /// Called after parsing to fill in words for lines that don't have word-level timestamps
    static func assignWordsToLines(_ lines: [LyricLine]) -> [LyricLine] {
        guard lines.count > 0 else { return lines }

        return lines.enumerated().map { index, line in
            // If words already exist, keep them
            if !line.words.isEmpty {
                return line
            }

            // Calculate duration for this line (time until next line starts)
            let nextTime: TimeInterval
            if index < lines.count - 1 {
                nextTime = lines[index + 1].time
            } else {
                nextTime = line.time + 3.0  // Last line gets 3 seconds
            }
            let duration = max(nextTime - line.time, 0.5)  // Minimum 0.5s

            // Skip empty or very short text
            let chars = Array(line.text).filter { !$0.isWhitespace }
            guard !chars.isEmpty else { return line }

            // Distribute time evenly across characters
            let interval = duration / Double(chars.count)
            let words = chars.enumerated().map { charIndex, char in
                LyricWord(time: line.time + Double(charIndex) * interval, text: String(char))
            }

            return LyricLine(time: line.time, text: line.text, words: words)
        }
    }
}
