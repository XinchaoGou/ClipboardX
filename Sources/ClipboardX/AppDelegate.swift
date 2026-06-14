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
            togglePanel: { [weak self] in self?.panelController.toggle() }
        )

        // First-run nudge for Accessibility so paste works.
        if !PasteExecutor.hasAccessibilityPermission {
            PasteExecutor.requestAccessibilityPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        hotkeys?.unregisterAll()
    }
}
