import SwiftUI

/// Full-width album art as background, with bottom fade to black and gentle breathing glow.
struct AlbumArtBackground: View {
    let artworkData: Data?
    var isAnimating: Bool = false

    @State private var breathe: Bool = false

    var body: some View {
        ZStack {
            // Album art image — semi-transparent so glass effect shows through
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.5)
            } else {
                Color.clear
            }

            // Ambient glow overlay (breathing animation)
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 60)
                    .opacity(0.2)
                    .scaleEffect(breathe ? 1.04 : 1.0)
                    .blendMode(.screen)
            } else {
                Color.tnAccent
                    .opacity(0.08)
                    .blur(radius: 80)
                    .scaleEffect(breathe ? 1.06 : 1.0)
            }

            // Subtle dark overlay for text readability
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(0.15), location: 0.5),
                    .init(color: .black.opacity(0.3), location: 1.0)
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
