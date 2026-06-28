import Foundation
import AppKit
import Combine

/// Central coordinator shared between the menu bar, panel and settings UI.
@MainActor
final class AppState: ObservableObject {
    let store: ClipboardStore
    let settings: SettingsStore
    let paste: PasteExecutor

    /// Which "table" the panel is showing.
    enum SidebarSelection: Hashable {
        case history
        case pinned
        case group(Int64)
    }

    @Published var items: [ClipboardItem] = []
    @Published var groups: [Group] = []
    @Published var searchText: String = "" {
        didSet { reload(); requestSelectionReset() }
    }
    @Published var sidebarSelection: SidebarSelection = .history {
        didSet { reload(); requestSelectionReset() }
    }

    /// The currently highlighted item id in the panel. Lives here (not in the
    /// SwiftUI view) so the panel window can act on it from performKeyEquivalent.
    @Published var selectedID: Int64?

    /// Item id whose title overlay is open; nil when not editing. Lives in AppState
    /// so PanelController can clear it when the panel is dismissed.
    @Published var titleEditingItemID: Int64?

    /// Bumped whenever the panel should reset its selection to the first item
    /// (e.g. on entering a section, searching, or reopening the panel).
    @Published var selectionResetToken = 0

    func requestSelectionReset() { selectionResetToken &+= 1 }

    /// Paste the currently selected item (used by window-level key handling).
    func pasteSelected(plainText: Bool) {
        guard let id = selectedID, let item = items.first(where: { $0.id == id }) else { return }
        pasteItem(item, plainText: plainText)
    }

    init(store: ClipboardStore, settings: SettingsStore, paste: PasteExecutor) {
        self.store = store
        self.settings = settings
        self.paste = paste
        reload()
    }

    func reload() {
        do {
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch sidebarSelection {
            case .history:
                items = q.isEmpty ? try store.recentItems() : try store.search(searchText)
            case .pinned:
                let all = try store.pinnedItems()
                items = q.isEmpty ? all : all.filter { itemMatchesQuery($0, q) }
            case .group(let gid):
                let all = try store.itemsInGroup(gid)
                items = q.isEmpty ? all : all.filter { itemMatchesQuery($0, q) }
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

    func updateTitle(_ item: ClipboardItem, title: String) {
        try? store.updateTitle(id: item.id, title: title)
        reload()
    }

    /// Client-side filter for pinned/board views (history uses store.search).
    private func itemMatchesQuery(_ item: ClipboardItem, _ q: String) -> Bool {
        if item.trimmedTitle?.lowercased().contains(q) == true { return true }
        if item.preview.lowercased().contains(q) { return true }
        if item.sourceAppName?.lowercased().contains(q) == true { return true }
        return false
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
        if sidebarSelection == .group(group.id) { sidebarSelection = .history }
        reload()
    }

    func addItem(_ item: ClipboardItem, toGroup group: Group) {
        try? store.addItem(item.id, toGroup: group.id)
        reload()
    }

    /// Move an item up/down within the currently-selected board.
    func moveItemInBoard(_ item: ClipboardItem, up: Bool) {
        guard case .group(let gid) = sidebarSelection,
              let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let target = up ? idx - 1 : idx + 1
        guard target >= 0, target < items.count else { return }
        var ids = items.map(\.id)
        ids.swapAt(idx, target)
        try? store.setGroupOrder(groupID: gid, orderedItemIDs: ids)
        reload()
    }

    var isViewingBoard: Bool {
        if case .group = sidebarSelection { return true }
        return false
    }

    var currentBoard: Group? {
        if case .group(let gid) = sidebarSelection {
            return groups.first { $0.id == gid }
        }
        return nil
    }

    /// Open the panel pre-filtered to a specific sidebar selection.
    func open(_ selection: SidebarSelection) {
        searchText = ""
        sidebarSelection = selection
        reload()
    }

    func removeItem(_ item: ClipboardItem, fromGroup group: Group) {
        try? store.removeItem(item.id, fromGroup: group.id)
        reload()
    }

    func groupIDs(for item: ClipboardItem) -> Set<Int64> {
        Set((try? store.groupIDs(forItem: item.id)) ?? [])
    }

    func clearHistory(keepFavorites: Bool) {
        try? store.clearAll(keepFavorites: keepFavorites)
        reload()
    }
}
