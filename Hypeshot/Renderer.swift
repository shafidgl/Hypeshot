import AppKit
import SwiftUI

/// Composites the final bitmap: beautify background + screenshot + annotations.
/// Annotations are stored in image-pixel coordinates with a top-left origin;
/// CoreGraphics draws bottom-up, so everything is flipped through `flip`.
enum Renderer {

    @MainActor
    static func render(_ vm: EditorViewModel) -> CGImage? {
        let base = vm.screenshot.image
        let imageSize = CGSize(width: base.width, height: base.height)
        let beautify = vm.beautify

        let pad = beautify.enabled ? beautify.padding * 2 : 0 // padding slider is in display points; double for retina pixels
        let canvasSize = CGSize(width: imageSize.width + pad * 2, height: imageSize.height + pad * 2)

        guard let ctx = CGContext(data: nil,
                                  width: Int(canvasSize.width),
                                  height: Int(canvasSize.height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        // Background
        if beautify.enabled {
            let colors = beautify.background.colors.map { NSColor($0).usingColorSpace(.sRGB)?.cgColor ?? .black }
            if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil) {
                ctx.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: canvasSize.height),
                                       end: CGPoint(x: canvasSize.width, y: 0),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
        }

        // Screenshot, rounded + shadowed when beautified
        let imageRect = CGRect(x: pad, y: pad, width: imageSize.width, height: imageSize.height)
        ctx.saveGState()
        if beautify.enabled {
            if beautify.shadow {
                ctx.setShadow(offset: CGSize(width: 0, height: -pad * 0.12), blur: pad * 0.5,
                              color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
            }
            let radius = beautify.cornerRadius * 2
            let path = CGPath(roundedRect: imageRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            // Draw shadow from the shape itself, then clip and draw the image.
            ctx.addPath(path)
            ctx.setFillColor(CGColor(gray: 0, alpha: 1))
            ctx.fillPath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.addPath(path)
            ctx.clip()
        }
        ctx.draw(base, in: imageRect)

        // Annotations (in image space; translate into padded canvas, flip y)
        let flip: (CGPoint) -> CGPoint = { p in
            CGPoint(x: p.x + pad, y: pad + imageSize.height - p.y)
        }
        let flipRect: (CGRect) -> CGRect = { r in
            CGRect(x: r.minX + pad, y: pad + imageSize.height - r.maxY, width: r.width, height: r.height)
        }

        for annotation in vm.annotations {
            let cgColor = NSColor(annotation.color).usingColorSpace(.sRGB)?.cgColor ?? .black
            switch annotation.tool {
            case .arrow:
                drawArrow(in: ctx, from: flip(annotation.start), to: flip(annotation.end),
                          color: cgColor, lineWidth: annotation.lineWidth)
            case .rect:
                ctx.setStrokeColor(cgColor)
                ctx.setLineWidth(annotation.lineWidth)
                ctx.stroke(flipRect(annotation.rect).insetBy(dx: annotation.lineWidth / 2, dy: annotation.lineWidth / 2))
            case .ellipse:
                ctx.setStrokeColor(cgColor)
                ctx.setLineWidth(annotation.lineWidth)
                ctx.strokeEllipse(in: flipRect(annotation.rect).insetBy(dx: annotation.lineWidth / 2, dy: annotation.lineWidth / 2))
            case .highlight:
                ctx.saveGState()
                ctx.setBlendMode(.multiply)
                ctx.setFillColor(NSColor(annotation.color).usingColorSpace(.sRGB)?.withAlphaComponent(0.45).cgColor ?? .black)
                ctx.fill(flipRect(annotation.rect))
                ctx.restoreGState()
            case .blur:
                if let pixellated = vm.pixellated {
                    ctx.saveGState()
                    ctx.clip(to: flipRect(annotation.rect))
                    ctx.draw(pixellated, in: imageRect)
                    ctx.restoreGState()
                }
            case .text:
                drawText(annotation, in: ctx, flip: flip)
            }
        }
        ctx.restoreGState()

        return ctx.makeImage()
    }

    private static func drawArrow(in ctx: CGContext, from: CGPoint, to: CGPoint, color: CGColor, lineWidth: CGFloat) {
        let dx = to.x - from.x, dy = to.y - from.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let angle = atan2(dy, dx)
        let headLength = max(lineWidth * 3.5, 18)
        let headAngle: CGFloat = .pi / 7

        let lineEnd = CGPoint(x: to.x - cos(angle) * headLength * 0.6,
                              y: to.y - sin(angle) * headLength * 0.6)

        ctx.setStrokeColor(color)
        ctx.setFillColor(color)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        if length > 2 {
            ctx.move(to: from)
            ctx.addLine(to: lineEnd)
            ctx.strokePath()

            let p1 = CGPoint(x: to.x - cos(angle - headAngle) * headLength, y: to.y - sin(angle - headAngle) * headLength)
            let p2 = CGPoint(x: to.x - cos(angle + headAngle) * headLength, y: to.y - sin(angle + headAngle) * headLength)
            ctx.move(to: to)
            ctx.addLine(to: p1)
            ctx.addLine(to: p2)
            ctx.closePath()
            ctx.fillPath()
        }
    }

    private static func drawText(_ annotation: Annotation, in ctx: CGContext, flip: (CGPoint) -> CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .semibold),
            .foregroundColor: NSColor(annotation.color),
            .strokeColor: NSColor.black.withAlphaComponent(0.35),
        ]
        let string = NSAttributedString(string: annotation.text, attributes: attributes)
        let size = string.size()
        let topLeft = flip(annotation.start)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        string.draw(at: CGPoint(x: topLeft.x, y: topLeft.y - size.height))
        NSGraphicsContext.restoreGraphicsState()
    }
}
