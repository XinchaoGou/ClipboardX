import AppKit
import Carbon.HIToolbox

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
        registerBoardHotkeys()

        // First-run nudge for Accessibility so paste works.
        if !PasteExecutor.hasAccessibilityPermission {
            PasteExecutor.requestAccessibilityPermission()
        }
    }

    /// Ctrl+Cmd+0 opens Pinned; Ctrl+Cmd+1…9 open the Nth collection.
    /// Keys are registered once; the board lookup happens live at trigger time so
    /// no re-registration is needed when collections are created/deleted.
    private func registerBoardHotkeys() {
        let mods = UInt32(cmdKey | controlKey)
        hotkeys.register(keyCode: UInt32(kVK_ANSI_0), modifiers: mods, id: 99) { [weak self] in
            self?.panelController.show(selection: .pinned)
        }
        let digitKeys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                         kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        for (index, key) in digitKeys.enumerated() {
            hotkeys.register(keyCode: UInt32(key), modifiers: mods, id: UInt32(100 + index)) { [weak self] in
                self?.openBoard(at: index)
            }
        }
    }

    private func openBoard(at index: Int) {
        let boards = appState.groups
        guard index < boards.count else { return }
        panelController.show(selection: .group(boards[index].id))
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
                                 filePaths: [], imagePath: nil, thumbnailPath: nil,
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
