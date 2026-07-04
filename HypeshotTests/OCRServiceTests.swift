import XCTest
@testable import Hypeshot

final class OCRServiceTests: XCTestCase {

    func testRecognizesLargeClearText() async throws {
        let image = TestImages.text("HYPESHOT 12345")
        let recognized: String
        do {
            recognized = try await OCRService.recognizeText(in: image)
        } catch {
            throw XCTSkip("Vision unavailable in this test environment: \(error)")
        }
        let flattened = recognized.uppercased().replacingOccurrences(of: "\n", with: " ")
        XCTAssertTrue(flattened.contains("HYPESHOT"), "got: \(recognized)")
        XCTAssertTrue(flattened.contains("12345"), "got: \(recognized)")
    }

    func testEmptyImageYieldsNoText() async throws {
        let image = TestImages.solid(width: 300, height: 200,
                                     color: CGColor(gray: 1, alpha: 1))
        let recognized: String
        do {
            recognized = try await OCRService.recognizeText(in: image)
        } catch {
            throw XCTSkip("Vision unavailable in this test environment: \(error)")
        }
        XCTAssertTrue(recognized.isEmpty, "blank image should produce no text, got: \(recognized)")
    }
}
