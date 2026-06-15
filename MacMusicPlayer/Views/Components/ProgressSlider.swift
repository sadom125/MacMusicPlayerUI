import SwiftUI

/// Progress bar with a visible thumb and easy drag target.
struct ProgressSlider: View {
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    var onSeek: ((TimeInterval) -> Void)?

    @State private var isDragging: Bool = false
    @State private var dragTime: TimeInterval = 0
    @State private var breathe: Bool = false

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
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 6)

                    // Glow behind fill bar — breathing blue
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.tnAccent.opacity(breathe ? 0.3 : 0.1))
                        .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 6)
                        .blur(radius: 6)

                    // Fill bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.tnAccent,
                                    Color.tnAccent.opacity(0.25)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 6)

                    // Thumb — breathing glow shadow
                    Circle()
                        .fill(Color.tnAccent)
                        .frame(width: 12, height: 12)
                        .shadow(color: Color.tnAccent.opacity(breathe ? 0.6 : 0.25), radius: breathe ? 6 : 3)
                        .offset(x: max(0, geo.size.width * CGFloat(progress) - 6))
                        .opacity(isDragging ? 1 : 0.6)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = max(0, min(1, value.location.x / max(geo.size.width, 1)))
                            let newTime = ratio * effectiveDuration
                            isDragging = true
                            dragTime = newTime
                        }
                        .onEnded { value in
                            let ratio = max(0, min(1, value.location.x / max(geo.size.width, 1)))
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
            .frame(height: 28) // larger touch area

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
