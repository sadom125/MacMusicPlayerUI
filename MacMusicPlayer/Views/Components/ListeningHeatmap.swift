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
    @State private var dataRefreshTimer: Timer?
    @State private var hoveredDate: String?

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
                            let dateStr = Self.formatDate(entry.date)
                            let isHovered = hoveredDate == dateStr

                            HeatmapCell(
                                count: entry.count,
                                level: intensityLevel(for: entry.count),
                                isHovered: isHovered,
                                color: cellColor(for: intensityLevel(for: entry.count)),
                                dateStr: dateStr,
                                themeManager: themeManager
                            )
                            .onHover { hovering in
                                withAnimation(.easeOut(duration: 0.15)) {
                                    hoveredDate = hovering ? dateStr : nil
                                }
                            }
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
            startDataRefreshTimer()
            // Listen for immediate data changes
            NotificationCenter.default.addObserver(
                forName: PlaybackHistory.dataDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                refreshTrigger.toggle()
            }
        }
        .onDisappear {
            midnightTimer?.invalidate()
            midnightTimer = nil
            dataRefreshTimer?.invalidate()
            dataRefreshTimer = nil
        }
    }

    // MARK: - Midnight Refresh

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
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

    /// 每 10 秒刷新一次数据，确保 @ObservedObject 变化能反映到 UI
    private func startDataRefreshTimer() {
        dataRefreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            DispatchQueue.main.async {
                refreshTrigger.toggle()
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

// MARK: - Heatmap Cell with Hover

private struct HeatmapCell: View {
    let count: Int
    let level: Int
    let isHovered: Bool
    let color: Color
    let dateStr: String
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .aspectRatio(1.15, contentMode: .fit)
                .scaleEffect(isHovered ? 1.25 : 1.0)
                .shadow(color: .black.opacity(isHovered ? 0.2 : 0), radius: isHovered ? 4 : 0)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isHovered ? (themeManager.isDarkMode ? .white.opacity(0.3) : .black.opacity(0.15)) : .clear, lineWidth: 1)
                )

            // Tooltip
            if isHovered {
                Text("\(dateStr): \(count) 首")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(themeManager.isDarkMode ? Color.white.opacity(0.9) : Color.white)
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    )
                    .offset(y: -32)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
