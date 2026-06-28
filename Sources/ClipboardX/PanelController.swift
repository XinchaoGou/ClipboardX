import AppKit
import SwiftUI

/// A borderless floating panel that can become key so the search field works.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Owns the clipboard panel window and toggles its visibility.
@MainActor
final class PanelController {
    static var shared: PanelController?

    private let app: AppState
    private var panel: FloatingPanel?
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?

    init(app: AppState) {
        self.app = app
        installKeyMonitor()
    }

    /// Intercept keys that the focused search field would otherwise swallow,
    /// before they reach any responder. Currently: Shift+Return → plain paste.
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible, panel.isKeyWindow else {
                return event
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 36, flags == .shift {   // 36 = Return
                self.app.pasteSelected(plainText: true)
                return nil   // consume so the field doesn't submit (formatted paste)
            }
            return event
        }
    }

    func toggle() {
        if let panel = panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show(selection: AppState.SidebarSelection = .history) {
        // Remember who was frontmost so paste targets the right app.
        if panel?.isVisible != true {
            previousApp = NSWorkspace.shared.frontmostApplication
        }

        app.open(selection)

        let panel = self.panel ?? makePanel()
        self.panel = panel

        if let screen = NSScreen.main {
            let frame = panel.frame
            let x = screen.frame.midX - frame.width / 2
            let y = screen.frame.midY - frame.height / 2 + 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        app.titleEditingItemID = nil
        PanelDelegate.shared.suppressAutoHide = false
        panel?.orderOut(nil)
        // Return focus to the app the user was using so Cmd+V lands there.
        previousApp?.activate()
    }

    private func makePanel() -> FloatingPanel {
        let view = ClipboardPanelView(app: app)
        let hosting = NSHostingView(rootView: view)
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
        panel.delegate = PanelDelegate.shared
        return panel
    }
}

/// Hides the panel when it loses key status (click outside / app switch).
/// Skips auto-hide while an in-panel modal overlay (e.g. edit title) is open.
final class PanelDelegate: NSObject, NSWindowDelegate {
    static let shared = PanelDelegate()
    /// When true, `windowDidResignKey` will not order the panel out.
    var suppressAutoHide = false

    func windowDidResignKey(_ notification: Notification) {
        guard !suppressAutoHide else { return }
        (notification.object as? NSWindow)?.orderOut(nil)
    }
}
