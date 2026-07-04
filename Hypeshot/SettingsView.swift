import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var pro: ProStore
    @AppStorage("copyAfterCapture") private var copyAfterCapture = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Toggle("Copy to clipboard after capture", isOn: $copyAfterCapture)
            }

            Section("Shortcuts") {
                LabeledContent("Capture Area", value: "⇧⌘7")
                LabeledContent("Capture Window", value: "⇧⌘8")
                LabeledContent("Capture Full Screen", value: "⇧⌘9")
            }

            Section("Hypeshot Pro") {
                if pro.isPro {
                    Label("Pro unlocked", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    LabeledContent("Beautify, pins, history, OCR, presets") {
                        Button("Unlock Pro…") {
                            PaywallWindowController.shared.show()
                        }
                    }
                    Button("Restore Purchase") {
                        Task { await pro.restore() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}
