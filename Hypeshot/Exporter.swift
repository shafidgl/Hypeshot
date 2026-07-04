import AppKit
import UniformTypeIdentifiers

/// Turns a rendered CGImage into clipboard contents, files, or drag items.
@MainActor
enum Exporter {

    static func copyToPasteboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage(from: image)])
    }

    /// Shows a save panel and writes the image with the given preset.
    static func saveWithPanel(_ image: CGImage, preset: ExportPreset, capturedAt: Date, in window: NSWindow?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [preset.format == .png ? UTType.png : UTType.jpeg]
        panel.nameFieldStringValue = preset.filename(for: capturedAt)
        panel.canCreateDirectories = true

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try write(image, to: url, preset: preset)
            } catch {
                NSSound.beep()
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }

    /// Writes the image to a temp file so it can be dragged out of the editor.
    static func temporaryDragFile(_ image: CGImage, preset: ExportPreset, capturedAt: Date) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(preset.filename(for: capturedAt))
        do {
            try write(image, to: url, preset: preset)
            return url
        } catch {
            return nil
        }
    }

    static func write(_ image: CGImage, to url: URL, preset: ExportPreset) throws {
        let scaled = preset.scale < 0.999 ? downscale(image, by: preset.scale) ?? image : image
        let rep = NSBitmapImageRep(cgImage: scaled)
        let data: Data?
        switch preset.format {
        case .png:
            data = rep.representation(using: .png, properties: [:])
        case .jpeg:
            data = rep.representation(using: .jpeg, properties: [.compressionFactor: preset.jpegQuality])
        }
        guard let data else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url)
    }

    static func nsImage(from image: CGImage) -> NSImage {
        // Report point size at 2x so pasted images aren't giant on retina.
        NSImage(cgImage: image, size: NSSize(width: image.width / 2, height: image.height / 2))
    }

    private static func downscale(_ image: CGImage, by scale: Double) -> CGImage? {
        let width = Int(Double(image.width) * scale)
        let height = Int(Double(image.height) * scale)
        guard width > 0, height > 0,
              let ctx = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
