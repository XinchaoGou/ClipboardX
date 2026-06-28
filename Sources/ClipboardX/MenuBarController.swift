import AppKit

/// Owns the menu bar status item and its dropdown menu.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let app: AppState
    private let onOpenPanel: () -> Void
    private let onOpenSettings: () -> Void

    init(app: AppState, onOpenPanel: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.app = app
        self.onOpenPanel = onOpenPanel
        self.onOpenSettings = onOpenSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipboardX")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        app.reload()

        let open = NSMenuItem(title: "Open Clipboard Panel", action: #selector(openPanel), keyEquivalent: "v")
        open.keyEquivalentModifierMask = [.command, .shift]
        open.target = self
        MenuItemImagePolicy.setExplicitMenuImage(open, image: nil)
        open.indentationLevel = 0
        menu.addItem(open)
        menu.addItem(.separator())

        // Pinned section
        let pinned = (try? app.store.pinnedItems()) ?? []
        if !pinned.isEmpty {
            menu.addItem(sectionHeader("Pinned"))
            for item in pinned.prefix(10) {
                menu.addItem(makeItem(item))
            }
            menu.addItem(.separator())
        }

        // Recent section (history excludes pinned; independent of the panel's view).
        // Collections (boards) live in the panel only — not listed in the status menu.
        menu.addItem(sectionHeader("Recent"))
        let recent = ((try? app.store.recentItems()) ?? []).prefix(15)
        if recent.isEmpty {
            let empty = NSMenuItem(title: "No history yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            empty.indentationLevel = 0
            menu.addItem(empty)
        } else {
            for (i, item) in recent.enumerated() {
                let mi = makeItem(item)
                if i < 9 {
                    mi.keyEquivalent = "\(i + 1)"
                    mi.keyEquivalentModifierMask = [.command]
                }
                menu.addItem(mi)
            }
        }

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        MenuItemImagePolicy.setExplicitMenuImage(settings, image: nil)
        settings.indentationLevel = 0
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit ClipboardX", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        quit.keyEquivalentModifierMask = [.command]
        MenuItemImagePolicy.setExplicitMenuImage(quit, image: nil)
        quit.indentationLevel = 0
        menu.addItem(quit)
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.indentationLevel = 0
        MenuItemImagePolicy.setExplicitMenuImage(item, image: nil)
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        return item
    }

    private func makeItem(_ item: ClipboardItem) -> NSMenuItem {
        let title = singleLine(item.listPrimaryLine)
        let mi = NSMenuItem(title: title, action: #selector(pasteItem(_:)), keyEquivalent: "")
        mi.target = self
        mi.representedObject = item.id
        mi.indentationLevel = 0
        if let icon = item.sourceAppIcon {
            icon.size = NSSize(width: 16, height: 16)
            MenuItemImagePolicy.setExplicitMenuImage(mi, image: icon)
        } else if item.type == .image, let thumb = item.thumbnailImage {
            thumb.size = NSSize(width: 16, height: 16)
            MenuItemImagePolicy.setExplicitMenuImage(mi, image: thumb)
        } else {
            MenuItemImagePolicy.setExplicitMenuImage(mi, image: nil)
        }
        return mi
    }

    private func singleLine(_ s: String) -> String {
        let oneLine = s.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        let max = 50
        let display = oneLine.isEmpty ? "(empty)" : oneLine
        return display.count > max ? String(display.prefix(max)) + "…" : display
    }

    @objc private func openPanel() { onOpenPanel() }
    @objc private func openSettings() { onOpenSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func pasteItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? Int64,
              let item = try? app.store.item(id: id) else { return }
        app.pasteItem(item)
    }
}
