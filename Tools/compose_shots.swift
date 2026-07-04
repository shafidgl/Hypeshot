import AppKit

// Composes App Store frames (2880x1800): branded backdrop + headline +
// optional PRO badge + a real app-window snapshot with shadow.
// Usage: swift compose_shots.swift <showcaseDir> <outDir>

let showcaseDir = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]

struct Slide {
    let input: String
    let output: String
    let headline: String
    let sub: String
    let pro: Bool
    let accent: NSColor
    var maxImageHeight: CGFloat = 1240
}

let pink = NSColor(calibratedRed: 1.00, green: 0.36, blue: 0.43, alpha: 1)
let purple = NSColor(calibratedRed: 0.55, green: 0.27, blue: 0.96, alpha: 1)

let slides: [Slide] = [
    Slide(input: "editor-annotate.png", output: "screenshot-1-annotate.png",
          headline: "Annotate in seconds",
          sub: "Arrow, box, highlight, redact, and text — non-destructive, always editable.",
          pro: false, accent: pink),
    Slide(input: "beautify-output.png", output: "screenshot-2-beautify.png",
          headline: "Make it gorgeous",
          sub: "One click wraps your capture in a gradient background with padding and shadow.",
          pro: true, accent: purple),
    Slide(input: "history.png", output: "screenshot-3-history.png",
          headline: "Every capture, kept",
          sub: "Browse, reopen, copy, or drag out any screenshot you've ever taken.",
          pro: true, accent: NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.98, alpha: 1)),
    Slide(input: "pin.png", output: "screenshot-4-pin.png",
          headline: "Pin it on top",
          sub: "Float any capture above your windows while you work from it.",
          pro: true, accent: NSColor(calibratedRed: 0.15, green: 0.75, blue: 0.65, alpha: 1),
          maxImageHeight: 1080),
    Slide(input: "settings.png", output: "screenshot-5-workflow.png",
          headline: "Your workflow, your rules",
          sub: "Custom shortcuts, automatic saving, and clipboard behavior — all yours to set.",
          pro: false, accent: NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.20, alpha: 1),
          maxImageHeight: 1220),
    Slide(input: "paywall.png", output: "screenshot-6-pro.png",
          headline: "One purchase, yours forever",
          sub: "Unlock Pro once. No subscription, ever.",
          pro: false, accent: purple, maxImageHeight: 1220),
]

let W: CGFloat = 2880, H: CGFloat = 1800

for slide in slides {
    guard let source = NSImage(contentsOfFile: "\(showcaseDir)/\(slide.input)"),
          let sourceRep = source.representations.first else {
        print("SKIP missing \(slide.input)")
        continue
    }
    let srcPx = CGSize(width: sourceRep.pixelsWide, height: sourceRep.pixelsHigh)

    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high

    // Backdrop: near-black vertical gradient + accent glow behind the window.
    NSGradient(starting: NSColor(calibratedRed: 0.09, green: 0.085, blue: 0.13, alpha: 1),
               ending: NSColor(calibratedRed: 0.045, green: 0.045, blue: 0.07, alpha: 1))!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)
    NSGradient(colorsAndLocations: (slide.accent.withAlphaComponent(0.28), 0.0), (NSColor.clear, 1.0))!
        .draw(fromCenter: NSPoint(x: W / 2, y: 640), radius: 0,
              toCenter: NSPoint(x: W / 2, y: 640), radius: 1350, options: [])

    // Headline row (badge + text centered together).
    let headlineFont = NSFont.systemFont(ofSize: 104, weight: .bold)
    let headline = NSAttributedString(string: slide.headline, attributes: [
        .font: headlineFont, .foregroundColor: NSColor.white, .kern: -1.5])
    let headlineSize = headline.size()
    let badgeWidth: CGFloat = slide.pro ? 176 : 0
    let rowWidth = headlineSize.width + (slide.pro ? badgeWidth + 36 : 0)
    var x = (W - rowWidth) / 2
    let headlineY: CGFloat = 1560

    if slide.pro {
        let badge = NSRect(x: x, y: headlineY + 22, width: badgeWidth, height: 84)
        let path = NSBezierPath(roundedRect: badge, xRadius: 42, yRadius: 42)
        NSGradient(starting: pink, ending: purple)!.draw(in: path, angle: 0)
        let label = NSAttributedString(string: "PRO", attributes: [
            .font: NSFont.systemFont(ofSize: 46, weight: .heavy),
            .foregroundColor: NSColor.white, .kern: 4])
        let ls = label.size()
        label.draw(at: NSPoint(x: badge.midX - ls.width / 2, y: badge.midY - ls.height / 2))
        x += badgeWidth + 36
    }
    headline.draw(at: NSPoint(x: x, y: headlineY))

    let sub = NSAttributedString(string: slide.sub, attributes: [
        .font: NSFont.systemFont(ofSize: 44, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.62)])
    let subSize = sub.size()
    sub.draw(at: NSPoint(x: (W - subSize.width) / 2, y: 1476))

    // Window image, fitted and centered in the lower band.
    let maxW: CGFloat = 2480
    let scale = min(maxW / srcPx.width, slide.maxImageHeight / srcPx.height, 1.35)
    let size = CGSize(width: srcPx.width * scale, height: srcPx.height * scale)
    let origin = NSPoint(x: (W - size.width) / 2, y: 120 + (1290 - size.height) / 2)

    ctx.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    shadow.shadowBlurRadius = 64
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
    shadow.set()
    source.draw(in: NSRect(origin: origin, size: size), from: .zero, operation: .sourceOver, fraction: 1)
    ctx.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(slide.output)"))
    print("wrote \(slide.output)")
}
