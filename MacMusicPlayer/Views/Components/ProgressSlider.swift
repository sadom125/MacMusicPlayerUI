import SwiftUI
import AppKit

/// Minimalist progress bar with time labels.
/// Uses NSSlider (via NSViewRepresentable) for native track drawing and
/// dragging — no GeometryReader, no DragGesture, no ZStack of Rects.
/// Observes TimeManager.shared so time updates do NOT trigger parent view
/// (CompactControlBar, MainPlayerView) body re-evaluation.
struct ProgressSlider: View {
    var onSeek: ((TimeInterval) -> Void)?

    @ObservedObject var timeManager = TimeManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isDragging: Bool = false
    @State private var dragTime: TimeInterval = 0

    private var hasValidDuration: Bool { timeManager.duration > 0 }

    private var displayDuration: TimeInterval {
        hasValidDuration ? timeManager.duration : max(timeManager.currentTime, 1)
    }

    private var displayTime: TimeInterval {
        isDragging ? dragTime : timeManager.currentTime
    }

    var body: some View {
        HStack(spacing: 10) {
            // Current Time
            Text(hasValidDuration ? formatTime(displayTime) : "--:--")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(textColor)
                .frame(minWidth: 36, alignment: .trailing)

            // NSSlider via NSViewRepresentable — zero SwiftUI body during drag
            ProgressSliderView(
                progress: displayDuration > 0 ? displayTime / displayDuration : 0,
                onChanged: { newProgress in
                    let newTime = newProgress * displayDuration
                    isDragging = true
                    dragTime = newTime
                },
                onEnded: { finalProgress in
                    let finalTime = finalProgress * displayDuration
                    isDragging = false
                    if displayDuration > 0 {
                        onSeek?(finalTime)
                    }
                }
            )
            .frame(height: 24)

            // Duration
            Text(hasValidDuration ? formatTime(timeManager.duration) : "--:--")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(textColor)
                .frame(minWidth: 36, alignment: .leading)
        }
    }

    // MARK: - Theme-adaptive colors

    private var textColor: Color {
        themeManager.isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

// MARK: - NSSlider NSViewRepresentable

/// NSSlider wrapper — AppKit handles track/thumb drawing and drag natively.
/// No SwiftUI GeometryReader, no DragGesture, no 3-layer ZStack re-creation.
private struct ProgressSliderView: NSViewRepresentable {
    /// Normalized progress 0.0–1.0
    let progress: Double
    var onChanged: ((Double) -> Void)?
    var onEnded: ((Double) -> Void)?

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider()
        slider.isContinuous = true
        slider.minValue = 0
        slider.maxValue = 1
        slider.doubleValue = progress
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged(_:))
        slider.controlSize = .small
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        // Don't fight the user's drag — let slider show drag position
        if !context.coordinator.isDragging {
            nsView.doubleValue = progress
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    class Coordinator: NSObject {
        var onChanged: ((Double) -> Void)?
        var onEnded: ((Double) -> Void)?
        var isDragging = false

        init(onChanged: ((Double) -> Void)?, onEnded: ((Double) -> Void)?) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        /// Distinguish drag-in-progress from drag-end by checking the current event type.
        @objc func valueChanged(_ sender: NSSlider) {
            guard let event = NSApp.currentEvent else { return }
            let value = sender.doubleValue
            switch event.type {
            case .leftMouseDown, .leftMouseDragged:
                isDragging = true
                onChanged?(value)
            case .leftMouseUp:
                isDragging = false
                onEnded?(value)
            default:
                onChanged?(value)
            }
        }
    }
}
