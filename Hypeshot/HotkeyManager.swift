import AppKit
import Carbon.HIToolbox

/// Registers the three global capture hotkeys via Carbon's RegisterEventHotKey,
/// which works inside the App Store sandbox (unlike CGEventTap, which needs
/// Accessibility permission).
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private struct Hotkey {
        let id: UInt32
        let keyCode: UInt32
        let action: () -> Void
    }

    private var hotkeys: [UInt32: Hotkey] = [:]
    private var refs: [EventHotKeyRef?] = []
    private var handler: EventHandlerRef?

    private init() {}

    func registerAll() {
        guard handler == nil else { return }

        let modifiers = UInt32(cmdKey | shiftKey)
        let keys: [Hotkey] = [
            Hotkey(id: 1, keyCode: UInt32(kVK_ANSI_7)) { CaptureController.shared.captureArea() },
            Hotkey(id: 2, keyCode: UInt32(kVK_ANSI_8)) { CaptureController.shared.captureWindow() },
            Hotkey(id: 3, keyCode: UInt32(kVK_ANSI_9)) { CaptureController.shared.captureFullScreen() },
        ]

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            Task { @MainActor in
                HotkeyManager.shared.hotkeys[hotkeyID.id]?.action()
            }
            return noErr
        }, 1, &eventType, nil, &handler)

        let signature = OSType(0x4859_5053) // 'HYPS'
        for key in keys {
            hotkeys[key.id] = key
            var ref: EventHotKeyRef?
            RegisterEventHotKey(key.keyCode, modifiers,
                                EventHotKeyID(signature: signature, id: key.id),
                                GetApplicationEventTarget(), 0, &ref)
            refs.append(ref)
        }
    }
}
