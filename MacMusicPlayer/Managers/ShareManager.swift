import SwiftUI
import AppKit

/// Manages share operations: text sharing via NSSharingServicePicker and screenshot image generation.
@MainActor
final class ShareManager {

    // MARK: - Share Song Info (Text)

    /// Assemble track info as share text and present the system share sheet.
    static func shareSongInfo(_ track: Track) {
        var text = track.title
        if !track.artist.isEmpty {
            text += " — \(track.artist)"
        }
        if !track.album.isEmpty {
            text += "（\(track.album)）"
        }

        let picker = NSSharingServicePicker(items: [text])
        showPicker(picker)
    }

    // MARK: - Share Lyrics Screenshot

    /// Generate a share-card image from the current track and lyrics, then present the system share sheet.
    static func shareLyricsCard(_ track: Track, currentLyricLine: String) {
        guard let image = generateShareImage(track: track, lyricLine: currentLyricLine) else {
            NSSound.beep()
            return
        }

        let picker = NSSharingServicePicker(items: [image])
        showPicker(picker)
    }

    // MARK: - Image Generation

    /// Generate a stylised share-card image using an off-screen NSHostingView.
    /// Falls back gracefully when rendering fails.
    /// - Parameters:
    ///   - track: The track whose info appears on the card
    ///   - lyricLine: Current lyric text to display
    /// - Returns: An NSImage, or nil if rendering fails
    static func generateShareImage(track: Track, lyricLine: String) -> NSImage? {
        let cardView = ShareCardView(
            title: track.title,
            artist: track.artist,
            album: track.album,
            artworkData: track.albumArtData,
            lyricsText: lyricLine
        )

        let hostingView = NSHostingView(rootView: cardView)
        let cardSize = CGSize(width: ShareCardView.cardWidth, height: ShareCardView.cardHeight)
        hostingView.frame = CGRect(origin: .zero, size: cardSize)
        hostingView.setFrameSize(cardSize)

        // Render to PDF data, then convert to bitmap image
        let pdfData = hostingView.dataWithPDF(inside: hostingView.bounds)

        // Create a bitmap image from the PDF data
        guard let pdfImageRep = NSPDFImageRep(data: pdfData) else { return nil }

        let image = NSImage(size: cardSize)
        image.lockFocus()
        pdfImageRep.draw(in: NSRect(origin: .zero, size: cardSize))
        image.unlockFocus()

        // Add rounded corners via masking
        let finalImage = NSImage(size: cardSize, flipped: false) { dstRect in
            let path = NSBezierPath(roundedRect: dstRect, xRadius: 16, yRadius: 16)
            path.addClip()
            image.draw(in: dstRect)
            return true
        }

        return finalImage
    }

    // MARK: - Helpers

    private static func showPicker(_ picker: NSSharingServicePicker) {
        if let contentView = NSApp.keyWindow?.contentView {
            // Show from the top-center of the window content area
            let anchorRect = NSRect(
                x: contentView.bounds.midX - 1,
                y: contentView.bounds.maxY - 1,
                width: 2,
                height: 2
            )
            picker.show(relativeTo: anchorRect, of: contentView, preferredEdge: .minY)
        }
    }
}
