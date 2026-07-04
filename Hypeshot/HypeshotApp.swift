import SwiftUI

@main
struct HypeshotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var pro = ProStore.shared

    var body: some Scene {
        MenuBarExtra("Hypeshot", systemImage: "camera.viewfinder") {
            MenuContent()
                .environmentObject(pro)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(pro)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyManager.shared.registerAll()
        Task { await ProStore.shared.start() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

struct MenuContent: View {
    @EnvironmentObject private var pro: ProStore

    var body: some View {
        Button("Capture Area") { CaptureController.shared.captureArea() }
            .keyboardShortcut("7", modifiers: [.command, .shift])
        Button("Capture Window") { CaptureController.shared.captureWindow() }
            .keyboardShortcut("8", modifiers: [.command, .shift])
        Button("Capture Full Screen") { CaptureController.shared.captureFullScreen() }
            .keyboardShortcut("9", modifiers: [.command, .shift])

        Divider()

        Button("History…") {
            if pro.isPro {
                HistoryWindowController.shared.show()
            } else {
                PaywallWindowController.shared.show()
            }
        }

        Divider()

        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",", modifiers: .command)

        if !pro.isPro {
            Button("Unlock Pro…") { PaywallWindowController.shared.show() }
        }

        Divider()

        Button("Quit Hypeshot") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
