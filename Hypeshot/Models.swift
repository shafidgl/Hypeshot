import SwiftUI

// MARK: - Screenshot

struct Screenshot: Identifiable {
    let id = UUID()
    let image: CGImage
    let capturedAt: Date

    var pixelSize: CGSize { CGSize(width: image.width, height: image.height) }
}

// MARK: - Annotation

enum AnnotationTool: String, CaseIterable, Identifiable {
    case arrow, rect, ellipse, highlight, blur, text

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .arrow: "arrow.up.right"
        case .rect: "rectangle"
        case .ellipse: "circle"
        case .highlight: "highlighter"
        case .blur: "eye.slash"
        case .text: "textformat"
        }
    }

    var help: String {
        switch self {
        case .arrow: "Arrow"
        case .rect: "Box"
        case .ellipse: "Ellipse"
        case .highlight: "Highlight"
        case .blur: "Redact"
        case .text: "Text"
        }
    }
}

/// One annotation, stored in image-pixel coordinates with a top-left origin.
struct Annotation: Identifiable {
    let id = UUID()
    var tool: AnnotationTool
    var start: CGPoint
    var end: CGPoint
    var color: Color
    var lineWidth: CGFloat
    var text: String = ""
    var fontSize: CGFloat = 36

    var rect: CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
               width: abs(end.x - start.x), height: abs(end.y - start.y))
    }
}

// MARK: - Beautify (Pro)

struct BeautifyBackground: Identifiable, Equatable {
    let id: String
    let colors: [Color]

    static let presets: [BeautifyBackground] = [
        .init(id: "hype", colors: [Color(red: 1.0, green: 0.36, blue: 0.43), Color(red: 0.55, green: 0.27, blue: 0.96)]),
        .init(id: "ocean", colors: [Color(red: 0.15, green: 0.55, blue: 0.95), Color(red: 0.10, green: 0.85, blue: 0.80)]),
        .init(id: "sunset", colors: [Color(red: 0.98, green: 0.60, blue: 0.20), Color(red: 0.90, green: 0.22, blue: 0.45)]),
        .init(id: "forest", colors: [Color(red: 0.13, green: 0.65, blue: 0.45), Color(red: 0.05, green: 0.35, blue: 0.55)]),
        .init(id: "mono", colors: [Color(red: 0.18, green: 0.18, blue: 0.21), Color(red: 0.08, green: 0.08, blue: 0.10)]),
        .init(id: "cream", colors: [Color(red: 0.97, green: 0.94, blue: 0.88), Color(red: 0.90, green: 0.82, blue: 0.72)]),
    ]
}

struct BeautifySettings {
    var enabled = false
    var background: BeautifyBackground = BeautifyBackground.presets[0]
    var padding: CGFloat = 64
    var cornerRadius: CGFloat = 14
    var shadow = true
}

// MARK: - Export presets

enum ExportFormat: String, Codable, CaseIterable, Identifiable {
    case png, jpeg

    var id: String { rawValue }
    var fileExtension: String { rawValue == "jpeg" ? "jpg" : rawValue }
    var label: String { rawValue.uppercased() }
}

struct ExportPreset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var format: ExportFormat = .png
    var jpegQuality: Double = 0.9
    /// 1.0 = full retina pixels, 0.5 = downscale to 1x.
    var scale: Double = 1.0
    var filenameTemplate: String = "Hypeshot {date}"

    static let standard = ExportPreset(name: "PNG (Default)")

    func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        var name = filenameTemplate.replacingOccurrences(of: "{date}", with: formatter.string(from: date))
        if name.isEmpty { name = "Hypeshot" }
        return name + "." + format.fileExtension
    }
}
