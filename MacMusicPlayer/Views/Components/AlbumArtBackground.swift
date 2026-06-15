import SwiftUI

/// Full-width background gradient that simulates album art colors bleeding into the dark background.
/// Takes the dominant color from the album art and creates a smooth fade to pure black.
struct AlbumArtBackground: View {
    let accentColor: Color
    var isAnimating: Bool = false

    @State private var breathe: Bool = false

    var body: some View {
        ZStack {
            // Main color wash
            accentColor
                .opacity(0.12)
                .blur(radius: 80)
                .scaleEffect(breathe ? 1.06 : 1.0)

            // Secondary purple wash
            accentColor
                .opacity(0.05)
                .blur(radius: 120)
                .offset(x: 30, y: -20)
                .scaleEffect(breathe ? 1.1 : 1.0)

            // Fade to black at bottom
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: .black.opacity(0.5), location: 0.6),
                    .init(color: .black, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}
