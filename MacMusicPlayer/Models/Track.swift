import Foundation

struct Track: Identifiable, Equatable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let albumArtData: Data?
    let duration: TimeInterval
    let url: URL
}
