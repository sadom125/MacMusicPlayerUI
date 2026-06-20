import SwiftUI

/// Dynamic Island style — covers the notch, expands on tap.
struct NotchPlayerView: View {
    @ObservedObject var player: PlayerManager
    @State private var isExpanded = false

    private var artworkData: Data? {
        if let data = player.currentTrack?.albumArtData { return data }
        guard let url = player.currentTrack?.url else { return nil }
        return MetadataParser.parseArtworkDirect(from: url)
    }

    var body: some View {
        if isExpanded {
            expandedView
                .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
        } else {
            collapsedView
                .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
        }
    }

    // MARK: - Collapsed: covers the notch, album art left, music wave right

    private var collapsedView: some View {
        HStack(spacing: 0) {
            // Left: album art
            if let data = artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Right: music wave indicator
            MusicWaveView()
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(
            NotchShape(topRadius: 10, bottomRadius: 18)
                .fill(Color.black)
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isExpanded = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NotchPlayerExpandChanged"),
                    object: nil,
                    userInfo: ["expanded": true]
                )
            }
        }
    }

    // MARK: - Expanded: drops down from notch with full info

    private var expandedView: some View {
        VStack(spacing: 0) {
            // Top bar (same height as collapsed, acts as connector to notch)
            HStack(spacing: 0) {
                if let data = artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
                MusicWaveView()
            }
            .padding(.horizontal, 14)
            .frame(height: 30)

            // Expanded content
            HStack(spacing: 16) {
                // Album art (large)
                if let data = artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.4))
                        )
                }

                // Track info
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.currentTrack?.title ?? "Not Playing")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(player.currentTrack?.artist ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Controls
                HStack(spacing: 22) {
                    Button(action: { player.playPrevious() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    Button(action: { player.isPlaying ? player.pause() : player.play() }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: { player.playNext() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(
            NotchShape(topRadius: 0, bottomRadius: 24)
                .fill(Color.black)
        )
        .onTapGesture {
            // Tap on expanded area collapses
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isExpanded = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NotchPlayerExpandChanged"),
                    object: nil,
                    userInfo: ["expanded": false]
                )
            }
        }
    }
}

// MARK: - Music Wave Animation

struct MusicWaveView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 2, height: animating ? CGFloat.random(in: 4...10) : 3)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.1),
                        value: animating
                    )
            }
        }
        .frame(height: 12)
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Notch Shape (matches hardware notch rounded corners)

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Top edge — flat (aligns with screen top / notch top)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // Right edge — round bottom-right
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addArc(
            center: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: true
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: true
        )

        // Left edge — round top-left
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topRadius))
        if topRadius > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius),
                radius: topRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: true
            )
        }

        path.closeSubpath()
        return path
    }
}
