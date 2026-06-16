import SwiftUI

/// Side panel playlist displayed on the right side of the player.
/// Shows the current queue with active track highlighted.
struct PlaylistPanel: View {
    let tracks: [Track]
    let currentTrackID: UUID?
    var backgroundColor: Color = Color(red: 0.031, green: 0.031, blue: 0.055)
    var onTrackTap: ((Int) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("播放列表")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(tracks.count) 首")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.1))

            // Track list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        Button(action: { onTrackTap?(index) }) {
                            PlaylistRow(
                                index: index + 1,
                                title: track.title,
                                artist: track.artist,
                                duration: track.duration,
                                isActive: track.id == currentTrackID
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .background(
            backgroundColor.opacity(0.95)
        )
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
