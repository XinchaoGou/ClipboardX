import Foundation
import AppKit
import Carbon.HIToolbox

/// Registers global hotkeys via the Carbon Hot Key API.
final class HotkeyManager {
    struct Hotkey {
        var keyCode: UInt32
        var modifiers: UInt32   // Carbon modifier flags (cmdKey, shiftKey, ...)
        var id: UInt32
    }

    enum Action: UInt32 {
        case togglePanel = 1
        case pastePlainText = 2
    }

    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?

    func registerDefaults(togglePanel: @escaping () -> Void,
                          pastePlainText: @escaping () -> Void) {
        installEventHandlerIfNeeded()
        // Shift + Cmd + V
        register(keyCode: UInt32(kVK_ANSI_V),
                 modifiers: UInt32(cmdKey | shiftKey),
                 action: .togglePanel, handler: togglePanel)
        // Ctrl + Cmd + V
        register(keyCode: UInt32(kVK_ANSI_V),
                 modifiers: UInt32(cmdKey | controlKey),
                 action: .pastePlainText, handler: pastePlainText)
    }

    func register(keyCode: UInt32, modifiers: UInt32, action: Action, handler: @escaping () -> Void) {
        installEventHandlerIfNeeded()
        handlers[action.rawValue] = handler
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x43_4C_58_31), id: action.rawValue) // 'CLX1'
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRefs.append(ref)
        } else {
            NSLog("ClipboardX: failed to register hotkey id=\(action.rawValue) status=\(status)")
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event = event, let userData = userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handlers[hkID.id]?()
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)
    }

    func unregisterAll() {
        for ref in hotKeyRefs where ref != nil {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
    }

    deinit {
        unregisterAll()
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
