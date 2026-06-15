import Foundation

struct Track: Identifiable, Equatable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let albumArtData: Data?
    let duration: TimeInterval
    let url: URL
    let lyrics: String?      // embedded LRC lyrics (e.g. FLAC Vorbis LYRICS tag)
}
