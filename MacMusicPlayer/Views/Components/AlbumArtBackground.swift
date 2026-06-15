import SwiftUI

/// Full-width album art as background, with bottom fade to black and gentle breathing glow.
struct AlbumArtBackground: View {
    let artworkData: Data?
    var isAnimating: Bool = false

    @State private var breathe: Bool = false

    var body: some View {
        ZStack {
            // Album art image as full background (no border, no rounded corners)
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                // Fallback: pure dark background
                Color(red: 0.031, green: 0.031, blue: 0.055)
            }

            // Ambient glow overlay (breathing animation)
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .blur(radius: 60)
                    .opacity(0.25)
                    .scaleEffect(breathe ? 1.04 : 1.0)
                    .blendMode(.screen)
            } else {
                // Fallback accent glow
                Color.tnAccent
                    .opacity(0.12)
                    .blur(radius: 80)
                    .scaleEffect(breathe ? 1.06 : 1.0)
            }

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
