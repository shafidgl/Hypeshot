import AppKit
import SwiftUI

/// Remembers the user's default save folder across launches. The sandbox
/// only re-grants access to a user-picked folder through a security-scoped
/// bookmark, so that's what gets persisted — never a bare path.
@MainActor
final class SaveLocationStore: ObservableObject {
    static let shared = SaveLocationStore()

    private static let defaultsKey = "saveFolderBookmark"

    /// nil means "ask where to save each time".
    @Published private(set) var folderURL: URL?

    private init() {
        folderURL = Self.resolveBookmark()
    }

    func chooseFolder(completion: @escaping (Bool) -> Void = { _ in }) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Use This Folder"
        panel.message = "Screenshots will be saved here without asking."
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else {
                completion(false)
                return
            }
            do {
                let bookmark = try url.bookmarkData(options: .withSecurityScope,
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: Self.defaultsKey)
                self.folderURL = url
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
        folderURL = nil
    }

    /// Runs `body` with security-scoped access to the saved folder.
    /// Returns nil when no folder is configured or access fails.
    func withAccess<T>(_ body: (URL) throws -> T) -> T? {
        guard let url = folderURL else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        return try? body(url)
    }

    private static func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                 options: .withSecurityScope,
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            return nil
        }
        if stale, let refreshed = try? url.bookmarkData(options: .withSecurityScope,
                                                        includingResourceValuesForKeys: nil,
                                                        relativeTo: nil) {
            UserDefaults.standard.set(refreshed, forKey: defaultsKey)
        }
        return url
    }
}
