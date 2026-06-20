import Foundation
import AVFoundation

/// Parses audio file metadata using AVAsset.
/// Extracts title, artist, album, artwork image, duration, and lyrics from embedded tags.
struct MetadataParser {

    struct Metadata {
        let title: String
        let artist: String
        let album: String
        let artworkData: Data?
        let duration: TimeInterval
        let lyrics: String?          // embedded LRC lyrics (FLAC Vorbis LYRICS tag)
    }

    /// Parse metadata from a local audio file URL.
    /// - Parameter url: File URL to an audio file (mp3, m4a, flac, wav, etc.)
    /// - Returns: Parsed metadata, or nil if the file can't be read.
    static func parse(from url: URL) async -> Metadata? {
        let ext = url.pathExtension.lowercased()
        let asset = AVAsset(url: url)

        // Load metadata and duration concurrently
        let metadata: [AVMetadataItem]
        let duration: CMTime
        do {
            metadata = try await asset.load(.metadata)
            duration = try await asset.load(.duration)
        } catch {
            // For DFF/DSF files, AVAsset can't read DSD — fall back to ffmpeg
            if ext == "dff" || ext == "dsf" {
                return parseDSDViaFFmpeg(url: url)
            }
            print("MetadataParser: failed to load asset metadata: \(error.localizedDescription)")
            return nil
        }

        let durationSeconds = CMTimeGetSeconds(duration)
        let validDuration = durationSeconds.isFinite && durationSeconds > 0 ? durationSeconds : 0

        // Extract common metadata using commonKey lookup
        let rawTitle = findMetadataItem(metadata: metadata, key: AVMetadataKey.commonKeyTitle)
        let rawArtist = findMetadataItem(metadata: metadata, key: AVMetadataKey.commonKeyArtist)

        // If no embedded metadata, parse from filename: "歌名 - 歌手" or "歌名-歌手"
        let filename = url.deletingPathExtension().lastPathComponent
        var title: String
        var artist: String

        if let t = rawTitle, let a = rawArtist {
            title = t
            artist = a
        } else if let range = filename.range(of: " - ") {
            title = String(filename[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            artist = String(filename[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let range = filename.range(of: "-") {
            title = String(filename[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            artist = String(filename[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else {
            title = rawTitle ?? filename
            artist = rawArtist ?? NSLocalizedString("Unknown Artist", comment: "Default artist name")
        }
        let album = findMetadataItem(metadata: metadata, key: AVMetadataKey.commonKeyAlbumName)
            ?? NSLocalizedString("Unknown Album", comment: "Default album name")
        let artworkData = findArtwork(metadata: metadata) ?? extractArtworkViaFFmpeg(url: url)
        let lyrics = findLyrics(metadata: metadata) ?? extractLyricsViaFFmpeg(url: url)

        return Metadata(
            title: title,
            artist: artist,
            album: album,
            artworkData: artworkData,
            duration: validDuration,
            lyrics: lyrics
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
                // FLAC METADATA_BLOCK_PICTURE wraps the image in a Vorbis comment header.
                // Try to extract the raw image data from the block.
                return extractImageFromVorbisPictureBlock(data) ?? data
            }
            // Some formats store artwork as Data in the value
            if let value = item.value as? Data, value.count > 0 {
                return extractImageFromVorbisPictureBlock(value) ?? value
            }
        }
        return nil
    }

    /// Extract raw image data from FLAC METADATA_BLOCK_PICTURE format.
    /// Format: pictureType(4) + mimeLen(4) + mime(mimeLen) + descLen(4) + desc(descLen)
    ///         + width(4) + height(4) + colorDepth(4) + numColors(4) + dataLen(4) + imageData(dataLen)
    private static func extractImageFromVorbisPictureBlock(_ data: Data) -> Data? {
        guard data.count > 4 else { return nil }

        // If data already starts with JPEG/PNG magic, it's raw image data — return as-is
        let first3 = data.prefix(3)
        let first4 = data.prefix(4)
        if first3 == Data([0xFF, 0xD8, 0xFF]) || // JPEG
           first4 == Data([0x89, 0x50, 0x4E, 0x47]) { // PNG
            return data
        }

        // Otherwise, try to parse as Vorbis METADATA_BLOCK_PICTURE
        guard data.count > 32 else { return nil }

        var offset = 0
        func readUInt32() -> UInt32? {
            guard offset + 4 <= data.count else { return nil }
            let value = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
            offset += 4
            return value.byteSwapped  // FLAC uses big-endian
        }

        guard let pictureType = readUInt32(), pictureType <= 21 else { return nil }
        guard let mimeLen = readUInt32(), offset + Int(mimeLen) <= data.count else { return nil }
        offset += Int(mimeLen)  // skip MIME type
        guard let descLen = readUInt32(), offset + Int(descLen) <= data.count else { return nil }
        offset += Int(descLen)  // skip description
        _ = readUInt32()  // width
        _ = readUInt32()  // height
        _ = readUInt32()  // color depth
        _ = readUInt32()  // number of indexed colors
        guard let dataLen = readUInt32(), offset + Int(dataLen) <= data.count else { return nil }

        let imageData = data.subdata(in: offset..<offset + Int(dataLen))
        // Verify it's a valid image by checking magic bytes
        guard imageData.count > 4 else { return nil }
        let imgFirst3 = imageData.prefix(3)
        let imgFirst4 = imageData.prefix(4)
        if imgFirst3 == Data([0xFF, 0xD8, 0xFF]) || // JPEG
           imgFirst4 == Data([0x89, 0x50, 0x4E, 0x47]) { // PNG
            return imageData
        }
        return nil
    }

    /// Extract embedded LRC lyrics from Vorbis comment (FLAC) or ID3 USLT tag.
    private static func findLyrics(metadata: [AVMetadataItem]) -> String? {
        // FLAC Vorbis comment stores lyrics with key "LYRICS" (no commonKey)
        for item in metadata {
            if let strKey = item.key as? String, strKey.uppercased() == "LYRICS",
               let value = item.value as? String, !value.isEmpty {
                return value
            }
        }
        // Also try common key for lyrics (used by some formats)
        if let item = metadata.first(where: { $0.commonKey?.rawValue == "lyrics" }),
           let value = item.value as? String, !value.isEmpty {
            return value
        }
        return nil
    }

    /// Extract embedded artwork using ffmpeg as a fallback when AVAsset can't read it.
    /// Some FLAC files store artwork in a format AVAsset doesn't recognize.
    private static func extractArtworkViaFFmpeg(url: URL) -> Data? {
        let tempPath = NSTemporaryDirectory() + UUID().uuidString + ".jpg"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        process.arguments = ["-i", url.path, "-an", "-vcodec", "copy", "-y", tempPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = try? Data(contentsOf: URL(fileURLWithPath: tempPath))
        try? FileManager.default.removeItem(atPath: tempPath)
        return data
    }

    /// Fallback: parse all metadata from DFF/DSF via ffmpeg when AVAsset fails.
    private static func parseDSDViaFFmpeg(url: URL) -> Metadata? {
        let filename = url.deletingPathExtension().lastPathComponent
        var title = filename
        var artist = NSLocalizedString("Unknown Artist", comment: "")
        var album = NSLocalizedString("Unknown Album", comment: "")
        var lyrics: String?

        // Parse "歌名 - 歌手" or "歌名-歌手" from filename
        if let range = filename.range(of: " - ") {
            title = String(filename[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            artist = String(filename[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let range = filename.range(of: "-") {
            title = String(filename[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            artist = String(filename[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        // Get ffmetadata for title/artist/album/lyrics
        let metaProcess = Process()
        metaProcess.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        metaProcess.arguments = ["-i", url.path, "-f", "ffmetadata", "-"]
        let metaPipe = Pipe()
        metaProcess.standardOutput = metaPipe
        metaProcess.standardError = FileHandle.nullDevice
        do {
            try metaProcess.run()
            metaProcess.waitUntilExit()
        } catch {
            return nil
        }
        if metaProcess.terminationStatus == 0,
           let output = String(data: metaPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
            for line in output.components(separatedBy: .newlines) {
                if line.hasPrefix("title=") {
                    let v = String(line.dropFirst("title=".count))
                    if !v.isEmpty { title = v }
                } else if line.hasPrefix("artist=") {
                    let v = String(line.dropFirst("artist=".count))
                    if !v.isEmpty { artist = v }
                } else if line.hasPrefix("album=") {
                    let v = String(line.dropFirst("album=".count))
                    if !v.isEmpty { album = v }
                } else if line.hasPrefix("LYRICS=") {
                    let v = String(line.dropFirst("LYRICS=".count))
                    if !v.isEmpty { lyrics = v }
                }
            }
        }

        // Get duration via ffprobe
        var duration: TimeInterval = 0
        let durProcess = Process()
        durProcess.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffprobe")
        durProcess.arguments = ["-v", "quiet", "-show_entries", "format=duration", "-of", "csv=p=0", url.path]
        let durPipe = Pipe()
        durProcess.standardOutput = durPipe
        durProcess.standardError = FileHandle.nullDevice
        do {
            try durProcess.run()
            durProcess.waitUntilExit()
        } catch {}
        if durProcess.terminationStatus == 0,
           let durStr = String(data: durPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let dur = Double(durStr), dur.isFinite {
            duration = dur
        }

        // Extract artwork via ffmpeg
        let artworkData = extractArtworkViaFFmpeg(url: url)

        return Metadata(
            title: title,
            artist: artist,
            album: album,
            artworkData: artworkData,
            duration: duration,
            lyrics: lyrics
        )
    }

    /// Extract embedded lyrics using ffmpeg for formats AVAsset can't read (DFF/DSF/DSD).
    private static func extractLyricsViaFFmpeg(url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        guard ext == "dff" || ext == "dsf" else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        process.arguments = ["-i", url.path, "-f", "ffmetadata", "-"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else { return nil }

        // Look for LYRICS= tag in ffmpeg metadata output
        for line in output.components(separatedBy: .newlines) {
            if line.hasPrefix("LYRICS=") {
                let lyrics = String(line.dropFirst("LYRICS=".count))
                return lyrics.isEmpty ? nil : lyrics
            }
        }
        return nil
    }

    /// Synchronously read LYRICS tag from a FLAC file by scanning raw Vorbis comments.
    /// Used as a direct fallback when async AVAsset metadata is not yet available.
    static func parseLyricsDirect(from url: URL) -> String? {
        guard url.pathExtension.lowercased() == "flac" else { return nil }
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fileHandle.close() }

        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int else { return nil }
        let readSize = min(1024 * 512, size)
        guard let data = try? fileHandle.read(upToCount: readSize), data.count > 42 else { return nil }

        // Search for "LYRICS=" in raw bytes (Vorbis comment stores as field=value)
        let pattern = "LYRICS=".data(using: .utf8)!
        var searchStart = 0
        while searchStart <= data.count - pattern.count {
            if data[searchStart..<searchStart + pattern.count] == pattern {
                let start = searchStart + pattern.count
                var end = start
                while end < data.count, data[end] != 0 {
                    end += 1
                }
                if end > start {
                    return String(data: data[start..<end], encoding: .utf8)
                }
            }
            searchStart += 1
        }
        return nil
    }

    /// Synchronously read album art (METADATA_BLOCK_PICTURE) from a FLAC file.
    /// Used as a direct fallback when async AVAsset metadata is not yet available.
    static func parseArtworkDirect(from url: URL) -> Data? {
        guard url.pathExtension.lowercased() == "flac" else { return nil }
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fileHandle.close() }

        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int else { return nil }
        let readSize = min(1024 * 512, size)
        guard let data = try? fileHandle.read(upToCount: readSize), data.count > 42 else { return nil }

        // Search for JPEG/PNG magic bytes in the raw FLAC data
        // JPEG magic: FF D8 FF
        // PNG magic:  89 50 4E 47
        for i in 0..<(data.count - 3) {
            if data[i] == 0xFF, data[i+1] == 0xD8, data[i+2] == 0xFF {
                return Data(data[i..<data.count])
            }
        }
        for i in 0..<(data.count - 4) {
            if data[i] == 0x89, data[i+1] == 0x50, data[i+2] == 0x4E, data[i+3] == 0x47 {
                return Data(data[i..<data.count])
            }
        }
        return nil
    }
}
