import SwiftUI

/// Minimalist progress bar with time labels and draggable thumb.
/// Shows "--:--" when no track is loaded (duration == 0).
/// Adapts to light/dark mode.
struct ProgressSlider: View {
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    var onSeek: ((TimeInterval) -> Void)?

    @State private var isDragging: Bool = false
    @State private var dragTime: TimeInterval = 0
    @ObservedObject var themeManager = ThemeManager.shared

    private var hasValidDuration: Bool {
        duration > 0
    }

    private var displayDuration: TimeInterval {
        hasValidDuration ? duration : max(currentTime, 1)
    }

    private var progress: Double {
        guard displayDuration > 0 else { return 0 }
        let p = (isDragging ? dragTime : currentTime) / displayDuration
        return max(0, min(1, p))
    }

    var body: some View {
        HStack(spacing: 10) {
            // Current Time
            Text(hasValidDuration ? formatTime(currentTime) : "--:--")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(textColor)
                .frame(minWidth: 36, alignment: .trailing)

            // Slider Track
            GeometryReader { geo in
                let tw = max(geo.size.width, 1)
                let thumbSize: CGFloat = 14
                let trackHeight: CGFloat = 3
                let p = CGFloat(progress)
                let centerY: CGFloat = 12  // half of 24

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: tw, height: 24)
                    .overlay(
                        ZStack {
                            // Track background
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(trackColor)
                                .frame(width: tw, height: trackHeight)
                                .position(x: tw / 2, y: centerY)

                            // Fill bar
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(fillColor)
                                .frame(width: max(0, tw * p - thumbSize / 2), height: trackHeight)
                                .position(x: max(thumbSize / 2, tw * p / 2), y: centerY)

                            // Thumb
                            Circle()
                                .fill(thumbColor)
                                .frame(width: thumbSize, height: thumbSize)
                                .shadow(color: thumbShadowColor, radius: 2)
                                .position(x: max(thumbSize / 2, tw * p), y: centerY)
                                .scaleEffect(isDragging ? 1.2 : 1.0)
                        }
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let ratio = max(0, min(1, value.location.x / tw))
                                let newTime = ratio * displayDuration
                                isDragging = true
                                dragTime = newTime
                            }
                            .onEnded { value in
                                let ratio = max(0, min(1, value.location.x / tw))
                                let newTime = ratio * displayDuration
                                isDragging = false
                                if displayDuration > 0 {
                                    onSeek?(newTime)
                                    currentTime = newTime
                                }
                            }
                    )
            }
            .frame(height: 24)

            // Duration
            Text(hasValidDuration ? formatTime(duration) : "--:--")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(textColor)
                .frame(minWidth: 36, alignment: .leading)
        }
    }

    // MARK: - Theme-adaptive colors (glass effect)

    private var textColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7)
    }

    private var trackColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.2) : .black.opacity(0.12)
    }

    private var fillColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.5) : .black.opacity(0.35)
    }

    private var thumbColor: Color {
        themeManager.isDarkMode
            ? Color.white.opacity(0.95)
            : Color.white.opacity(0.95)
    }

    private var thumbShadowColor: Color {
        themeManager.isDarkMode ? .black.opacity(0.3) : .black.opacity(0.15)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
