#if DEBUG
import AppKit
import SwiftUI
import ScreenCaptureKit

/// Marketing-screenshot mode: launched with HYPESHOT_SHOWCASE=1, the app
/// stages each of its real windows with demo content and saves window
/// snapshots (rendered by AppKit — no Screen Recording needed) into
/// Application Support/Hypeshot/Showcase, then quits.
@MainActor
enum ShowcaseRunner {

    static var isRequested: Bool {
        ProcessInfo.processInfo.environment["HYPESHOT_SHOWCASE"] != nil
    }

    static func run() async {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Hypeshot/Showcase", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        NSApp.activate(ignoringOtherApps: true)

        // 1. Paywall while still locked.
        PaywallWindowController.shared.show()
        await settle()
        await snapshotWindow(titled: "Unlock Hypeshot Pro", as: "paywall.png", in: dir)
        PaywallWindowController.shared.close()

        ProStore.shared.debugUnlockForShowcase()

        // 2. Editor with annotations.
        let sample = SampleContent.make(accent: NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.98, alpha: 1))
        EditorWindowController.shared.show(screenshot: Screenshot(image: sample, capturedAt: .now))
        await settle()
        if let vm = EditorWindowController.shared.debugViewModel {
            let pink = Color(red: 1.0, green: 0.36, blue: 0.43)
            vm.annotations = [
                Annotation(tool: .rect, start: CGPoint(x: 440, y: 905), end: CGPoint(x: 850, y: 1075),
                           color: pink, lineWidth: 8),
                Annotation(tool: .arrow, start: CGPoint(x: 1560, y: 330), end: CGPoint(x: 1250, y: 545),
                           color: pink, lineWidth: 10),
                Annotation(tool: .highlight, start: CGPoint(x: 430, y: 582), end: CGPoint(x: 1240, y: 648),
                           color: .yellow, lineWidth: 6),
                Annotation(tool: .blur, start: CGPoint(x: 425, y: 690), end: CGPoint(x: 1500, y: 760),
                           color: pink, lineWidth: 6),
                Annotation(tool: .text, start: CGPoint(x: 1180, y: 880), end: CGPoint(x: 1180, y: 880),
                           color: pink, lineWidth: 6, text: "Ship this!", fontSize: 72),
            ]
        }
        await settle()
        await snapshotWindow(titled: "Hypeshot", as: "editor-annotate.png", in: dir)

        // 3. Beautified output — the renderer's real export, not a mockup.
        if let vm = EditorWindowController.shared.debugViewModel {
            vm.beautify.enabled = true
            vm.beautify.padding = 96
            vm.beautify.cornerRadius = 18
            if let rendered = Renderer.render(vm) {
                write(rendered, as: "beautify-output.png", in: dir)
            }
        }
        NSApp.windows.first { $0.title == "Hypeshot" }?.close()

        // 4. History grid, seeded with demo captures (removed afterwards).
        var seeded: [UUID] = []
        let accents: [NSColor] = [
            NSColor(calibratedRed: 0.98, green: 0.45, blue: 0.35, alpha: 1),
            NSColor(calibratedRed: 0.30, green: 0.80, blue: 0.60, alpha: 1),
            NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.98, alpha: 1),
            NSColor(calibratedRed: 0.85, green: 0.40, blue: 0.90, alpha: 1),
            NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.25, alpha: 1),
            NSColor(calibratedRed: 0.45, green: 0.85, blue: 0.95, alpha: 1),
        ]
        let realEntries = HistoryStore.shared.entries
        for accent in accents {
            let shot = Screenshot(image: SampleContent.make(accent: accent), capturedAt: .now)
            seeded.append(shot.id)
            HistoryStore.shared.add(shot)
        }
        // Show ONLY the demo captures — the user's real history must never
        // leak into marketing shots.
        let demoEntries = HistoryStore.shared.entries.filter { seeded.contains($0.id) }
        HistoryStore.shared.debugSetEntries(demoEntries)
        HistoryWindowController.shared.show()
        // Two demo rows exactly — no empty band under the grid.
        NSApp.windows.first { $0.title == "Capture History" }?.setContentSize(NSSize(width: 720, height: 434))
        try? await Task.sleep(nanoseconds: 1_400_000_000) // let thumbnails load
        await snapshotWindow(titled: "Capture History", as: "history.png", in: dir)
        NSApp.windows.first { $0.title == "Capture History" }?.close()
        for entry in demoEntries {
            try? FileManager.default.removeItem(at: entry.url)
        }
        HistoryStore.shared.debugSetEntries(realEntries)

        // 5. Settings (hosted in a plain window so no Settings scene plumbing).
        let settings = NSWindow(contentViewController: NSHostingController(
            rootView: SettingsView().environmentObject(ProStore.shared)))
        settings.title = "Hypeshot Settings"
        settings.makeKeyAndOrderFront(nil)
        await settle()
        await snapshotWindow(titled: "Hypeshot Settings", as: "settings.png", in: dir)
        settings.close()

        // 6. Pinned floating screenshot.
        PinWindowController.pin(image: SampleContent.make(accent: NSColor(calibratedRed: 0.30, green: 0.80, blue: 0.60, alpha: 1)))
        await settle()
        if let pin = NSApp.windows.compactMap({ $0 as? PinPanel }).first {
            await save(window: pin, as: "pin.png", in: dir)
            pin.close()
        }

        try? Data("done".utf8).write(to: dir.appendingPathComponent("DONE"))
        NSApp.terminate(nil)
    }

    // MARK: helpers

    private static func settle() async {
        try? await Task.sleep(nanoseconds: 800_000_000)
    }

    private static func snapshotWindow(titled title: String, as name: String, in dir: URL) async {
        guard let window = NSApp.windows.first(where: { $0.title == title && $0.isVisible }) else { return }
        await save(window: window, as: name, in: dir)
    }

    /// True pixels via ScreenCaptureKit when the app has Screen Recording
    /// permission (toolbar glyphs and materials render exactly as on screen);
    /// falls back to AppKit frame-view rendering otherwise.
    private static func save(window: NSWindow, as name: String, in dir: URL) async {
        log("preflight=\(CGPreflightScreenCaptureAccess()) for \(name)", in: dir)
        if CGPreflightScreenCaptureAccess() {
            do {
                let image = try await sckCapture(window)
                write(image, as: name, in: dir)
                return
            } catch {
                log("sck failed for \(name): \(error)", in: dir)
            }
        }
        cacheDisplaySave(window: window, as: name, in: dir)
    }

    private static func sckCapture(_ window: NSWindow) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let scWindow = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else {
            throw CocoaError(.fileNoSuchFile) // window not in shareable list
        }
        let config = SCStreamConfiguration()
        config.showsCursor = false
        config.width = Int(window.frame.width) * 2
        config.height = Int(window.frame.height) * 2
        return try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(desktopIndependentWindow: scWindow),
            configuration: config)
    }

    private static func log(_ message: String, in dir: URL) {
        let url = dir.appendingPathComponent("showcase.log")
        let line = message + "\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }

    static func write(_ image: CGImage, as name: String, in dir: URL) {
        let rep = NSBitmapImageRep(cgImage: image)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: dir.appendingPathComponent(name))
        }
    }

    private static func cacheDisplaySave(window: NSWindow, as name: String, in dir: URL) {
        guard let frameView = window.contentView?.superview else { return }
        let bounds = frameView.bounds
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(bounds.width) * 2,
                                         pixelsHigh: Int(bounds.height) * 2,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = bounds.size // 2x pixels at 1x point size = retina rendering
        frameView.cacheDisplay(in: bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: dir.appendingPathComponent(name))
        }
    }
}

