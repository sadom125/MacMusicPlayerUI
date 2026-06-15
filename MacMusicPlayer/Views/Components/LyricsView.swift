import SwiftUI

/// Centered, immersive lyrics display.
/// Active line is highlighted with larger font and subtle glow.
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
                        Text(line.text)
                            .font(index == currentLineIndex
                                ? .system(size: 18, weight: .semibold)
                                : .system(size: 14))
                            .foregroundColor(textColor(for: index))
                            .lineSpacing(6)
                            .padding(.horizontal, 24)
                            .padding(.vertical, index == currentLineIndex ? 8 : 3)
                            .background(
                                index == currentLineIndex
                                    ? Color.accentColor.opacity(0.04)
                                    : Color.clear
                            )
                            .cornerRadius(8)
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
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private func textColor(for index: Int) -> Color {
        if index == currentLineIndex {
            return .white
        }
        let diff = abs(index - currentLineIndex)
        if diff <= 2 {
            return .white.opacity(0.5)
        }
        return .white.opacity(0.15)
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
            let milliseconds = Double(ms) ?? 0
            let time = minutes * 60 + seconds + milliseconds / 1000

            if !text.isEmpty {
                lines.append(LyricLine(time: time, text: text))
            }
        }

        return lines.sorted { $0.time < $1.time }
    }
}
