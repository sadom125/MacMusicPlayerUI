import SwiftUI

/// Centered, immersive lyrics display.
/// Active line is highlighted with larger font and breathing glow.
/// Past lines fade to near-invisible.
struct LyricsView: View {
    let lyrics: [LyricLine]
    let currentLineIndex: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    // Top spacer so active line can be centered
                    Color.clear.frame(height: 100)

                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        LyricLineView(
                            text: line.text,
                            isActive: index == currentLineIndex,
                            proximity: proximity(index)
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
struct LyricLineView: View {
    let text: String
    let isActive: Bool
    let proximity: LyricsView.Proximity

    @State private var breathe: Bool = false
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        Text(text)
            .font(isActive ? .system(size: 18, weight: .semibold) : .system(size: 14))
            .foregroundColor(foreground)
            .lineSpacing(6)
            .padding(.horizontal, 24)
            .padding(.vertical, isActive ? 8 : 3)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ThemeManager.shared.accent.opacity(breathe ? 0.08 : 0.03))
                }
            }
            .cornerRadius(8)
            .shadow(color: .clear, radius: 0)
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
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
}

/// Simple LRC parser: "[mm:ss.xx]text"
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
            // 2 digits = centiseconds (÷100), 3 digits = milliseconds (÷1000)
            let fraction = Double(ms) ?? 0
            let divisor: Double = ms.count == 2 ? 100.0 : 1000.0
            let time = minutes * 60 + seconds + fraction / divisor

            if !text.isEmpty {
                lines.append(LyricLine(time: time, text: text))
            }
        }

        return lines.sorted { $0.time < $1.time }
    }
}
