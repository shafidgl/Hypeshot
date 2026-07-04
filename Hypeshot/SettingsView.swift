import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var pro: ProStore
    @ObservedObject private var hotkeys = HotkeyStore.shared
    @ObservedObject private var saveLocation = SaveLocationStore.shared
    @AppStorage(CaptureCopyMode.openEditorKey) private var openEditorAfterCapture = true
    @AppStorage(CaptureCopyMode.autoSaveKey) private var autoSaveCaptures = false
    @AppStorage(CaptureCopyMode.defaultsKey) private var copyModeRaw = CaptureCopyMode.current.rawValue
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
                Toggle("Open annotation editor after capture", isOn: $openEditorAfterCapture)
            }

            Section {
                LabeledContent("Save screenshots to") {
                    HStack(spacing: 8) {
                        Text(saveLocation.folderURL?.lastPathComponent ?? "Ask each time")
                            .foregroundStyle(.secondary)
                            .help(saveLocation.folderURL?.path ?? "A save dialog is shown for every save")
                        Button("Choose…") { saveLocation.chooseFolder() }
                        if saveLocation.folderURL != nil {
                            Button("Reset") { saveLocation.clear() }
                        }
                    }
                }

                Toggle("Save every capture automatically", isOn: $autoSaveCaptures)
                    .disabled(saveLocation.folderURL == nil)

                Picker("After capture, copy", selection: $copyModeRaw) {
                    ForEach(CaptureCopyMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Saving")
            } footer: {
                if saveLocation.folderURL == nil {
                    Text("Choose a folder to enable automatic saving and file copying.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if copyModeRaw == CaptureCopyMode.file.rawValue {
                    Text("Each capture is saved to \(saveLocation.folderURL!.lastPathComponent) and the file is placed on the clipboard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Shortcuts") {
                ForEach(CaptureAction.allCases) { action in
                    LabeledContent(action.title) {
                        ShortcutRecorder(action: action)
                    }
                }
                Button("Reset Shortcuts to Defaults") { hotkeys.resetToDefaults() }
                    .font(.callout)
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
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Click-to-record shortcut field. While recording, global hotkeys are
/// paused so the combo being recorded isn't swallowed by its current owner.
private struct ShortcutRecorder: View {
    let action: CaptureAction

    @ObservedObject private var hotkeys = HotkeyStore.shared
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stopRecording() : startRecording()
        } label: {
            Text(recording ? "Press keys…" : hotkeys.spec(for: action)?.display ?? "None")
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 92)
        }
        .tint(recording ? .accentColor : nil)
        .help(recording ? "Press a combination including ⌘, ⌃, or ⌥ — Esc cancels"
                        : "Click to record a new shortcut")
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        recording = true
        HotkeyManager.shared.pause()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape cancels
                stopRecording()
                return nil
            }
            if let spec = HotkeySpec.from(event: event) {
                hotkeys.assign(spec, to: action)
                stopRecording()
                return nil
            }
            NSSound.beep() // bare key without ⌘/⌃/⌥
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if recording {
            recording = false
            HotkeyManager.shared.resume()
        }
    }
}
