import SwiftUI

/// Progress bar with a visible thumb and easy drag target.
struct ProgressSlider: View {
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    var onSeek: ((TimeInterval) -> Void)?

    @State private var isDragging: Bool = false
    @State private var dragTime: TimeInterval = 0
    @State private var breathe: Bool = false
    @ObservedObject var themeManager = ThemeManager.shared

    private var effectiveDuration: TimeInterval {
        if duration > 0 { return duration }
        return max(currentTime, 1)
    }

    private var progress: Double {
        guard effectiveDuration > 0 else { return 0 }
        let p = (isDragging ? dragTime : currentTime) / effectiveDuration
        return max(0, min(1, p))
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(formatTime(currentTime))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(minWidth: 32, alignment: .leading)

            GeometryReader { geo in
                let trackWidth = geo.size.width
                let thumbSize: CGFloat = 14
                let trackHeight: CGFloat = 6
                let centerY = geo.size.height / 2

                ZStack {
                    // Track background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: trackWidth, height: trackHeight)
                        .position(x: trackWidth / 2, y: centerY)

                    // Glow behind fill bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ThemeManager.shared.accent.opacity(breathe ? 0.3 : 0.1))
                        .frame(width: max(0, trackWidth * CGFloat(progress) - thumbSize / 2), height: trackHeight)
                        .blur(radius: 6)
                        .position(x: max(thumbSize / 2, trackWidth * CGFloat(progress) / 2), y: centerY)

                    // Fill bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ThemeManager.shared.accent,
                                    ThemeManager.shared.accent.opacity(0.25)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, trackWidth * CGFloat(progress) - thumbSize / 2), height: trackHeight)
                        .position(x: max(thumbSize / 2, trackWidth * CGFloat(progress) / 2), y: centerY)

                    // Thumb — glass effect with breathing glow
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: thumbSize, height: thumbSize)
                        .overlay(
                            Circle()
                                .fill(ThemeManager.shared.accent.opacity(0.8))
                                .frame(width: 8, height: 8)
                        )
                        .shadow(color: ThemeManager.shared.accent.opacity(breathe ? 0.5 : 0.2), radius: breathe ? 4 : 2)
                        .position(x: max(thumbSize / 2, trackWidth * CGFloat(progress)), y: centerY)
                        .scaleEffect(isDragging ? 1.2 : 1.0)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = max(0, min(1, value.location.x / max(trackWidth, 1)))
                            let newTime = ratio * effectiveDuration
                            isDragging = true
                            dragTime = newTime
                        }
                        .onEnded { value in
                            let ratio = max(0, min(1, value.location.x / max(trackWidth, 1)))
                            let newTime = ratio * effectiveDuration
                            isDragging = false
                            if effectiveDuration > 0 {
                                onSeek?(newTime)
                                currentTime = newTime
                            }
                        }
                )
                .contentShape(Rectangle())
            }
            .frame(height: 28)

            Text(formatTime(effectiveDuration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(minWidth: 32, alignment: .trailing)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
