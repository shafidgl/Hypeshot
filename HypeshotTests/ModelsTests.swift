import XCTest
import SwiftUI
@testable import Hypeshot

final class ModelsTests: XCTestCase {

    // MARK: Annotation

    func testAnnotationRectNormalizesReversedDrag() {
        let annotation = Annotation(tool: .rect,
                                    start: CGPoint(x: 100, y: 80),
                                    end: CGPoint(x: 20, y: 10),
                                    color: .red, lineWidth: 4)
        XCTAssertEqual(annotation.rect, CGRect(x: 20, y: 10, width: 80, height: 70))
    }

    func testAnnotationRectZeroSizeAtSamePoint() {
        let point = CGPoint(x: 5, y: 5)
        let annotation = Annotation(tool: .ellipse, start: point, end: point, color: .red, lineWidth: 2)
        XCTAssertEqual(annotation.rect, CGRect(x: 5, y: 5, width: 0, height: 0))
    }

    // MARK: ExportPreset

    func testFilenameSubstitutesDateTemplate() {
        var preset = ExportPreset(name: "Test")
        preset.filenameTemplate = "Shot {date}"
        let date = Date(timeIntervalSince1970: 0)
        let name = preset.filename(for: date)
        XCTAssertTrue(name.hasPrefix("Shot 19"), "expected substituted year, got \(name)")
        XCTAssertTrue(name.hasSuffix(".png"))
        XCTAssertFalse(name.contains("{date}"))
    }

    func testFilenameEmptyTemplateFallsBack() {
        var preset = ExportPreset(name: "Test")
        preset.filenameTemplate = ""
        XCTAssertEqual(preset.filename(for: .now), "Hypeshot.png")
    }

    func testJPEGExtensionIsJpg() {
        var preset = ExportPreset(name: "Test")
        preset.format = .jpeg
        preset.filenameTemplate = "x"
        XCTAssertEqual(preset.filename(for: .now), "x.jpg")
        XCTAssertEqual(ExportFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(ExportFormat.png.fileExtension, "png")
    }

    func testStandardPresetDefaults() {
        let preset = ExportPreset.standard
        XCTAssertEqual(preset.format, .png)
        XCTAssertEqual(preset.scale, 1.0)
    }

    // MARK: BeautifyBackground

    func testBeautifyPresetsNonEmptyWithUniqueIDs() {
        let presets = BeautifyBackground.presets
        XCTAssertFalse(presets.isEmpty)
        XCTAssertEqual(Set(presets.map(\.id)).count, presets.count, "preset ids must be unique")
        for preset in presets {
            XCTAssertGreaterThanOrEqual(preset.colors.count, 2, "gradient needs at least 2 stops")
        }
    }

    // MARK: Screenshot

    func testScreenshotPixelSize() {
        let shot = Screenshot(image: TestImages.solid(width: 123, height: 45), capturedAt: .now)
        XCTAssertEqual(shot.pixelSize, CGSize(width: 123, height: 45))
    }

    // MARK: Capture copy mode

    func testCaptureCopyModeMigratesLegacyBooleanAndPrefersExplicitValue() {
        let defaults = UserDefaults.standard
        let savedMode = defaults.string(forKey: CaptureCopyMode.defaultsKey)
        let savedLegacy = defaults.object(forKey: "copyAfterCapture")
        defer {
            savedMode.map { defaults.set($0, forKey: CaptureCopyMode.defaultsKey) }
                ?? defaults.removeObject(forKey: CaptureCopyMode.defaultsKey)
            savedLegacy.map { defaults.set($0, forKey: "copyAfterCapture") }
                ?? defaults.removeObject(forKey: "copyAfterCapture")
        }

        defaults.removeObject(forKey: CaptureCopyMode.defaultsKey)
        defaults.removeObject(forKey: "copyAfterCapture")
        XCTAssertEqual(CaptureCopyMode.current, .image, "default is copying the image")

        defaults.set(false, forKey: "copyAfterCapture")
        XCTAssertEqual(CaptureCopyMode.current, .off, "legacy false migrates to off")

        defaults.set(true, forKey: "copyAfterCapture")
        XCTAssertEqual(CaptureCopyMode.current, .image, "legacy true migrates to image")

        defaults.set(CaptureCopyMode.file.rawValue, forKey: CaptureCopyMode.defaultsKey)
        XCTAssertEqual(CaptureCopyMode.current, .file, "explicit setting beats legacy")
    }
}
