import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Keeps recent captures on disk (Application Support/History) so Pro users
/// can revisit them. Screenshots are written for everyone; the History UI is
/// what's Pro-gated, so a user who upgrades later finds their backlog waiting.
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    struct Entry: Identifiable, Equatable {
        let id: UUID
        let url: URL
        let capturedAt: Date

        func loadImage() -> NSImage? { NSImage(contentsOf: url) }
    }

    @Published private(set) var entries: [Entry] = []

    private let maxEntries = 200
    private let directory: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("Hypeshot/History", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        reload()
    }

    func add(_ shot: Screenshot) {
        let url = directory.appendingPathComponent("\(Self.filenameFormatter.string(from: shot.capturedAt))-\(shot.id.uuidString.prefix(8)).png")
        guard let data = pngData(from: shot.image) else { return }
        do {
            try data.write(to: url)
            entries.insert(Entry(id: shot.id, url: url, capturedAt: shot.capturedAt), at: 0)
            trim()
        } catch {
            // History is best-effort; capture flow must never fail because of it.
        }
    }

#if DEBUG
    /// Showcase mode only: swap the visible list without touching disk.
    func debugSetEntries(_ newEntries: [Entry]) {
        entries = newEntries
    }
#endif

    func delete(_ entry: Entry) {
        try? FileManager.default.removeItem(at: entry.url)
        entries.removeAll { $0.id == entry.id }
    }

    func clear() {
        for entry in entries {
            try? FileManager.default.removeItem(at: entry.url)
        }
        entries.removeAll()
    }

    private func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles)) ?? []
        entries = files
            .filter { $0.pathExtension == "png" }
            .compactMap { url in
                let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return Entry(id: UUID(), url: url, capturedAt: date)
            }
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    private func trim() {
        while entries.count > maxEntries {
            let last = entries.removeLast()
            try? FileManager.default.removeItem(at: last.url)
        }
    }

    private func pngData(from image: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
    }

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
