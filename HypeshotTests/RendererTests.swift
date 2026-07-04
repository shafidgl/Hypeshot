import XCTest
import SwiftUI
@testable import Hypeshot

@MainActor
final class RendererTests: XCTestCase {

    private func makeViewModel(width: Int = 200, height: Int = 100) -> EditorViewModel {
        EditorViewModel(screenshot: Screenshot(image: TestImages.solid(width: width, height: height),
                                               capturedAt: .now))
    }

    func testPlainRenderMatchesInputSize() throws {
        let vm = makeViewModel()
        let output = try XCTUnwrap(Renderer.render(vm))
        XCTAssertEqual(output.width, 200)
        XCTAssertEqual(output.height, 100)
    }

    func testEveryToolRenders() throws {
        let vm = makeViewModel()
        for tool in AnnotationTool.allCases {
            var annotation = Annotation(tool: tool,
                                        start: CGPoint(x: 20, y: 20),
                                        end: CGPoint(x: 120, y: 80),
                                        color: .red, lineWidth: 6)
            if tool == .text { annotation.text = "Hi" }
            vm.annotations = [annotation]
            XCTAssertNotNil(Renderer.render(vm), "tool \(tool.rawValue) failed to render")
        }
    }

    func testBeautifyGrowsCanvasByFourTimesPadding() throws {
        let vm = makeViewModel()
        vm.beautify.enabled = true
        vm.beautify.padding = 50
        let output = try XCTUnwrap(Renderer.render(vm))
        // Renderer doubles the point padding for retina pixels, then pads both sides:
        // canvas = image + (padding * 2) * 2 = image + 4 * padding.
        XCTAssertEqual(output.width, 200 + 4 * 50)
        XCTAssertEqual(output.height, 100 + 4 * 50)
    }

    func testRectAnnotationChangesPixels() throws {
        let vm = makeViewModel()
        let plain = try XCTUnwrap(Renderer.render(vm))
        vm.annotations = [Annotation(tool: .rect,
                                     start: CGPoint(x: 30, y: 20),
                                     end: CGPoint(x: 170, y: 80),
                                     color: .yellow, lineWidth: 8)]
        let annotated = try XCTUnwrap(Renderer.render(vm))
        XCTAssertEqual(plain.width, annotated.width)
        XCTAssertNotEqual(TestImages.rgbaBytes(of: plain), TestImages.rgbaBytes(of: annotated),
                          "rect annotation should alter pixels")
    }

    func testRedactionPixellatesRegion() throws {
        // A gradient-ish source so pixellation actually changes values.
        let base = TestImages.text("XYZ", width: 200, height: 100)
        let vm = EditorViewModel(screenshot: Screenshot(image: base, capturedAt: .now))
        let plain = try XCTUnwrap(Renderer.render(vm))
        vm.annotations = [Annotation(tool: .blur,
                                     start: CGPoint(x: 0, y: 0),
                                     end: CGPoint(x: 200, y: 100),
                                     color: .clear, lineWidth: 1)]
        let redacted = try XCTUnwrap(Renderer.render(vm))
        XCTAssertNotEqual(TestImages.rgbaBytes(of: plain), TestImages.rgbaBytes(of: redacted),
                          "full-frame redaction should alter pixels")
    }

    func testEditorViewModelUndoAndClear() {
        let vm = makeViewModel()
        vm.annotations = [
            Annotation(tool: .rect, start: .zero, end: CGPoint(x: 10, y: 10), color: .red, lineWidth: 2),
            Annotation(tool: .arrow, start: .zero, end: CGPoint(x: 50, y: 50), color: .red, lineWidth: 2),
        ]
        vm.undo()
        XCTAssertEqual(vm.annotations.count, 1)
        XCTAssertEqual(vm.annotations.first?.tool, .rect)
        vm.clearAll()
        XCTAssertTrue(vm.annotations.isEmpty)
        vm.undo() // must not crash on empty
        XCTAssertTrue(vm.annotations.isEmpty)
    }

    func testCommitPendingTextTrimsAndAppends() {
        let vm = makeViewModel()
        vm.pendingText = Annotation(tool: .text, start: CGPoint(x: 10, y: 10),
                                    end: CGPoint(x: 10, y: 10), color: .red, lineWidth: 2)
        vm.pendingTextValue = "  hello  "
        vm.commitPendingText()
        XCTAssertEqual(vm.annotations.count, 1)
        XCTAssertEqual(vm.annotations.first?.text, "hello")
        XCTAssertNil(vm.pendingText)
        XCTAssertEqual(vm.pendingTextValue, "")

        // Whitespace-only text is discarded.
        vm.pendingText = Annotation(tool: .text, start: .zero, end: .zero, color: .red, lineWidth: 2)
        vm.pendingTextValue = "   "
        vm.commitPendingText()
        XCTAssertEqual(vm.annotations.count, 1)
    }
}
