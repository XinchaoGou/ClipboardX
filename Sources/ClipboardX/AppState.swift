import Foundation
import AppKit
import Combine

/// Central coordinator shared between the menu bar, panel and settings UI.
@MainActor
final class AppState: ObservableObject {
    let store: ClipboardStore
    let settings: SettingsStore
    let paste: PasteExecutor

    @Published var items: [ClipboardItem] = []
    @Published var groups: [Group] = []
    @Published var searchText: String = "" {
        didSet { reload() }
    }
    @Published var selectedGroupID: Int64? {
        didSet { reload() }
    }

    init(store: ClipboardStore, settings: SettingsStore, paste: PasteExecutor) {
        self.store = store
        self.settings = settings
        self.paste = paste
        reload()
    }

    func reload() {
        do {
            if let gid = selectedGroupID {
                let all = try store.itemsInGroup(gid)
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                items = q.isEmpty ? all : all.filter { $0.preview.lowercased().contains(q) }
            } else if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                items = try store.recentItems()
            } else {
                items = try store.search(searchText)
            }
            groups = try store.groups()
        } catch {
            NSLog("ClipboardX: reload failed: \(error)")
        }
    }

    // MARK: - Item actions

    func pasteItem(_ item: ClipboardItem, plainText: Bool = false) {
        PanelController.shared?.hide()
        try? store.touch(id: item.id)
        paste.paste(item, plainText: plainText)
        reload()
    }

    func copyItem(_ item: ClipboardItem) {
        paste.copyToPasteboard(item)
        try? store.touch(id: item.id)
        reload()
    }

    func togglePin(_ item: ClipboardItem) {
        try? store.setPinned(id: item.id, pinned: !item.isPinned)
        reload()
    }

    func delete(_ item: ClipboardItem) {
        try? store.delete(id: item.id)
        reload()
    }

    func updateText(_ item: ClipboardItem, text: String) {
        try? store.updateText(id: item.id, text: text)
        reload()
    }

    // MARK: - Groups

    func createGroup(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = try? store.createGroup(name: trimmed)
        reload()
    }

    func deleteGroup(_ group: Group) {
        try? store.deleteGroup(id: group.id)
        if selectedGroupID == group.id { selectedGroupID = nil }
        reload()
    }

    func addItem(_ item: ClipboardItem, toGroup group: Group) {
        try? store.addItem(item.id, toGroup: group.id)
        reload()
    }

    func removeItem(_ item: ClipboardItem, fromGroup group: Group) {
        try? store.removeItem(item.id, fromGroup: group.id)
        reload()
    }

    func groupIDs(for item: ClipboardItem) -> Set<Int64> {
        Set((try? store.groupIDs(forItem: item.id)) ?? [])
    }

    func clearHistory(keepPinned: Bool) {
        try? store.clearAll(keepPinned: keepPinned)
        reload()
    }
}
