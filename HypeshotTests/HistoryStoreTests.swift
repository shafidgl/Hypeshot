import XCTest
import AppKit
@testable import Hypeshot

/// Exercises the real singleton against the app container's History
/// directory. Every entry the tests create is removed again, and files that
/// existed before `clear()` runs are backed up and restored on disk.
@MainActor
final class HistoryStoreTests: XCTestCase {

    private var store: HistoryStore { HistoryStore.shared }

    func testAddCreatesEntryAndFile() throws {
        let countBefore = store.entries.count
        let shot = Screenshot(image: TestImages.solid(width: 40, height: 30), capturedAt: .now)
        store.add(shot)
        defer { if let entry = store.entries.first(where: { $0.id == shot.id }) { store.delete(entry) } }

        XCTAssertEqual(store.entries.count, countBefore + 1)
        let entry = try XCTUnwrap(store.entries.first, "newest entry should be inserted at the front")
        XCTAssertEqual(entry.id, shot.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: entry.url.path))
        XCTAssertNotNil(entry.loadImage())
    }

    func testDeleteRemovesEntryAndFile() throws {
        let shot = Screenshot(image: TestImages.solid(width: 40, height: 30), capturedAt: .now)
        store.add(shot)
        let entry = try XCTUnwrap(store.entries.first(where: { $0.id == shot.id }))
        store.delete(entry)
        XCTAssertFalse(store.entries.contains(entry))
        XCTAssertFalse(FileManager.default.fileExists(atPath: entry.url.path))
    }

    func testClearEmptiesStore() throws {
        // Back up whatever is on disk so the user's history survives this test.
        let existing = store.entries.map(\.url)
        var backups: [(name: String, data: Data)] = []
        for url in existing {
            if let data = try? Data(contentsOf: url) {
                backups.append((url.lastPathComponent, data))
            }
        }
        let directory = existing.first?.deletingLastPathComponent()

        let shot = Screenshot(image: TestImages.solid(width: 40, height: 30), capturedAt: .now)
        store.add(shot)
        XCTAssertFalse(store.entries.isEmpty)

        store.clear()
        XCTAssertTrue(store.entries.isEmpty)

        // Restore pre-existing files (entries repopulate on next app launch).
        if let directory {
            for backup in backups {
                try? backup.data.write(to: directory.appendingPathComponent(backup.name))
            }
        }
    }
}
