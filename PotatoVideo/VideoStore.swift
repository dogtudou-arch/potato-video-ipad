import Combine
import Foundation

@MainActor
final class VideoStore: ObservableObject {
    @Published var query = ""
    @Published var history: [String]
    @Published var results: [Video] = []
    @Published var showingResults = false
    @Published var isSearching = false
    @Published var searchMessage = "没有找到结果"
    @Published var folders: [FavoriteFolder]

    private var searchTask: Task<Void, Never>?
    private static let historyKey = "search_history"
    private static let foldersKey = "favorite_folders"

    init() {
        history = Array((UserDefaults.standard.stringArray(forKey: Self.historyKey) ?? []).prefix(20))
        if let saved = UserDefaults.standard.data(forKey: Self.foldersKey),
           let decoded = try? JSONDecoder().decode([FavoriteFolder].self, from: saved) {
            folders = decoded
        } else {
            folders = []
        }
        _ = UsageWindow.isActive()
    }

    func clearSearch() {
        searchTask?.cancel()
        searchTask = nil
        showingResults = false
        isSearching = false
    }

    func search(_ term: String) {
        let value = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { clearSearch(); return }
        searchTask?.cancel()
        query = value
        showingResults = true
        results = []
        isSearching = false
        guard UsageWindow.isActive() else {
            searchMessage = "网络不可用"
            return
        }
        remember(value)
        searchMessage = "没有找到结果"
        isSearching = true
        searchTask = Task {
            var failed = 0
            await withTaskGroup(of: [Video]?.self) { group in
                for source in Source.all {
                    group.addTask { try? await VideoAPI.search(value, source: source) }
                }
                for await batch in group {
                    if Task.isCancelled { break }
                    if let batch {
                        results.append(contentsOf: batch)
                    } else {
                        failed += 1
                    }
                }
            }
            if !Task.isCancelled {
                searchMessage = failed == Source.all.count ? "所有片源请求失败，请检查网络或片源" : "没有找到结果"
                isSearching = false
            }
        }
    }

    func deleteHistory(_ value: String) {
        history.removeAll { $0 == value }
        UserDefaults.standard.set(history, forKey: Self.historyKey)
    }

    func clearHistory() {
        history = []
        UserDefaults.standard.set(history, forKey: Self.historyKey)
    }

    @discardableResult
    func createFolder(_ name: String) -> UUID? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let folder = FavoriteFolder(id: UUID(), name: cleaned, videos: [])
        folders.append(folder)
        saveFolders()
        return folder.id
    }

    func deleteFolder(_ id: UUID) {
        folders.removeAll { $0.id == id }
        saveFolders()
    }

    func clearFolders() {
        folders.removeAll()
        saveFolders()
    }

    func add(_ video: Video, to folderID: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }),
              !folders[index].videos.contains(where: { $0.id == video.id }) else { return }
        folders[index].videos.append(video)
        saveFolders()
    }

    func remove(_ video: Video, from folderID: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[index].videos.removeAll { $0.id == video.id }
        saveFolders()
    }

    func contains(_ video: Video, in folderID: UUID) -> Bool {
        folders.first(where: { $0.id == folderID })?.videos.contains(where: { $0.id == video.id }) ?? false
    }

    private func saveFolders() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: Self.foldersKey)
    }

    private func remember(_ value: String) {
        history.removeAll { $0 == value }
        history.insert(value, at: 0)
        history = Array(history.prefix(20))
        UserDefaults.standard.set(history, forKey: Self.historyKey)
    }
}
