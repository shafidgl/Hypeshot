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
    @ObservedObject private var hotkeys = HotkeyStore.shared

    var body: some View {
        ForEach(CaptureAction.allCases) { action in
            Button(action.title) { action.perform() }
                .hotkeyShortcut(hotkeys.spec(for: action))
        }

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
