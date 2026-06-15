import Foundation
import AVFoundation

/// Parses audio file metadata using AVAsset.
/// Extracts title, artist, album, artwork image, and duration from embedded ID3 tags.
struct MetadataParser {

    struct Metadata {
        let title: String
        let artist: String
        let album: String
        let artworkData: Data?
        let duration: TimeInterval
    }

    /// Parse metadata from a local audio file URL.
    /// - Parameter url: File URL to an audio file (mp3, m4a, flac, wav, etc.)
    /// - Returns: Parsed metadata, or nil if the file can't be read.
    static func parse(from url: URL) async -> Metadata? {
        let asset = AVAsset(url: url)

        // Load metadata and duration concurrently
        let metadata: [AVMetadataItem]
        let duration: CMTime
        do {
            metadata = try await asset.load(.metadata)
            duration = try await asset.load(.duration)
        } catch {
            print("MetadataParser: failed to load asset metadata: \(error.localizedDescription)")
            return nil
        }

        let durationSeconds = CMTimeGetSeconds(duration)
        let validDuration = durationSeconds.isFinite && durationSeconds > 0 ? durationSeconds : 0

        // Extract common metadata using commonKey lookup
        let title = findMetadataItem(metadata: metadata, key: AVMetadataKey.commonKeyTitle)
            ?? url.deletingPathExtension().lastPathComponent
        let artist = findMetadataItem(metadata: metadata, key: AVMetadataKey.commonKeyArtist)
            ?? NSLocalizedString("Unknown Artist", comment: "Default artist name")
        let album = findMetadataItem(metadata: metadata, key: AVMetadataKey.commonKeyAlbumName)
            ?? NSLocalizedString("Unknown Album", comment: "Default album name")
        let artworkData = findArtwork(metadata: metadata)

        return Metadata(
            title: title,
            artist: artist,
            album: album,
            artworkData: artworkData,
            duration: validDuration
        )
    }

    // MARK: - Private Helpers

    private static func findMetadataItem(metadata: [AVMetadataItem], key: AVMetadataKey) -> String? {
        let item = metadata.first(where: { $0.commonKey == key })
        guard let value = item?.value else { return nil }
        // AVMetadataItem.value is NSObject, often NSString
        if let stringValue = value as? String, !stringValue.isEmpty {
            return stringValue
        }
        return nil
    }

    private static func findArtwork(metadata: [AVMetadataItem]) -> Data? {
        // Try common key for artwork
        let artItem = metadata.first(where: { $0.commonKey == .commonKeyArtwork })
        if let item = artItem {
            if let data = item.dataValue, data.count > 0 {
                return data
            }
            // Some formats store artwork as Data in the value
            if let value = item.value as? Data, value.count > 0 {
                return value
            }
        }
        return nil
    }
}
