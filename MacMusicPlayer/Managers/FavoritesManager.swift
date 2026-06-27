import Foundation

/// 收藏管理 — 按 URL 路径持久化，支持跨会话保留
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    static let favoritesDidChangeNotification = Notification.Name("FavoritesDidChange")

    private let favoritesKey = "FavoriteTrackURLs"

    @Published var favoriteURLs: Set<String> = []

    private init() {
        loadFromStorage()
    }

    /// 收藏/取消收藏
    func toggle(_ track: Track) {
        if favoriteURLs.contains(track.url.path) {
            favoriteURLs.remove(track.url.path)
        } else {
            favoriteURLs.insert(track.url.path)
        }
        saveToStorage()
        notifyChange()
    }

    /// 检查是否已收藏
    func isFavorite(_ track: Track) -> Bool {
        favoriteURLs.contains(track.url.path)
    }

    /// 从当前播放列表中筛选出收藏的歌曲
    func getFavoriteTracks(from playlist: [Track]) -> [Track] {
        playlist.filter { favoriteURLs.contains($0.url.path) }
    }

    /// 收藏总数
    var count: Int { favoriteURLs.count }

    // MARK: - Persistence

    private func saveToStorage() {
        UserDefaults.standard.set(Array(favoriteURLs), forKey: favoritesKey)
    }

    private func loadFromStorage() {
        if let urls = UserDefaults.standard.stringArray(forKey: favoritesKey) {
            favoriteURLs = Set(urls)
        }
    }

    private func notifyChange() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            NotificationCenter.default.post(name: Self.favoritesDidChangeNotification, object: nil)
        }
    }
}
