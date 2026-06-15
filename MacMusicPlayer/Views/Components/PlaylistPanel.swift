import SwiftUI

/// Expandable playlist panel shown below the control bar.
/// Displays the current queue with active track highlighted.
struct PlaylistPanel: View {
    let tracks: [Track]
    let currentTrackID: UUID?
    var onTrackTap: ((Int) -> Void)?

    var body: some View {
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
            .padding(.horizontal, 32)
            .padding(.vertical, 6)
        }
        .frame(maxHeight: 260)
    }
}

private struct PlaylistRow: View {
    let index: Int
    let title: String
    let artist: String
    let duration: TimeInterval
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(String(format: "%02d", index))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(isActive ? Color.accentColor : .white.opacity(0.35))
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(isActive ? Color.accentColor : .white.opacity(0.7))
                    .lineLimit(1)
                if !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(formatDuration(duration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(isActive ? Color.accentColor : .white.opacity(0.35))
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(isActive ? Color.accentColor.opacity(0.05) : Color.clear)
        .cornerRadius(6)
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
