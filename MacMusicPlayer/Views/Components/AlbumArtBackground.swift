import SwiftUI
import AppKit

/// Full-width album art as background, with bottom fade to black and gentle breathing glow.
struct AlbumArtBackground: View {
    let artworkData: Data?
    let trackID: UUID?
    var isAnimating: Bool = false

    @State private var breathe: Bool = false

    /// Create NSImage directly from data — works because this runs in the view body on main thread.
    private var currentImage: NSImage? {
        guard let data = artworkData else { return nil }
        return NSImage(data: data)
    }

    var body: some View {
        ZStack {
            // Album art image — semi-transparent so glass effect shows through
            if let image = currentImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.5)
                    .transition(.opacity)
            } else {
                Color.clear
                    .transition(.opacity)
            }

            // Ambient glow overlay (breathing animation)
            if let image = currentImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 60)
                    .opacity(0.2)
                    .scaleEffect(breathe ? 1.04 : 1.0)
                    .blendMode(.screen)
                    .transition(.opacity)
            } else {
                Color.tnAccent
                    .opacity(0.08)
                    .blur(radius: 80)
                    .scaleEffect(breathe ? 1.06 : 1.0)
                    .transition(.opacity)
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
        .animation(.easeInOut(duration: 0.5), value: trackID)
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}
