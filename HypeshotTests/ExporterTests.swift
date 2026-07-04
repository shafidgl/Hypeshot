import XCTest
import AppKit
@testable import Hypeshot

@MainActor
final class ExporterTests: XCTestCase {

    private let image = TestImages.solid(width: 100, height: 60)

    private func tempURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("HypeshotTests-\(UUID().uuidString)-\(name)")
    }

    func testWritePNGIsDecodable() throws {
        let url = tempURL("out.png")
        defer { try? FileManager.default.removeItem(at: url) }
        try Exporter.write(image, to: url, preset: .standard)
        let reloaded = try XCTUnwrap(NSImage(contentsOf: url))
        let cg = try XCTUnwrap(reloaded.cgImage(forProposedRect: nil, context: nil, hints: nil))
        XCTAssertEqual(cg.width, 100)
        XCTAssertEqual(cg.height, 60)
    }

    func testWriteJPEGIsDecodable() throws {
        var preset = ExportPreset(name: "jpeg")
        preset.format = .jpeg
        preset.jpegQuality = 0.8
        let url = tempURL("out.jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        try Exporter.write(image, to: url, preset: preset)
        let reloaded = try XCTUnwrap(NSImage(contentsOf: url))
        XCTAssertNotNil(reloaded.cgImage(forProposedRect: nil, context: nil, hints: nil))
        // JPEG magic bytes.
        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(2)), [0xFF, 0xD8])
    }

    func testDownscalePresetHalvesPixelDimensions() throws {
        var preset = ExportPreset(name: "half")
        preset.scale = 0.5
        let url = tempURL("half.png")
        defer { try? FileManager.default.removeItem(at: url) }
        try Exporter.write(image, to: url, preset: preset)
        let reloaded = try XCTUnwrap(NSImage(contentsOf: url))
        let cg = try XCTUnwrap(reloaded.cgImage(forProposedRect: nil, context: nil, hints: nil))
        XCTAssertEqual(cg.width, 50)
        XCTAssertEqual(cg.height, 30)
    }

    func testTemporaryDragFileIsReadable() throws {
        let url = try XCTUnwrap(Exporter.temporaryDragFile(image, preset: .standard, capturedAt: .now))
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(FileManager.default.isReadableFile(atPath: url.path))
        XCTAssertEqual(url.pathExtension, "png")
        XCTAssertNotNil(NSImage(contentsOf: url))
    }

    func testCopyToPasteboardPutsImage() {
        Exporter.copyToPasteboard(image)
        let objects = NSPasteboard.general.readObjects(forClasses: [NSImage.self]) as? [NSImage]
        XCTAssertEqual(objects?.isEmpty, false, "pasteboard should contain an image")
    }

    func testUniqueURLNumbersCollisions() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HypeshotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = Exporter.uniqueURL(in: dir, preferredName: "Shot.png")
        XCTAssertEqual(first.lastPathComponent, "Shot.png")
        try Data("x".utf8).write(to: first)

        let second = Exporter.uniqueURL(in: dir, preferredName: "Shot.png")
        XCTAssertEqual(second.lastPathComponent, "Shot 2.png")
        try Data("x".utf8).write(to: second)

        XCTAssertEqual(Exporter.uniqueURL(in: dir, preferredName: "Shot.png").lastPathComponent, "Shot 3.png")
    }

    func testCopyFileToPasteboardPutsFileURL() throws {
        let url = tempURL("copy.png")
        try Exporter.write(image, to: url, preset: .standard)
        defer { try? FileManager.default.removeItem(at: url) }

        Exporter.copyFileToPasteboard(url)
        let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self]) as? [URL]
        XCTAssertEqual(urls?.first?.lastPathComponent, url.lastPathComponent)
    }
}
