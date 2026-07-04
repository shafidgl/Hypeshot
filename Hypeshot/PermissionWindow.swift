import AppKit
import SwiftUI

/// Shown when Screen Recording permission has been denied (or revoked).
/// macOS only honors the permission after the app is relaunched, so the
/// window walks the user through Settings and offers a one-click relaunch.
@MainActor
final class PermissionWindowController {
    static let shared = PermissionWindowController()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: PermissionView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Screen Recording Permission"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct PermissionView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "rectangle.badge.record")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.tint)
                .padding(.top, 30)

            Text("Hypeshot needs Screen Recording access")
                .font(.title3.weight(.semibold))

            Text("macOS requires permission before any app can capture the screen. Turn on **Hypeshot** in System Settings, then relaunch the app.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            VStack(spacing: 8) {
                Button("Open System Settings") {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Relaunch Hypeshot") {
                    relaunch()
                }
                .buttonStyle(.link)
                .font(.callout)
            }
            .padding(.bottom, 26)
        }
        .frame(width: 400)
        .background(.regularMaterial)
    }

    private func relaunch() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
