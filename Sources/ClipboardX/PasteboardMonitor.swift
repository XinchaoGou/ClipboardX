import Foundation
import AppKit

/// Polls `NSPasteboard.general` for changes and records new items.
final class PasteboardMonitor {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    private let store: ClipboardStore
    private let settings: SettingsStore
    private let onChange: () -> Void

    /// Set by `PasteExecutor` when we programmatically write to the pasteboard,
    /// so we can avoid recording our own writes.
    var ignoreNextChangeCount: Int?

    init(store: ClipboardStore, settings: SettingsStore, onChange: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.onChange = onChange
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        let t = Timer.scheduledTimer(withTimeInterval: settings.pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        // Skip changes we caused ourselves.
        if let ignore = ignoreNextChangeCount, ignore == current {
            ignoreNextChangeCount = nil
            return
        }

        let front = AppFilter.frontmostApp()
        guard let item = ClipboardItemParser.parse(pasteboard, source: front) else { return }

        do {
            try store.insert(item)
            try store.enforceLimit(maxCount: settings.maxHistoryCount)
            onChange()
        } catch {
            NSLog("ClipboardX: failed to store item: \(error)")
        }
    }
}
