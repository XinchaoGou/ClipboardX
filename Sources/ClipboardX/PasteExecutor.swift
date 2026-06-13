import Foundation
import AppKit
import Carbon.HIToolbox

/// Writes an item back to the system pasteboard and simulates Cmd+V.
final class PasteExecutor {
    private let settings: SettingsStore
    weak var monitor: PasteboardMonitor?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Whether we currently have Accessibility permission to post key events.
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user for Accessibility permission (opens the system dialog).
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Put an item on the pasteboard and paste it into the frontmost app.
    /// - Parameter plainText: force writing only plain text (strips formatting).
    func paste(_ item: ClipboardItem, plainText: Bool = false) {
        let pb = NSPasteboard.general
        let previous = settings.restorePreviousClipboardAfterPaste ? snapshot(pb) : nil

        writeToPasteboard(item, plainText: plainText)
        monitor?.ignoreNextChangeCount = pb.changeCount

        // Give the pasteboard a beat, then synthesize Cmd+V into the target app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.simulateCommandV()
            if let previous = previous {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self?.restore(previous, to: pb)
                }
            }
        }
    }

    /// Only copy to the pasteboard (no auto-paste).
    func copyToPasteboard(_ item: ClipboardItem, plainText: Bool = false) {
        writeToPasteboard(item, plainText: plainText)
        monitor?.ignoreNextChangeCount = NSPasteboard.general.changeCount
    }

    private func writeToPasteboard(_ item: ClipboardItem, plainText: Bool) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.type {
        case .text, .url:
            pb.setString(item.contentText ?? "", forType: .string)
        case .image:
            if let path = item.imagePath, let img = NSImage(contentsOfFile: path) {
                pb.writeObjects([img])
            }
        case .file:
            let urls = item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }
            if !urls.isEmpty {
                pb.writeObjects(urls)
            }
        }
        _ = plainText // text items are already plain; kept for API symmetry
    }

    private func simulateCommandV() {
        guard Self.hasAccessibilityPermission else {
            Self.requestAccessibilityPermission()
            return
        }
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        let loc = CGEventTapLocation.cghidEventTap
        down?.post(tap: loc)
        up?.post(tap: loc)
    }

    // MARK: - Snapshot / restore

    private struct Snapshot {
        var items: [[String: Data]]
    }

    private func snapshot(_ pb: NSPasteboard) -> Snapshot {
        var saved: [[String: Data]] = []
        for element in pb.pasteboardItems ?? [] {
            var dict: [String: Data] = [:]
            for type in element.types {
                if let data = element.data(forType: type) {
                    dict[type.rawValue] = data
                }
            }
            saved.append(dict)
        }
        return Snapshot(items: saved)
    }

    private func restore(_ snapshot: Snapshot, to pb: NSPasteboard) {
        pb.clearContents()
        var newItems: [NSPasteboardItem] = []
        for dict in snapshot.items {
            let item = NSPasteboardItem()
            for (rawType, data) in dict {
                item.setData(data, forType: NSPasteboard.PasteboardType(rawType))
            }
            newItems.append(item)
        }
        if !newItems.isEmpty {
            pb.writeObjects(newItems)
            monitor?.ignoreNextChangeCount = pb.changeCount
        }
    }
}
