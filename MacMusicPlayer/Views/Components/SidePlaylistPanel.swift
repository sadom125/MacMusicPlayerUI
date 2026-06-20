import SwiftUI

/// Full-height playlist panel that slides in from the right.
/// Minimalist design matching reference: clean layout, subtle colors, fluid animations.
/// Adapts to light/dark mode with glass effect.
struct SidePlaylistPanel: View {
    let tracks: [Track]
    let currentTrackID: UUID?
    var onTrackTap: ((Int) -> Void)?
    var onDismiss: (() -> Void)?

    @State private var searchText: String = ""
    @State private var selectedTab: String = "queue" // "history" or "queue"
    @FocusState private var isSearchFocused: Bool
    @State private var historyTracks: [Track] = []
    @ObservedObject var themeManager = ThemeManager.shared

    private var filteredTracks: [Track] {
        let sourceTracks = selectedTab == "history" ? historyTracks : tracks
        if searchText.isEmpty { return sourceTracks }
        let query = searchText.lowercased()
        return sourceTracks.filter { track in
            track.title.lowercased().contains(query) ||
            track.artist.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            headerSection

            // Search Bar
            searchBar

            // Track List
            trackList

            // Bottom info
            bottomInfo
        }
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(themeManager.isDarkMode ? 0.1 : 0.15), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            loadHistory()
        }
        .onChange(of: currentTrackID) { _ in
            if selectedTab == "history" {
                loadHistory()
            }
        }
    }

    // MARK: - Header with Tabs

    private var headerSection: some View {
        HStack(spacing: 0) {
            // History Tab
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = "history"
                }
                loadHistory()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("播放历史")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(selectedTab == "history" ? primaryTextColor : tertiaryTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selectedTab == "history"
                        ? RoundedRectangle(cornerRadius: 6)
                            .fill(accentBgColor)
                        : nil
                )
            }
            .buttonStyle(.plain)

            // Queue Tab
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = "queue"
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "list.number")
                        .font(.system(size: 11))
                    Text("待播清单")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(selectedTab == "queue" ? primaryTextColor : tertiaryTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selectedTab == "queue"
                        ? RoundedRectangle(cornerRadius: 6)
                            .fill(accentBgColor)
                        : nil
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(tertiaryTextColor)

            TextField("搜索...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(primaryTextColor)
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(tertiaryTextColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(inactiveBgColor)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Track List

    private var trackList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 1) {
                    ForEach(filteredTracks) { track in
                        Button(action: {
                            if let originalIndex = tracks.firstIndex(where: { $0.id == track.id }) {
                                onTrackTap?(originalIndex)
                            }
                        }) {
                            TrackRow(
                                track: track,
                                isActive: track.id == currentTrackID
                            )
                        }
                        .buttonStyle(.plain)
                        .id(track.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: currentTrackID) { newID in
                if let id = newID {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Bottom Info

    private var bottomInfo: some View {
        HStack {
            Text("\(filteredTracks.count) 首")
                .font(.system(size: 11))
                .foregroundColor(tertiaryTextColor)

            Spacer()

            if selectedTab == "history" && !historyTracks.isEmpty {
                Button(action: {
                    PlaybackHistory.shared.clear()
                    historyTracks = []
                }) {
                    Text("清空历史")
                        .font(.system(size: 11))
                        .foregroundColor(tertiaryTextColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - History Management

    private func loadHistory() {
        historyTracks = PlaybackHistory.shared.recentTracks
    }

    // MARK: - Theme-adaptive colors

    private var primaryTextColor: Color {
        themeManager.isDarkMode ? .white : .black
    }

    private var secondaryTextColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6)
    }

    private var tertiaryTextColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)
    }

    private var accentBgColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.08) : .black.opacity(0.06)
    }

    private var inactiveBgColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.04) : .black.opacity(0.03)
    }
}

// MARK: - Track Row

private struct TrackRow: View {
    let track: Track
    let isActive: Bool

    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 10) {
            // Album Art Thumbnail
            if let data = track.albumArtData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.low)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeManager.isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.25) : .black.opacity(0.25))
                    )
            }

            // Track Info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 12, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? primaryTextColor : secondaryTextColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !track.artist.isEmpty {
                    Text(track.artist)
                        .font(.system(size: 10))
                        .foregroundColor(tertiaryTextColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 6)

            // Duration
            Text(formatDuration(track.duration))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(tertiaryTextColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? accentBgColor : Color.clear)
        )
        .padding(.horizontal, 8)
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    // MARK: - Theme-adaptive colors

    private var primaryTextColor: Color {
        themeManager.isDarkMode ? .white : .black
    }

    private var secondaryTextColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8)
    }

    private var tertiaryTextColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)
    }

    private var accentBgColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.08) : .black.opacity(0.06)
    }
}

// MARK: - Playback History Manager

class PlaybackHistory: ObservableObject {
    static let shared = PlaybackHistory()
    static let dataDidChangeNotification = Notification.Name("PlaybackHistoryDataDidChange")

    private let maxHistorySize = 50
    private let historyKey = "PlaybackHistory"
    private let dailyCountsKey = "PlaybackDailyCounts"

    @Published var recentTracks: [Track] = []
    /// 日听歌量：[日期字符串: 次数]
    @Published var dailyPlayCounts: [String: Int] = [:]

    private init() {
        loadFromStorage()
    }

    func addToHistory(_ track: Track) {
        // Remove if already exists
        recentTracks.removeAll { $0.id == track.id }

        // Add to beginning
        recentTracks.insert(track, at: 0)

        // Limit size
        if recentTracks.count > maxHistorySize {
            recentTracks = Array(recentTracks.prefix(maxHistorySize))
        }

        // Update daily count
        let today = Self.dateFormatter.string(from: Date())
        dailyPlayCounts[today, default: 0] += 1

        saveToStorage()

        // Notify observers (heatmap) that data changed
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.dataDidChangeNotification, object: nil)
        }
    }

    func clear() {
        recentTracks = []
        dailyPlayCounts = [:]
        UserDefaults.standard.removeObject(forKey: historyKey)
        UserDefaults.standard.removeObject(forKey: dailyCountsKey)
    }

    /// 获取最近 35 天每天的听歌量（用于热力图）
    func dailyCountsForLast35Days() -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [(date: Date, count: Int)] = []

        for dayOffset in (0..<35).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let key = Self.dateFormatter.string(from: date)
                let count = dailyPlayCounts[key] ?? 0
                result.append((date: date, count: count))
            }
        }
        return result
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func saveToStorage() {
        let urls = recentTracks.map { $0.url.path }
        UserDefaults.standard.set(urls, forKey: historyKey)
        UserDefaults.standard.set(dailyPlayCounts, forKey: dailyCountsKey)
    }

    private func loadFromStorage() {
        guard let urls = UserDefaults.standard.stringArray(forKey: historyKey) else { return }
        if let counts = UserDefaults.standard.dictionary(forKey: dailyCountsKey) as? [String: Int] {
            dailyPlayCounts = counts
        }
    }
}

// MARK: - Bottom-Only Rounded Rectangle

/// Rectangle with only bottom corners rounded — for panels flush with window top edge.
private struct BottomRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                    radius: radius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                    radius: radius,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}
