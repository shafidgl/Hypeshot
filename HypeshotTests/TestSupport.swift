import AppKit
import CoreGraphics

enum TestImages {

    /// Solid-color sRGB image of the given pixel size.
    static func solid(width: Int, height: Int,
                      color: CGColor = CGColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1)) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    /// White image with large black text, for OCR tests.
    static func text(_ string: String, width: Int = 900, height: Int = 220) -> CGImage {
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 96, weight: .bold),
                .foregroundColor: NSColor.black,
            ]
            let attributed = NSAttributedString(string: string, attributes: attributes)
            let size = attributed.size()
            attributed.draw(at: NSPoint(x: (rect.width - size.width) / 2,
                                        y: (rect.height - size.height) / 2))
            return true
        }
        var proposedRect = CGRect(x: 0, y: 0, width: width, height: height)
        return image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)!
    }

    /// Raw RGBA bytes for pixel-level comparisons.
    static func rgbaBytes(of image: CGImage) -> [UInt8] {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let ctx = CGContext(data: &bytes, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }
}
