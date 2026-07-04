import AppKit
import ScreenCaptureKit

/// Orchestrates the three capture modes: shows overlays, runs the
/// ScreenCaptureKit capture, and hands the result to the editor.
@MainActor
final class CaptureController {
    static let shared = CaptureController()

    private var overlay: SelectionPanel?

    // MARK: - Entry points

    func captureArea() {
        guard ensurePermission() else { return }
        guard let screen = screenUnderMouse() else { return }
        presentOverlay(on: screen, mode: .area)
    }

    func captureWindow() {
        guard ensurePermission() else { return }
        guard let screen = screenUnderMouse() else { return }
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                let windows = content.windows.filter { window in
                    window.isOnScreen
                        && window.windowLayer == 0
                        && window.frame.width > 60 && window.frame.height > 60
                        && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
                }
                presentOverlay(on: screen, mode: .window(windows))
            } catch {
                NSSound.beep()
            }
        }
    }

    func captureFullScreen() {
        guard ensurePermission() else { return }
        guard let screen = screenUnderMouse() else { return }
        Task { await self.performDisplayCapture(screen: screen, sourceRect: nil) }
    }

    // MARK: - Overlay

    private func presentOverlay(on screen: NSScreen, mode: SelectionMode) {
        dismissOverlay()
        let panel = SelectionPanel(screen: screen, mode: mode) { [weak self] result in
            guard let self else { return }
            self.dismissOverlay()
            switch result {
            case .cancelled:
                break
            case .area(let rectInScreen):
                Task { await self.performDisplayCapture(screen: screen, sourceRect: rectInScreen) }
            case .window(let scWindow):
                Task { await self.performWindowCapture(scWindow) }
            }
        }
        overlay = panel
        panel.present()
    }

    private func dismissOverlay() {
        overlay?.orderOut(nil)
        overlay = nil
    }

    // MARK: - ScreenCaptureKit

    /// `sourceRect` is in the display's top-left-origin point space; nil captures the whole display.
    private func performDisplayCapture(screen: NSScreen, sourceRect: CGRect?) async {
        guard let displayID = screen.displayID else { return }
        do {
            // Give the overlay's fade-out a beat so it never appears in the shot.
            try? await Task.sleep(nanoseconds: 80_000_000)

            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return }
            let ourWindows = content.windows.filter {
                $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            let filter = SCContentFilter(display: display, excludingWindows: ourWindows)

            let scale = screen.backingScaleFactor
            let config = SCStreamConfiguration()
            config.showsCursor = false
            let rect = sourceRect ?? CGRect(x: 0, y: 0, width: CGFloat(display.width), height: CGFloat(display.height))
            config.sourceRect = rect
            config.width = Int(rect.width * scale)
            config.height = Int(rect.height * scale)

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            finish(image)
        } catch {
            NSSound.beep()
        }
    }

    private func performWindowCapture(_ window: SCWindow) async {
        do {
            try? await Task.sleep(nanoseconds: 80_000_000)
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let scale = screenUnderMouse()?.backingScaleFactor ?? 2
            let config = SCStreamConfiguration()
            config.showsCursor = false
            config.width = Int(window.frame.width * scale)
            config.height = Int(window.frame.height * scale)
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            finish(image)
        } catch {
            NSSound.beep()
        }
    }

    private func finish(_ image: CGImage) {
        let shot = Screenshot(image: image, capturedAt: .now)
        HistoryStore.shared.add(shot)
        // Missing key means the default (on), matching @AppStorage in SettingsView.
        let copyAfterCapture = UserDefaults.standard.object(forKey: "copyAfterCapture") as? Bool ?? true
        if copyAfterCapture {
            Exporter.copyToPasteboard(image)
        }
        EditorWindowController.shared.show(screenshot: shot)
    }

    // MARK: - Permission

    private func ensurePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        // Triggers the one-time system prompt if it has never been shown.
        CGRequestScreenCaptureAccess()
        if CGPreflightScreenCaptureAccess() { return true }
        PermissionWindowController.shared.show()
        return false
    }

    private func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
