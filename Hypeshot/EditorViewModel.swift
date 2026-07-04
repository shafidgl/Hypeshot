import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
final class EditorViewModel: ObservableObject {
    let screenshot: Screenshot

    @Published var annotations: [Annotation] = []
    @Published var tool: AnnotationTool = .arrow
    @Published var color: Color = Color(red: 1.0, green: 0.36, blue: 0.43)
    @Published var lineWidth: CGFloat = 6
    @Published var draft: Annotation?
    @Published var beautify = BeautifySettings()
    @Published var toast: String?

    /// Pending text annotation being typed (image-space position).
    @Published var pendingText: Annotation?
    @Published var pendingTextValue = ""

    /// Pixellated copy of the screenshot used to render redaction rects.
    private(set) lazy var pixellated: CGImage? = Self.makePixellated(from: screenshot.image)

    init(screenshot: Screenshot) {
        self.screenshot = screenshot
    }

    func undo() {
        _ = annotations.popLast()
    }

    func clearAll() {
        annotations.removeAll()
    }

    func commitPendingText() {
        guard var annotation = pendingText else { return }
        let text = pendingTextValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            annotation.text = text
            annotations.append(annotation)
        }
        pendingText = nil
        pendingTextValue = ""
    }

    func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if toast == message { toast = nil }
        }
    }

    private static func makePixellated(from image: CGImage) -> CGImage? {
        let ci = CIImage(cgImage: image)
        let filter = CIFilter.pixellate()
        filter.inputImage = ci
        filter.scale = Float(max(image.width, image.height)) / 60
        filter.center = .zero
        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        return context.createCGImage(output, from: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
}
