import SwiftUI
import AppKit

/// The Spotlight-like floating panel: search field on top, history list below.
struct ClipboardPanelView: View {
    @ObservedObject var app: AppState
    // Selection and hover are tracked by stable item id (not list position) so
    // they stay attached to the right row when the list reorders or reloads.
    @State private var selectedID: Int64?
    @State private var hoveredID: Int64?
    @State private var editingItem: ClipboardItem?
    @FocusState private var searchFocused: Bool

    private var selectedIndex: Int {
        guard let id = selectedID else { return 0 }
        return app.items.firstIndex { $0.id == id } ?? 0
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                searchBar
                Divider()
                listView
            }
        }
        .frame(width: 720, height: 460)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
        .onAppear {
            searchFocused = true
            selectedID = app.items.first?.id
        }
        .onChange(of: app.items) { _, items in
            // Keep selection valid when the list reloads/reorders.
            if selectedID == nil || !items.contains(where: { $0.id == selectedID }) {
                selectedID = items.first?.id
            }
        }
        .onChange(of: app.selectionResetToken) { _, _ in
            // Always reselect the top item when entering a section / reopening.
            selectedID = app.items.first?.id
        }
        .onKeyPress(phases: .down) { press in handleKey(press) }
        .sheet(item: $editingItem) { item in
            EditTextView(text: item.contentText ?? "") { newText in
                app.updateText(item, text: newText)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search clipboard…", text: $app.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($searchFocused)
                .onSubmit { pasteSelected() }
            if !app.searchText.isEmpty {
                Button { app.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            sidebarRow(title: "History", systemImage: "clock", selection: .history)
            sidebarRow(title: "Pinned", systemImage: "pin", selection: .pinned)

            if !app.groups.isEmpty {
                Text("COLLECTIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 2)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(app.groups) { g in
                            sidebarRow(title: g.name, systemImage: "folder", selection: .group(g.id))
                        }
                    }
                }
            } else {
                Text("Create collections in Settings")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12).padding(.top, 12)
            }
            Spacer()
            Text("⇧⌘↑/↓ switch")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12).padding(.bottom, 4)
        }
        .padding(.vertical, 10)
        .frame(width: 180)
    }

    private func sidebarRow(title: String, systemImage: String,
                            selection: AppState.SidebarSelection,
                            hint: String? = nil) -> some View {
        let active = app.sidebarSelection == selection
        return Button {
            app.sidebarSelection = selection
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage).frame(width: 16)
                Text(title).lineLimit(1)
                Spacer()
                if let hint {
                    Text(hint).font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(active ? Color.white.opacity(0.8) : Color.secondary.opacity(0.6))
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(active ? Color.white : Color.primary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    @ViewBuilder private var listView: some View {
        if app.items.isEmpty {
            VStack(spacing: 6) {
                Spacer()
                Image(systemName: "tray").font(.system(size: 28)).foregroundStyle(.tertiary)
                Text(emptyMessage).font(.system(size: 13)).foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            itemList
        }
    }

    private var emptyMessage: String {
        if !app.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No results"
        }
        switch app.sidebarSelection {
        case .history: return "No clipboard history yet"
        case .pinned: return "No pinned items"
        case .group: return "This collection is empty"
        }
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(app.items.enumerated()), id: \.element.id) { index, item in
                        ClipboardRowView(
                            item: item,
                            index: index,
                            selected: item.id == selectedID,
                            hovered: item.id == hoveredID,
                            app: app,
                            onActivate: { selectedID = item.id; pasteSelected() },
                            onHoverChange: { isHovering in
                                if isHovering { hoveredID = item.id }
                                else if hoveredID == item.id { hoveredID = nil }
                            },
                            onEdit: { editingItem = item }
                        )
                    }
                }
                .padding(8)
            }
            // Scroll by the row's stable element id (matches the ForEach identity).
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    // MARK: - Keyboard

    /// Ordered sidebar sections: History, Pinned, then each collection.
    private var sections: [AppState.SidebarSelection] {
        [.history, .pinned] + app.groups.map { .group($0.id) }
    }

    private func switchSection(by delta: Int) {
        let all = sections
        let current = all.firstIndex(of: app.sidebarSelection) ?? 0
        let next = min(max(current + delta, 0), all.count - 1)
        app.sidebarSelection = all[next]
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        // Shift + Cmd + ↑/↓ → switch sidebar section (History / Pinned / collections)
        if press.modifiers.contains(.command), press.modifiers.contains(.shift) {
            switch press.key {
            case .downArrow: switchSection(by: 1); return .handled
            case .upArrow: switchSection(by: -1); return .handled
            default: break
            }
        }
        // Cmd + Delete → delete the selected item, keeping selection nearby
        if press.modifiers.contains(.command), press.key == .delete {
            deleteSelected()
            return .handled
        }
        // Cmd + 1...9 → quick paste
        if press.modifiers.contains(.command),
           let n = Int(press.characters), n >= 1, n <= 9 {
            let idx = n - 1
            if idx < app.items.count {
                app.pasteItem(app.items[idx])
            }
            return .handled
        }
        switch press.key {
        case .downArrow:
            if !app.items.isEmpty {
                let next = min(selectedIndex + 1, app.items.count - 1)
                selectedID = app.items[next].id
            }
            return .handled
        case .upArrow:
            if !app.items.isEmpty {
                let prev = max(selectedIndex - 1, 0)
                selectedID = app.items[prev].id
            }
            return .handled
        case .escape:
            PanelController.shared?.hide()
            return .handled
        case .return:
            pasteSelected()
            return .handled
        default:
            return .ignored
        }
    }

    private func pasteSelected() {
        guard selectedIndex < app.items.count, !app.items.isEmpty else { return }
        app.pasteItem(app.items[selectedIndex])
    }

    private func deleteSelected() {
        let idx = selectedIndex
        guard idx < app.items.count, !app.items.isEmpty else { return }
        let victim = app.items[idx]
        // Pick a neighbour to keep the cursor near where it was.
        let nextID: Int64? = idx + 1 < app.items.count ? app.items[idx + 1].id
            : (idx - 1 >= 0 ? app.items[idx - 1].id : nil)
        app.delete(victim)
        selectedID = nextID ?? app.items.first?.id
    }
}

