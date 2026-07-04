import AppKit
import SwiftUI
import Carbon.HIToolbox

// MARK: - Actions

enum CaptureAction: String, CaseIterable, Codable, Identifiable {
    case area, window, fullScreen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .area: "Capture Area"
        case .window: "Capture Window"
        case .fullScreen: "Capture Full Screen"
        }
    }

    var defaultSpec: HotkeySpec {
        let mods = UInt32(cmdKey | shiftKey)
        switch self {
        case .area: return HotkeySpec(keyCode: UInt32(kVK_ANSI_7), carbonModifiers: mods, keyLabel: "7")
        case .window: return HotkeySpec(keyCode: UInt32(kVK_ANSI_8), carbonModifiers: mods, keyLabel: "8")
        case .fullScreen: return HotkeySpec(keyCode: UInt32(kVK_ANSI_9), carbonModifiers: mods, keyLabel: "9")
        }
    }

    @MainActor func perform() {
        switch self {
        case .area: CaptureController.shared.captureArea()
        case .window: CaptureController.shared.captureWindow()
        case .fullScreen: CaptureController.shared.captureFullScreen()
        }
    }
}

// MARK: - Spec

/// One recorded shortcut: hardware key + Carbon modifier mask, plus the
/// character label used for display and the in-app menu key equivalent.
struct HotkeySpec: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var keyLabel: String

    var display: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + keyLabel.uppercased()
    }

    var eventModifiers: SwiftUI.EventModifiers {
        var mods: SwiftUI.EventModifiers = []
        if carbonModifiers & UInt32(controlKey) != 0 { mods.insert(.control) }
        if carbonModifiers & UInt32(optionKey) != 0 { mods.insert(.option) }
        if carbonModifiers & UInt32(shiftKey) != 0 { mods.insert(.shift) }
        if carbonModifiers & UInt32(cmdKey) != 0 { mods.insert(.command) }
        return mods
    }

    var keyEquivalent: KeyEquivalent? {
        guard let char = keyLabel.lowercased().first else { return nil }
        return KeyEquivalent(char)
    }

    /// Builds a spec from a key-down event; nil for bare keys (a shortcut
    /// must include ⌘, ⌃, or ⌥ so typing isn't hijacked).
    static func from(event: NSEvent) -> HotkeySpec? {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else { return nil }
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        let label = event.charactersIgnoringModifiers?.uppercased() ?? "?"
        return HotkeySpec(keyCode: UInt32(event.keyCode), carbonModifiers: carbon, keyLabel: label)
    }
}

// MARK: - Store

/// Persisted user shortcut choices; the single source the manager, menu,
/// and Settings recorder all read.
@MainActor
final class HotkeyStore: ObservableObject {
    static let shared = HotkeyStore()

    private static let defaultsKey = "hotkeySpecs"

    @Published var specs: [CaptureAction: HotkeySpec] {
        didSet {
            if let data = try? JSONEncoder().encode(specs) {
                UserDefaults.standard.set(data, forKey: Self.defaultsKey)
            }
            HotkeyManager.shared.reregister()
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([CaptureAction: HotkeySpec].self, from: data) {
            specs = saved
        } else {
            specs = Dictionary(uniqueKeysWithValues: CaptureAction.allCases.map { ($0, $0.defaultSpec) })
        }
    }

    func spec(for action: CaptureAction) -> HotkeySpec? { specs[action] }

    /// Assigns a spec; if another action already uses the combo, that action
    /// loses it (last assignment wins, nothing is silently dropped).
    func assign(_ spec: HotkeySpec, to action: CaptureAction) {
        var updated = specs
        for (other, existing) in updated where other != action && existing == spec {
            updated[other] = nil
        }
        updated[action] = spec
        specs = updated
    }

    func resetToDefaults() {
        specs = Dictionary(uniqueKeysWithValues: CaptureAction.allCases.map { ($0, $0.defaultSpec) })
    }
}

// MARK: - Manager

/// Registers the capture shortcuts globally via Carbon's RegisterEventHotKey,
/// which works inside the App Store sandbox (unlike CGEventTap, which needs
/// Accessibility permission).
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private static let signature = OSType(0x4859_5053) // 'HYPS'
    private let actionIDs: [UInt32: CaptureAction] = [1: .area, 2: .window, 3: .fullScreen]

    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    private init() {}

    func registerAll() {
        installHandlerIfNeeded()
        register()
    }

    func reregister() {
        unregister()
        register()
    }

    /// Suspends global registration while the Settings recorder captures a
    /// combo — otherwise recording an in-use shortcut would be swallowed
    /// by the hotkey itself.
    func pause() { unregister() }
    func resume() { register() }

    private func register() {
        guard handler != nil else { return }
        for (id, action) in actionIDs {
            guard let spec = HotkeyStore.shared.spec(for: action) else { continue }
            var ref: EventHotKeyRef?
            RegisterEventHotKey(spec.keyCode, spec.carbonModifiers,
                                EventHotKeyID(signature: Self.signature, id: id),
                                GetApplicationEventTarget(), 0, &ref)
            if let ref { refs.append(ref) }
        }
    }

    private func unregister() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            Task { @MainActor in
                HotkeyManager.shared.actionIDs[hotkeyID.id]?.perform()
            }
            return noErr
        }, 1, &eventType, nil, &handler)
    }
}

// MARK: - Menu shortcut helper

extension View {
    /// Applies a keyboard shortcut from a recorded spec when it can be
    /// represented as a SwiftUI key equivalent.
    @ViewBuilder
    func hotkeyShortcut(_ spec: HotkeySpec?) -> some View {
        if let spec, let key = spec.keyEquivalent {
            keyboardShortcut(key, modifiers: spec.eventModifiers)
        } else {
            self
        }
    }
}
