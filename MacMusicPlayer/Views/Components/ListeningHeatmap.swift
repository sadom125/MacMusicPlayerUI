//
//  ListeningHeatmap.swift
//  MacMusicPlayer
//
//  Listening activity heatmap — last 30 days.
//  Circular cells with breathing glow, fills container width.
//

import SwiftUI

/// 听歌热力图 — 圆形网格 + 呼吸动画，自适应容器
struct ListeningHeatmap: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject private var history = PlaybackHistory.shared
    @State private var refreshTrigger: Bool = false
    @State private var lastRefreshDay: String = ""
    @State private var midnightTimer: Timer?
    @State private var hoveredDate: String?
    @State private var breathe: Bool = false

    private var primaryText: Color { themeManager.isDarkMode ? .white : .black }
    private var cardBg: Color { themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.04) }
    private var separatorColor: Color { themeManager.isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.08) }

    private let cellSize: CGFloat = 72
    private let cellSpacing: CGFloat = 24

    /// 30 天数据，每行 10 列，共 3 行
    private var rows: [[(date: Date, count: Int)]] {
        let data = history.dailyCountsForLast30Days()
        let cols = 10
        return stride(from: 0, to: data.count, by: cols).map {
            Array(data[$0..<min($0 + cols, data.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                        Circle()
                            .fill(cellColor(for: level))
                            .frame(width: 10, height: 10)
                    }
                    Text("多")
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.isDarkMode ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Rectangle()
                .fill(separatorColor)
                .frame(height: 1)

            // Grid
            VStack(alignment: .leading, spacing: cellSpacing) {
                ForEach(rows.indices, id: \.self) { rowIdx in
                    HStack(spacing: cellSpacing) {
                        ForEach(rows[rowIdx].indices, id: \.self) { colIdx in
                            let entry = rows[rowIdx][colIdx]
                            let dateStr = Self.formatDate(entry.date)
                            let isHovered = hoveredDate == dateStr
                            let level = intensityLevel(for: entry.count)

                            HeatmapDot(
                                count: entry.count,
                                level: level,
                                isHovered: isHovered,
                                color: cellColor(for: level),
                                dateStr: dateStr,
                                breathe: breathe && entry.count > 0,
                                cellSize: cellSize,
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
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                breathe = true
            }
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
        }
    }

    // MARK: - Helpers

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
                DispatchQueue.main.async { refreshTrigger.toggle() }
            }
        }
    }

    // 数据刷新由 PlaybackHistory.dataDidChangeNotification 通知驱动

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

// MARK: - Heatmap Dot

private struct HeatmapDot: View {
    let count: Int
    let level: Int
    let isHovered: Bool
    let color: Color
    let dateStr: String
    let breathe: Bool
    let cellSize: CGFloat
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: cellSize, height: cellSize)
            .scaleEffect(isHovered ? 1.15 : 1.0)
            .shadow(color: color.opacity(isHovered ? 0.4 : (breathe && level > 0 ? 0.15 : 0)),
                    radius: isHovered ? 6 : (breathe ? 3 : 0))
            .overlay(
                Group {
                    if isHovered {
                        let displayDate = dateStr.replacingOccurrences(of: "-", with: "/")
                        Text("\(displayDate)\n\(count) 首")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.isDarkMode ? .white : .black)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(themeManager.isDarkMode ? Color.black.opacity(0.85) : Color.white)
                                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                            )
                            .offset(y: -(cellSize / 2 + 24))
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            .zIndex(10)
                    }
                }
            )
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
