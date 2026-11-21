import SwiftUI

@MainActor final class LocalLibrary: ObservableObject {
    @Published private(set) var favorites: [BiliVideo]
    @Published private(set) var history: [BiliVideo]
    init() {
        func read(_ key: String) -> [BiliVideo] {
            guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
            return (try? JSONDecoder().decode([BiliVideo].self, from: data)) ?? []
        }
        favorites = read("favorites")
        history = read("history")
    }
    func contains(_ video: BiliVideo) -> Bool { favorites.contains { $0.id == video.id } }
    func toggle(_ video: BiliVideo) {
        if contains(video) { favorites.removeAll { $0.id == video.id } }
        else { favorites.insert(video, at: 0) }
        UserDefaults.standard.set(try? JSONEncoder().encode(favorites), forKey: "favorites")
    }
    func watched(_ video: BiliVideo) {
        history.removeAll { $0.id == video.id }
        history.insert(video, at: 0)
        UserDefaults.standard.set(try? JSONEncoder().encode(history), forKey: "history")
    }
}
