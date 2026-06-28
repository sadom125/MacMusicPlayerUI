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
        PlaylistTableView(
            tracks: filteredTracks,
            currentTrackID: currentTrackID,
            onTrackTap: { index in
                if let origIndex = tracks.firstIndex(where: { $0.id == filteredTracks[index].id }) {
                    onTrackTap?(origIndex)
                }
            }
        )
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

// MARK: - Playlist NSTableView

/// NSTableView-based playlist for true native scrolling performance.
/// NSTableView reuses cells (~15 visible for 300 tracks), supports
/// hardware-accelerated scrolling, and avoids SwiftUI's view struct
/// instantiation overhead entirely.
private struct PlaylistTableView: NSViewRepresentable {
    let tracks: [Track]
    let currentTrackID: UUID?
    var onTrackTap: ((Int) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTrackTap)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        let tableView = NSTableView()
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.rowHeight = 50
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.floatsGroupRows = false
        tableView.selectionHighlightStyle = .none
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        col.isEditable = false
        tableView.addTableColumn(col)
        tableView.setDraggingSourceOperationMask(.every, forLocal: true)

        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.target = context.coordinator
        tableView.action = #selector(Coordinator.rowClicked(_:))

        scrollView.documentView = tableView

        // Track user-initiated scrolling — skip auto-scroll during user drag
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.willStartLiveScroll),
            name: NSScrollView.willStartLiveScrollNotification,
            object: scrollView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.didEndLiveScroll),
            name: NSScrollView.didEndLiveScrollNotification,
            object: scrollView
        )

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tableView = nsView.documentView as? NSTableView else { return }

        context.coordinator.tracks = tracks
        context.coordinator.currentTrackID = currentTrackID
        context.coordinator.onTrackTap = onTrackTap

        // Only reloadData when track data actually changes
        if context.coordinator.lastReloadIDs != Set(tracks.map(\.id)) {
            context.coordinator.lastReloadIDs = Set(tracks.map(\.id))
            tableView.reloadData()
        }

        // Only auto-scroll to current track when actively changing tracks,
        // NOT when the user is manually scrolling.
        if !context.coordinator.isUserScrolling,
           context.coordinator.lastScrolledTrackID != currentTrackID {
            context.coordinator.lastScrolledTrackID = currentTrackID
            if let id = currentTrackID,
               let idx = tracks.firstIndex(where: { $0.id == id }) {
                tableView.scrollRowToVisible(idx)
            }
        }
    }

    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var tracks: [Track] = []
        var currentTrackID: UUID?
        var onTrackTap: ((Int) -> Void)?

        /// Track last reload data set to avoid unnecessary reloadData calls
        var lastReloadIDs: Set<UUID> = []
        /// Track last auto-scrolled track to avoid fighting user scroll
        var lastScrolledTrackID: UUID?
        /// User-initiated scroll flag — checked before auto-scroll
        var isUserScrolling = false

        init(onTap: ((Int) -> Void)?) {
            self.onTrackTap = onTap
        }

        @objc func willStartLiveScroll() {
            isUserScrolling = true
        }

        @objc func didEndLiveScroll() {
            isUserScrolling = false
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            tracks.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < tracks.count else { return nil }
            let track = tracks[row]
            let isActive = track.id == currentTrackID

            let identifier = NSUserInterfaceItemIdentifier("PlaylistCell")
            let cell: PlaylistCell
            if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? PlaylistCell {
                cell = reused
            } else {
                cell = PlaylistCell()
                cell.identifier = identifier
            }
            cell.configure(with: track, isActive: isActive)
            return cell
        }

        @objc func rowClicked(_ sender: NSTableView) {
            let row = sender.clickedRow
            guard row >= 0, row < tracks.count else { return }
            onTrackTap?(row)
        }
    }
}

/// Custom NSTableCellView for playlist rows.
private class PlaylistCell: NSTableCellView {
    private let artImageView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let artistField = NSTextField(labelWithString: "")
    private let durationField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        // Album art
        artImageView.wantsLayer = true
        artImageView.layer?.cornerRadius = 6
        artImageView.layer?.masksToBounds = true
        artImageView.imageScaling = .scaleAxesIndependently
        artImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(artImageView)

        // Title
        titleField.lineBreakMode = .byTruncatingTail
        titleField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleField)

        // Artist
        artistField.font = NSFont.systemFont(ofSize: 10)
        artistField.textColor = .secondaryLabelColor
        artistField.lineBreakMode = .byTruncatingTail
        artistField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(artistField)

        // Duration
        durationField.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        durationField.textColor = .secondaryLabelColor
        durationField.alignment = .right
        durationField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(durationField)

        NSLayoutConstraint.activate([
            artImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            artImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            artImageView.widthAnchor.constraint(equalToConstant: 36),
            artImageView.heightAnchor.constraint(equalToConstant: 36),

            titleField.leadingAnchor.constraint(equalTo: artImageView.trailingAnchor, constant: 10),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            titleField.trailingAnchor.constraint(lessThanOrEqualTo: durationField.leadingAnchor, constant: -8),

            artistField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
            artistField.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 8),
            artistField.trailingAnchor.constraint(lessThanOrEqualTo: durationField.leadingAnchor, constant: -8),

            durationField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            durationField.centerYAnchor.constraint(equalTo: centerYAnchor),
            durationField.widthAnchor.constraint(equalToConstant: 50),
        ])
    }

    func configure(with track: Track, isActive: Bool) {
        if let data = track.albumArtData, let img = NSImage(data: data) {
            artImageView.image = img
        } else {
            artImageView.image = nil
        }

        titleField.stringValue = track.title
        titleField.font = isActive ? NSFont.systemFont(ofSize: 12, weight: .medium) : NSFont.systemFont(ofSize: 12)
        titleField.textColor = isActive ? NSColor.labelColor : NSColor.secondaryLabelColor

        artistField.stringValue = track.artist
        artistField.textColor = .tertiaryLabelColor

        durationField.stringValue = track.duration.formatDuration
        durationField.textColor = .tertiaryLabelColor
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

    /// 获取最近 30 天每天的听歌量（用于热力图）
    func dailyCountsForLast30Days() -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [(date: Date, count: Int)] = []

        for dayOffset in (0..<30).reversed() {
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