// MARK: - Demo capture content

/// Draws the fake "captured app" that appears inside the editor in marketing
/// shots — a generic dark dashboard, deliberately not a real product.
private enum SampleContent {
    static func make(accent: NSColor) -> CGImage {
        let W = 2000, H = 1250
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx

        func bar(_ rect: NSRect, _ color: NSColor, radius: CGFloat = 12) {
            color.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        }

        // Window body + title bar (drawn in bottom-up AppKit coordinates).
        bar(NSRect(x: 0, y: 0, width: W, height: H), NSColor(calibratedWhite: 0.12, alpha: 1), radius: 0)
        bar(NSRect(x: 0, y: CGFloat(H) - 76, width: CGFloat(W), height: 76), NSColor(calibratedWhite: 0.16, alpha: 1), radius: 0)
        for (i, c) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
            c.withAlphaComponent(0.9).setFill()
            NSBezierPath(ovalIn: NSRect(x: 36 + CGFloat(i) * 44, y: CGFloat(H) - 52, width: 26, height: 26)).fill()
        }

        // Sidebar.
        bar(NSRect(x: 0, y: 0, width: 360, height: CGFloat(H) - 76), NSColor(calibratedWhite: 0.145, alpha: 1), radius: 0)
        for i in 0..<6 {
            bar(NSRect(x: 40, y: CGFloat(H) - 190 - CGFloat(i) * 74, width: i == 0 ? 280 : 230, height: 30),
                i == 0 ? accent.withAlphaComponent(0.85) : NSColor(calibratedWhite: 0.26, alpha: 1), radius: 15)
        }

        // Chart, top right (image-space y 200–560 → AppKit y H-560..H-200).
        for (i, h) in [130, 210, 165, 300, 250, 335].enumerated() {
            bar(NSRect(x: 1120 + CGFloat(i) * 130, y: CGFloat(H) - 560, width: 90, height: CGFloat(h)),
                i == 3 ? accent : accent.withAlphaComponent(0.45), radius: 10)
        }

        // Heading + text rows (rows at image-space y ~580–760).
        bar(NSRect(x: 430, y: CGFloat(H) - 300, width: 560, height: 52), NSColor(calibratedWhite: 0.30, alpha: 1), radius: 16)
        bar(NSRect(x: 430, y: CGFloat(H) - 640, width: 810, height: 40), NSColor(calibratedWhite: 0.24, alpha: 1), radius: 14)
        // Real text in the redaction zone so pixelation reads as redaction.
        NSAttributedString(
            string: "alex@example.com   ·   token ghp_9f2Kx84nQzT31LmVe",
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 34, weight: .medium),
                         .foregroundColor: NSColor(calibratedWhite: 0.78, alpha: 1)]
        ).draw(at: NSPoint(x: 434, y: CGFloat(H) - 748))
        bar(NSRect(x: 430, y: CGFloat(H) - 856, width: 640, height: 40), NSColor(calibratedWhite: 0.24, alpha: 1), radius: 14)

        // Button (image-space y 905–1075 → AppKit).
        bar(NSRect(x: 480, y: CGFloat(H) - 1040, width: 320, height: 96), accent, radius: 20)

        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage!
    }
}
#endif
