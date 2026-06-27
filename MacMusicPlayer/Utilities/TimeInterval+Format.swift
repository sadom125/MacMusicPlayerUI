import Foundation

extension TimeInterval {
    /// Format as mm:ss or "--:--" when duration is invalid.
    var formatDuration: String {
        guard isFinite, self > 0 else { return "--:--" }
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
