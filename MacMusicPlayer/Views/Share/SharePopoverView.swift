import SwiftUI

/// A compact popover listing share actions for the current track.
/// Two options: share song info as text, or share a lyrics screenshot card.
struct SharePopoverView: View {
    let track: Track?
    let currentLyricLine: String

    /// Called after the user picks an action; the caller dismisses the popover.
    var onShareInfo: ((Track) -> Void)?
    var onShareScreenshot: ((Track) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if let track = track {
                ShareOptionRow(
                    icon: "music.note.list",
                    title: "分享歌曲信息"
                ) {
                    onShareInfo?(track)
                }

                Divider()
                    .padding(.vertical, 2)

                ShareOptionRow(
                    icon: "photo.on.rectangle",
                    title: "分享歌词截图"
                ) {
                    onShareScreenshot?(track)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "slash.circle")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    Text("没有正在播放的歌曲")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
            }
        }
        .padding(6)
        .frame(width: 220)
    }
}
