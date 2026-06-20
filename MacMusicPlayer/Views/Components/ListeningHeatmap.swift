//
//  ListeningHeatmap.swift
//  MacMusicPlayer
//
//  Listening activity heatmap — last 30 days.
//  Rounded rectangle grid, fills container width.
//

import SwiftUI

/// 听歌热力图 — 圆角矩形网格，自适应容器
struct ListeningHeatmap: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject private var history = PlaybackHistory.shared
    @State private var refreshTrigger: Bool = false
    @State private var lastRefreshDay: String = ""
    @State private var midnightTimer: Timer?

    private var primaryText: Color { themeManager.isDarkMode ? .white : .black }
    private var cardBg: Color { themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.04) }
    private var separatorColor: Color { themeManager.isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.08) }

    /// 30 天数据，每行 10 列，共 3 行
    private var rows: [[(date: Date, count: Int)]] {
        let data = Array(history.dailyCountsForLast35Days().prefix(30))
        let cols = 10
        return stride(from: 0, to: data.count, by: cols).map {
            Array(data[$0..<min($0 + cols, data.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: title + legend on same line
            HStack(alignment: .center) {
                Text("听歌热力图（近30天）")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(primaryText)

                Spacer()

                HStack(spacing: 4) {
                    Text("少")
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.isDarkMode ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cellColor(for: level))
                            .frame(width: 14, height: 14)
                    }
                    Text("多")
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.isDarkMode ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Separator
            Rectangle()
                .fill(separatorColor)
                .frame(height: 1)

            // Grid — adaptive width, fixed aspect ratio
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows.indices, id: \.self) { rowIdx in
                    HStack(spacing: 6) {
                        ForEach(rows[rowIdx].indices, id: \.self) { colIdx in
                            let entry = rows[rowIdx][colIdx]
                            RoundedRectangle(cornerRadius: 6)
                                .fill(cellColor(for: intensityLevel(for: entry.count)))
                                .aspectRatio(1.15, contentMode: .fit)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBg)
        )
        .onAppear {
            lastRefreshDay = Self.todayString()
            startMidnightTimer()
        }
        .onDisappear {
            midnightTimer?.invalidate()
            midnightTimer = nil
        }
    }

    // MARK: - Midnight Refresh

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func startMidnightTimer() {
        midnightTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            let today = Self.todayString()
            if today != lastRefreshDay {
                lastRefreshDay = today
                DispatchQueue.main.async {
                    refreshTrigger.toggle()
                }
            }
        }
    }

    // MARK: - Helpers

    private func intensityLevel(for count: Int) -> Int {
        switch count {
        case 0: return 0
        case 1...2: return 1
        case 3...5: return 2
        case 6...10: return 3
        default: return 4
        }
    }

    private func cellColor(for level: Int) -> Color {
        let accent = themeManager.accent
        switch level {
        case 0: return themeManager.isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
        case 1: return accent.opacity(0.25)
        case 2: return accent.opacity(0.45)
        case 3: return accent.opacity(0.7)
        case 4: return accent
        default: return Color.clear
        }
    }
}