/// A single row in the panel list.
struct ClipboardRowView: View {
    let item: ClipboardItem
    let index: Int
    let selected: Bool
    let hovered: Bool
    @ObservedObject var app: AppState
    let onActivate: () -> Void
    let onHoverChange: (Bool) -> Void
    let onEdit: () -> Void

    private var active: Bool { selected || hovered }

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview.isEmpty ? "(empty)" : item.preview)
                    .lineLimit(2)
                    .font(.system(size: 13))
                HStack(spacing: 6) {
                    if let icon = item.sourceAppIcon {
                        Image(nsImage: icon).resizable().frame(width: 12, height: 12)
                    }
                    if let app = item.sourceAppName {
                        Text(app).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Text(item.type.rawValue).font(.system(size: 10))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
                    if let host = item.urlHost {
                        Text(host).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Text(Self.relativeFormatter.localizedString(for: item.updatedAt, relativeTo: Date()))
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if index < 9 {
                Text("⌘\(index + 1)").font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            if item.isPinned && !active {
                Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(.orange)
            }
            if active {
                rowActions
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Color.accentColor.opacity(0.20) : (hovered ? Color.secondary.opacity(0.08) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        // Make the whole row (including empty space) hoverable/clickable.
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { onHoverChange($0) }
        .onTapGesture { onActivate() }
        .contextMenu { contextMenu }
    }

    @ViewBuilder private var thumbnail: some View {
        switch item.type {
        case .image:
            if let img = item.thumbnailImage {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 34, height: 34).clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                icon("photo")
            }
        case .file: icon("doc")
        case .url: icon("link")
        case .text: icon("text.alignleft")
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 15)).foregroundStyle(.secondary)
            .frame(width: 34, height: 34).background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var rowActions: some View {
        HStack(spacing: 6) {
            if app.isViewingBoard {
                iconButton("arrow.up") { app.moveItemInBoard(item, up: true) }
                iconButton("arrow.down") { app.moveItemInBoard(item, up: false) }
            }
            // Single pin toggle; colour/fill conveys the pinned state.
            Button { app.togglePin(item) } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin").font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(item.isPinned ? Color.orange : Color.secondary)
            .help(item.isPinned ? "Unpin" : "Pin")
            if item.type == .text || item.type == .url {
                iconButton("pencil") { onEdit() }
            }
        }
    }

    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: name).font(.system(size: 12)) }
            .buttonStyle(.plain).foregroundStyle(.secondary)
    }

    @ViewBuilder private var contextMenu: some View {
        Button("Paste") { onActivate() }
        Button("Copy") { app.copyItem(item) }
        Button(item.isPinned ? "Unpin" : "Pin") { app.togglePin(item) }
        if item.type == .text || item.type == .url {
            Button("Edit") { onEdit() }
        }
        if !app.groups.isEmpty {
            Menu("Add to Collection") {
                let inGroups = app.groupIDs(for: item)
                ForEach(app.groups) { g in
                    Button {
                        if inGroups.contains(g.id) { app.removeItem(item, fromGroup: g) }
                        else { app.addItem(item, toGroup: g) }
                    } label: {
                        Label(g.name, systemImage: inGroups.contains(g.id) ? "checkmark" : "")
                    }
                }
            }
        }
        if app.isViewingBoard, let board = app.currentBoard {
            Divider()
            Button("Move Up") { app.moveItemInBoard(item, up: true) }
            Button("Move Down") { app.moveItemInBoard(item, up: false) }
            Button("Remove from \(board.name)") { app.removeItem(item, fromGroup: board) }
        }
        Divider()
        Button("Delete", role: .destructive) { app.delete(item) }
    }

    static let relativeFormatter = RelativeDateTimeFormatter()
}

/// Sheet for editing a text item.
struct EditTextView: View {
    @State var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Edit Text").font(.headline)
            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .frame(width: 420, height: 240)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") { onSave(text); dismiss() }.keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
    }
}
