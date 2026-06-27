import Foundation

extension Notification.Name {
    // MARK: - Playback
    static let trackChanged = Notification.Name("TrackChanged")
    static let playbackStateChanged = Notification.Name("PlaybackStateChanged")
    static let playModeChanged = Notification.Name("PlayModeChanged")
    static let currentTrackMetadataUpdated = Notification.Name("CurrentTrackMetadataUpdated")
    static let trackFinished = Notification.Name("TrackFinished")

    // MARK: - Playlist
    static let playlistUpdated = Notification.Name("PlaylistUpdated")
    static let focusPlaylistSearch = Notification.Name("FocusPlaylistSearch")
    static let clearPlaylistSearch = Notification.Name("ClearPlaylistSearch")

    // MARK: - Library
    static let refreshMusicLibrary = Notification.Name("RefreshMusicLibrary")
    static let addNewLibrary = Notification.Name("AddNewLibrary")

    // MARK: - Config
    static let configUpdated = Notification.Name("ConfigUpdated")

    // MARK: - Metadata Editor
    static let trackMetadataEdited = Notification.Name("TrackMetadataEdited")

    // MARK: - Window
    static let windowWillZoom = Notification.Name("MainPlayerWindowWillZoom")
    static let windowDidZoom = Notification.Name("MainPlayerWindowDidZoom")
}
