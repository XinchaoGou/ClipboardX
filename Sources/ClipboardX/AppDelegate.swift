import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: ClipboardStore!
    private var appState: AppState!
    private var monitor: PasteboardMonitor!
    private var menuBar: MenuBarController!
    private var hotkeys: HotkeyManager!
    private var panelController: PanelController!
    private var settingsController: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only, no Dock icon.
        NSApp.setActivationPolicy(.accessory)

        let settings = SettingsStore.shared
        do {
            store = try ClipboardStore()
        } catch {
            NSLog("ClipboardX: FATAL could not open database: \(error)")
            NSApp.terminate(nil)
            return
        }

        let paste = PasteExecutor(settings: settings)
        appState = AppState(store: store, settings: settings, paste: paste)

        monitor = PasteboardMonitor(store: store, settings: settings) { [weak self] in
            self?.appState.reload()
        }
        paste.monitor = monitor
        monitor.start()

        panelController = PanelController(app: appState)
        PanelController.shared = panelController

        settingsController = SettingsWindowController(settings: settings, app: appState)

        menuBar = MenuBarController(
            app: appState,
            onOpenPanel: { [weak self] in self?.panelController.toggle() },
            onOpenSettings: { [weak self] in self?.settingsController.show() }
        )

        hotkeys = HotkeyManager()
        hotkeys.registerDefaults(
            togglePanel: { [weak self] in self?.panelController.toggle() },
            pastePlainText: { [weak self] in self?.pastePlainTextFromClipboard() }
        )

        // First-run nudge for Accessibility so paste works.
        if !PasteExecutor.hasAccessibilityPermission {
            PasteExecutor.requestAccessibilityPermission()
        }
    }

    /// Ctrl+Cmd+V: re-paste the current clipboard as plain text into the front app.
    private func pastePlainTextFromClipboard() {
        guard SettingsStore.shared.enablePlainTextPaste else { return }
        let pb = NSPasteboard.general
        guard let text = pb.string(forType: .string) else { return }
        pb.clearContents()
        pb.setString(text, forType: .string)
        monitor.ignoreNextChangeCount = pb.changeCount
        let exec = PasteExecutor(settings: SettingsStore.shared)
        exec.monitor = monitor
        let item = ClipboardItem(id: 0, type: .text, contentText: text, contentHash: "",
                                 filePaths: [], imagePath: nil, thumbnailPath: nil, rtfPath: nil,
                                 sourceAppName: nil, sourceAppBundleID: nil, sourceAppIconPath: nil,
                                 createdAt: Date(), updatedAt: Date(), lastUsedAt: nil,
                                 useCount: 0, isPinned: false)
        exec.paste(item, plainText: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        hotkeys?.unregisterAll()
    }
}
