import Foundation

/// Result of a successful metadata save.
struct SavedMetadata {
    let title: String
    let artist: String
    let album: String
    let artworkData: Data?
    let lyrics: String?
}

/// Writes metadata back to audio files using ffmpeg.
///
/// ffmpeg can re-mux metadata without re-encoding (`-c copy`), making it fast
/// for most formats. For DSD files (DFF/DSF) ffmpeg writes a temporary WAV
/// which is not suitable — those files are handled as read-only.
struct MetadataWriter {

    /// Save new metadata to an audio file.
    /// - Parameters:
    ///   - url: Original file URL
    ///   - originalTrack: The current Track object (used for unchanged fields)
    ///   - title: New title (nil = keep existing)
    ///   - artist: New artist (nil = keep existing)
    ///   - album: New album (nil = keep existing)
    ///   - artworkData: New cover image data (nil = keep existing)
    ///   - removeExistingArtwork: true to strip all attached pictures
    ///   - lyrics: New lyrics text (nil = keep existing)
    /// - Returns: SavedMetadata on success, nil on failure.
    static func save(
        to url: URL,
        originalTrack: Track,
        title: String?,
        artist: String?,
        album: String?,
        artworkData: Data?,
        removeExistingArtwork: Bool = false,
        lyrics: String?
    ) async -> SavedMetadata? {
        let ext = url.pathExtension.lowercased()

        // DSD files are read-only (ffmpeg would convert to WAV, not acceptable)
        guard ext != "dff", ext != "dsf" else {
            print("MetadataWriter: DSD files are read-only")
            return nil
        }

        // Build ffmpeg arguments
        // Order matters: ALL -i come first, then output options, then output file
        var args: [String] = ["-y", "-i", url.path]

        // Optional artwork input
        let artworkPath: String?
        if let artData = artworkData {
            let tempArt = NSTemporaryDirectory() + UUID().uuidString + ".jpg"
            do {
                try artData.write(to: URL(fileURLWithPath: tempArt))
                artworkPath = tempArt
            } catch {
                print("MetadataWriter: failed to write temp artwork: \(error)")
                artworkPath = nil
            }
        } else {
            artworkPath = nil
        }
        if let artPath = artworkPath {
            args += ["-i", artPath]
        }

        // --- Output options (after all inputs) ---

        // Preserve original file metadata, then override changed fields
        args += ["-map_metadata", "0"]

        // Write text metadata tags
        if let t = title { args += ["-metadata", "title=\(t)"] }
        if let a = artist { args += ["-metadata", "artist=\(a)"] }
        if let al = album { args += ["-metadata", "album=\(al)"] }

        // Lyrics
        if let lyr = lyrics, !lyr.isEmpty {
            args += ["-metadata", "LYRICS=\(lyr)"]
            if ext == "m4a" || ext == "mp4" {
                args += ["-metadata", "lyrics=\(lyr)"]
            }
        } else if lyrics != nil {
            args += ["-metadata", "LYRICS="]
            if ext == "m4a" || ext == "mp4" {
                args += ["-metadata", "lyrics="]
            }
        }

        // Stream mapping + codec
        // Use -map 0:a to exclude old attached pictures from input 0
        if let artPath = artworkPath {
            // Replace cover: audio from original + new picture
            args += ["-map", "0:a", "-map", "1:v",
                     "-c", "copy", "-disposition:v", "attached_pic"]
        } else if removeExistingArtwork {
            // Remove cover: audio only, drop all video streams
            args += ["-map", "0:a", "-c", "copy", "-vn"]
        } else {
            // Keep existing: copy everything as-is
            args += ["-c", "copy"]
        }

        // Temp output file
        let tempPath = NSTemporaryDirectory() + UUID().uuidString + "." + ext
        args += [tempPath]

        // Run ffmpeg — capture stderr for diagnostics
        NSLog("MetadataWriter: ffmpeg args: %@", args.joined(separator: " "))
        print("MetadataWriter: ffmpeg args: \(args.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            NSLog("MetadataWriter: failed to launch ffmpeg: %@", error.localizedDescription)
            print("MetadataWriter: failed to launch ffmpeg: \(error)")
            if let art = artworkPath { try? FileManager.default.removeItem(atPath: art) }
            return nil
        }

        // Always capture stderr for diagnostics
        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let errStr = String(data: errData, encoding: .utf8) ?? "unknown error"
        print("MetadataWriter: ffmpeg stderr:\n\(errStr)")
        NSLog("MetadataWriter: ffmpeg exit code: %d, stderr: %@",
              process.terminationStatus,
              errStr.prefix(2000) as NSString)

        guard process.terminationStatus == 0 else {
            NSLog("MetadataWriter: ffmpeg failed (code %d)", process.terminationStatus)
            try? FileManager.default.removeItem(atPath: tempPath)
            if let art = artworkPath { try? FileManager.default.removeItem(atPath: art) }
            return nil
        }

        // Clean up temp artwork
        if let art = artworkPath { try? FileManager.default.removeItem(atPath: art) }

        // Verify temp file exists and has content
        guard let tempSize = try? FileManager.default.attributesOfItem(atPath: tempPath)[.size] as? Int,
              tempSize > 0 else {
            try? FileManager.default.removeItem(atPath: tempPath)
            return nil
        }

        // Replace original with new file
        do {
            try FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: URL(fileURLWithPath: tempPath), to: url)
        } catch {
            print("MetadataWriter: failed to replace file: \(error)")
            try? FileManager.default.removeItem(atPath: tempPath)
            return nil
        }

        // Read back the new artwork from the saved file
        var newArtwork: Data? = nil
        if artworkData != nil {
            if ext == "flac" {
                newArtwork = MetadataParser.parseArtworkDirect(from: url)
            }
            if newArtwork == nil {
                newArtwork = artworkData
            }
        }

        // Use original track values for unchanged fields
        return SavedMetadata(
            title: title ?? originalTrack.title,
            artist: artist ?? originalTrack.artist,
            album: album ?? originalTrack.album,
            artworkData: removeExistingArtwork ? nil : (newArtwork ?? originalTrack.albumArtData),
            lyrics: lyrics ?? originalTrack.lyrics
        )
    }
}
