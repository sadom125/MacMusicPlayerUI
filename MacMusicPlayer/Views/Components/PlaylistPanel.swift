import SwiftUI

/// Side panel playlist displayed on the right or bottom of the player.
/// Shows the current queue with active track highlighted.
/// No background - uses the main window's background.
struct PlaylistPanel: View {
    let tracks: [Track]
    let currentTrackID: UUID?
    var onTrackTap: ((Int) -> Void)?
    var isHorizontal: Bool = false // true for bottom layout
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    /// Filtered tracks based on search text
    private var filteredTracks: [Track] {
        if searchText.isEmpty { return tracks }
        let query = searchText.lowercased()
        return tracks.filter { track in
            track.title.lowercased().contains(query) ||
            track.artist.lowercased().contains(query)
        }
    }

    var body: some View {
        if isHorizontal {
            // Bottom layout: vertical scroll (v1 style)
            VStack(spacing: 0) {
                // Listen for keyboard shortcut notifications
                Color.clear
                    .frame(width: 0, height: 0)
                    .onReceive(NotificationCenter.default.publisher(for: .focusPlaylistSearch)) { _ in
                        isSearchFocused = true
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .clearPlaylistSearch)) { _ in
                        if !searchText.isEmpty {
                            searchText = ""
                        } else {
                            isSearchFocused = false
                        }
                    }
                // Header
                HStack {
                    Text("播放列表")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("\(filteredTracks.count) 首")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                    TextField("搜索歌曲...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .focused($isSearchFocused)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.04))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                Divider().background(Color.white.opacity(0.1))

                // Track list - vertical scroll (v1 style)
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                                Button(action: {
                                    if let originalIndex = tracks.firstIndex(where: { $0.id == track.id }) {
                                        onTrackTap?(originalIndex)
                                    }
                                }) {
                                    PlaylistRowBottom(
                                        index: index + 1,
                                        title: track.title,
                                        artist: track.artist,
                                        duration: track.duration,
                                        isActive: track.id == currentTrackID
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(track.id)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onChange(of: currentTrackID) { newID in
                        if let id = newID {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                    .onAppear {
                        if let id = currentTrackID {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
        } else {
            // Right layout: vertical scroll
            VStack(spacing: 0) {
                // Listen for keyboard shortcut notifications
                Color.clear
                    .frame(width: 0, height: 0)
                    .onReceive(NotificationCenter.default.publisher(for: .focusPlaylistSearch)) { _ in
                        isSearchFocused = true
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .clearPlaylistSearch)) { _ in
                        if !searchText.isEmpty {
                            searchText = ""
                        } else {
                            isSearchFocused = false
                        }
                    }

                // Header
                HStack {
                    Text("播放列表")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("\(filteredTracks.count) 首")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                    TextField("搜索歌曲...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .focused($isSearchFocused)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.04))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                Divider().background(Color.white.opacity(0.1))

                // Track list (right panel)
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                                Button(action: {
                                    if let originalIndex = tracks.firstIndex(where: { $0.id == track.id }) {
                                        onTrackTap?(originalIndex)
                                    }
                                }) {
                                    PlaylistRow(
                                        index: index + 1,
                                        title: track.title,
                                        artist: track.artist,
                                        duration: track.duration,
                                        isActive: track.id == currentTrackID
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(track.id)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onChange(of: currentTrackID) { newID in
                        if let id = newID {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                    .onAppear {
                        if let id = currentTrackID {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
            .frame(width: 260)
            .frame(maxHeight: .infinity)
        }
    }
}

private struct PlaylistRow: View {
    let index: Int
    let title: String
    let artist: String
    let duration: TimeInterval
    let isActive: Bool

    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 10) {
            // Track number
            Text(String(format: "%02d", index))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(isActive ? themeManager.accent : .white.opacity(0.3))
                .frame(width: 20, alignment: .trailing)

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? themeManager.accent : .white.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 8)

            // Duration
            Text(formatDuration(duration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? themeManager.accent.opacity(0.08) : Color.clear)
        )
        .padding(.horizontal, 8)
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

private struct PlaylistRowHorizontal: View {
    let index: Int
    let title: String
    let artist: String
    let duration: TimeInterval
    let isActive: Bool

    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Track number
            Text(String(format: "%02d", index))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(isActive ? themeManager.accent : .white.opacity(0.3))

            // Track title
            Text(title)
                .font(.system(size: 12, weight: isActive ? .medium : .regular))
                .foregroundColor(isActive ? themeManager.accent : .white.opacity(0.75))
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(width: 120, alignment: .leading)

            // Artist
            if !artist.isEmpty {
                Text(artist)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 120, alignment: .leading)
            }

            // Duration
            Text(formatDuration(duration))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? themeManager.accent.opacity(0.08) : Color.white.opacity(0.02))
        )
        .frame(width: 140)
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

private struct PlaylistRowBottom: View {
    let index: Int
    let title: String
    let artist: String
    let duration: TimeInterval
    let isActive: Bool

    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Track number
            Text(String(format: "%02d", index))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(isActive ? themeManager.accent : .white.opacity(0.3))
                .frame(width: 24, alignment: .trailing)

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? themeManager.accent : .white.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 8)

            // Duration
            Text(formatDuration(duration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? themeManager.accent.opacity(0.08) : Color.clear)
        )
        .padding(.horizontal, 8)
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
