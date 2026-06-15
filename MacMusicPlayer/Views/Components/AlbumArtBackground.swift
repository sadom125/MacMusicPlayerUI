//
//  AlbumArtBackground.swift
//  MacMusicPlayer
//
//  Full-bleed album art background with breathing glow.
//  Supports album art or solid color background modes.
//

import SwiftUI

struct AlbumArtBackground: View {
    let artworkData: Data?
    let trackID: UUID?
    var isAnimating: Bool = false
    var solidColor: Color? = nil

    @State private var breathe: Bool = false
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var artworkDestroyed: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Solid color background mode
                if let color = solidColor {
                    color
                }
                // Album art mode — destroyed during zoom, recreated after
                else if !artworkDestroyed, let data = artworkData, let nsImage = NSImage(data: data) {
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

                // Breathing glow overlay — only for album art mode
                if solidColor == nil, !artworkDestroyed, artworkData != nil {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.accent.opacity(0.15 * (breathe ? 1 : 0.5)),
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
            artworkDestroyed = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .windowDidZoom)) { _ in
            artworkDestroyed = false
        }
    }
}
