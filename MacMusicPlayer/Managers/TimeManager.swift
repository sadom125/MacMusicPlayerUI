import Foundation
import Combine

/// Standalone time publisher — removes currentTime/duration from PlayerManager's
/// @Published properties so only views that genuinely need time updates (LyricsView,
/// ProgressSlider) re-evaluate their body. Views like CompactControlBar, HomeView,
/// and MainPlayerView itself stop re-evaluating every 1s for time-only changes.
class TimeManager: ObservableObject {
    static let shared = TimeManager()

    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
}
