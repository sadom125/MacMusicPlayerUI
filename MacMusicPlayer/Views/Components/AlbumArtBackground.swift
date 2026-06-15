//
//  AlbumArtBackground.swift
//  MacMusicPlayer
//
//  Full-bleed album art background with breathing glow.
//  Destroys artwork during window zoom to avoid layout glitch,
//  then recreates at the correct maximized size.
//

import SwiftUI

struct AlbumArtBackground: View {
    let artworkData: Data?
    let trackID: UUID?
    var isAnimating: Bool = false

    @State private var breathe: Bool = false
    @ObservedObject var themeManager = ThemeManager.shared
    /// When true, artwork is completely removed (not just hidden)
    /// so SwiftUI destroys the Image view. After zoom completes,
    /// it's recreated at the correct size.
    @State private var artworkDestroyed: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Album art — destroyed during zoom, recreated after
                if !artworkDestroyed, let data = artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(0.5)
                        .transition(.opacity)
                } else {
                    Color.clear
                }

                // Breathing glow overlay
                if !artworkDestroyed, artworkData != nil {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ThemeManager.shared.accent.opacity(0.15 * (breathe ? 1 : 0.5)),
                                    Color.clear,
                                ],
                                center: .center,
                                startRadius: geo.size.width * 0.1,
                                endRadius: geo.size.width * 0.6
                            )
                        )
                        .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.9)
                        .blur(radius: 60)
                        .offset(y: -20)
                        .allowsHitTesting(false)
                }

                // Bottom gradient fade
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.6),
                            Color.black.opacity(0.2),
                            Color.clear,
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: geo.size.height * 0.45)
                }
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: trackID)
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .windowWillZoom)) { _ in
            // Destroy artwork BEFORE zoom animation starts
            artworkDestroyed = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .windowDidZoom)) { _ in
            // Recreate artwork after zoom animation completes
            artworkDestroyed = false
        }
    }
}

#Preview {
    ZStack {
        AlbumArtBackground(artworkData: nil, trackID: nil)
        Text("Album Art Background")
            .foregroundColor(.white)
    }
    .frame(width: 600, height: 400)
}
