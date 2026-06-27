//
//  AlbumArtBackground.swift
//  MacMusicPlayer
//
//  Full-bleed album art background with breathing glow.
//  Supports album art, solid color, and dynamic gradient background modes.
//  Adapts to light/dark mode.
//

import SwiftUI

/// Full-bleed album art background with breathing glow.
/// Supports album art, solid color, and dynamic gradient background modes.
struct AlbumArtBackground: View {
    let artworkData: Data?
    let trackID: UUID?
    var isAnimating: Bool = false
    var solidColor: Color? = nil
    var useDynamicGradient: Bool = true

    @State private var breathe: Bool = false
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var artworkDestroyed: Bool = false
    @State private var dominantColor: Color = Color(red: 0.1, green: 0.1, blue: 0.15)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dynamic gradient background (default)
                if useDynamicGradient, let data = artworkData {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
                // Solid color background mode
                else if let color = solidColor {
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
                        .opacity(artworkOpacity)
                        .transition(.opacity)
                } else {
                    // Transparent fallback — glass shows through
                    Color.clear
                }

                // Breathing glow overlay — only for album art mode
                if solidColor == nil, !artworkDestroyed, artworkData != nil, useDynamicGradient {
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
                        colors: bottomGradientColors,
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: geo.size.height * 0.45)
                }
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: trackID)
        .animation(.easeInOut(duration: 0.3), value: themeManager.isDarkMode)
        .onAppear {
            updateBreatheAnimation()
            extractDominantColor()
        }
        .onChange(of: isAnimating) { _ in
            updateBreatheAnimation()
        }
        .onChange(of: artworkData != nil) { _ in
            updateBreatheAnimation()
        }
        .onChange(of: trackID) { _ in
            extractDominantColor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .windowWillZoom)) { _ in
            artworkDestroyed = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .windowDidZoom)) { _ in
            artworkDestroyed = false
        }
    }

    // MARK: - Theme-adaptive colors

    private var gradientColors: [Color] {
        if themeManager.isDarkMode {
            return [
                dominantColor.opacity(0.3),
                dominantColor.opacity(0.15),
                dominantColor.opacity(0.05),
                Color.clear,
            ]
        } else {
            return [
                dominantColor.opacity(0.25),
                dominantColor.opacity(0.12),
                dominantColor.opacity(0.04),
                Color.clear,
            ]
        }
    }

    private var artworkOpacity: Double {
        themeManager.isDarkMode ? 0.25 : 0.3
    }

    private var bottomGradientColors: [Color] {
        if themeManager.isDarkMode {
            return [
                Color.black.opacity(0.2),
                Color.black.opacity(0.05),
                Color.clear,
            ]
        } else {
            return [
                Color.white.opacity(0.15),
                Color.white.opacity(0.04),
                Color.clear,
            ]
        }
    }

    /// Start/stop the breathing glow animation based on playback state.
    /// Keeps the animation paused when not playing to save GPU cycles.
    private func updateBreatheAnimation() {
        // Reset breathe state each time
        breathe = false
        if isAnimating, artworkData != nil, useDynamicGradient {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    private func extractDominantColor() {
        guard let trackID = trackID else { return }
        dominantColor = ColorExtractor.shared.dominantColor(from: artworkData, for: trackID)
    }
}
