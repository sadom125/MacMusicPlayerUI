import SwiftUI

/// Centered, immersive lyrics display.
/// Active line is highlighted with larger font and breathing glow.
/// Past lines fade to near-invisible.
/// Supports word-level highlighting when word timestamps are available.
struct LyricsView: View {
    let lyrics: [LyricLine]
    let currentLineIndex: Int
    let currentTime: TimeInterval  // 当前播放时间，用于逐字高亮

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
                            currentTime: currentTime
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

    @State private var breathe: Bool = false
    @ObservedObject var themeManager = ThemeManager.shared

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
                let opacity = wordOpacity(word: word, at: index, in: line.words)
                let scale = wordScale(word: word, at: index, in: line.words)
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
    private func wordOpacity(word: LyricWord, at index: Int, in words: [LyricWord]) -> Double {
        guard index < words.count else { return 0.3 }

        let currentWord = words[index]
        let timeDiff = currentTime - currentWord.time

        // 还没唱到的字
        if timeDiff < 0 {
            // 前面的字：根据距离逐渐变亮
            if index > 0 {
                let prevWord = words[index - 1]
                let prevDiff = currentTime - prevWord.time
                let transitionDuration = currentWord.time - prevWord.time
                if transitionDuration > 0 && prevDiff >= 0 {
                    // 正在从前一个字过渡过来，逐渐变亮
                    return min(prevDiff / transitionDuration, 1.0) * 0.7 + 0.3
                }
            }
            return 0.3
        }

        // 当前字或已唱过的字
        // 找到下一个字的时间
        let nextTime: TimeInterval
        if index < words.count - 1 {
            nextTime = words[index + 1].time
        } else {
            nextTime = currentWord.time + 0.5  // 最后一个字
        }
        let duration = nextTime - currentWord.time

        if duration > 0 && timeDiff < duration {
            // 正在当前字：根据进度变化亮度
            let progress = timeDiff / duration
            return 0.3 + 0.7 * (1.0 - progress * 0.3)  // 从1.0渐变到0.7
        }

        // 已唱过的字：保持中等亮度
        return 0.7
    }

    /// 计算每个字的缩放 — 当前字稍微放大
    private func wordScale(word: LyricWord, at index: Int, in words: [LyricWord]) -> CGFloat {
        guard index < words.count else { return 1.0 }

        let currentWord = words[index]
        let timeDiff = currentTime - currentWord.time

        // 还没唱到的字
        if timeDiff < 0 {
            if index > 0 {
                let prevWord = words[index - 1]
                let prevDiff = currentTime - prevWord.time
                let transitionDuration = currentWord.time - prevWord.time
                if transitionDuration > 0 && prevDiff >= 0 {
                    let t = min(prevDiff / transitionDuration, 1.0)
                    return 1.0 + t * 0.05  // 从1.0到1.05
                }
            }
            return 1.0
        }

        let nextTime: TimeInterval
        if index < words.count - 1 {
            nextTime = words[index + 1].time
        } else {
            nextTime = currentWord.time + 0.5
        }
        let duration = nextTime - currentWord.time

        if duration > 0 && timeDiff < duration {
            let progress = timeDiff / duration
            return 1.05 - progress * 0.03  // 从1.05到1.02
        }

        return 1.0
    }

    /// 判断某个字是否应该高亮
    private func isWordHighlighted(word: LyricWord, at index: Int, in words: [LyricWord]) -> Bool {
        // 如果是最后一个字，只要当前时间 >= 字的时间就高亮
        if index == words.count - 1 {
            return currentTime >= word.time
        }
        // 否则，当前时间在这个字和下一个字之间就高亮
        let nextWord = words[index + 1]
        return currentTime >= word.time && currentTime < nextWord.time
    }

    private var foreground: Color {
        let isDark = themeManager.isDarkMode
        switch proximity {
        case .active: return isDark ? .white : .black
        case .near:   return isDark ? .white.opacity(0.6) : .black.opacity(0.6)
        case .far:    return isDark ? .white.opacity(0.25) : .black.opacity(0.25)
        }
    }

    private var wordActiveColor: Color {
        themeManager.isDarkMode ? .white : .black
    }

    private var wordInactiveColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)
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
