import SwiftUI
import AppKit

/// The Spotlight-like floating panel: search field on top, history list below.
struct ClipboardPanelView: View {
    @ObservedObject var app: AppState
    // Selection (in AppState) and hover are tracked by stable item id (not list
    // position) so they stay attached to the right row when the list reorders.
    @State private var hoveredID: Int64?
    /// Increment to re-focus the AppKit search field (e.g. after closing edit overlay).
    @State private var searchFocusTrigger = 0

    private var editingItem: ClipboardItem? {
        guard let id = app.editingItemID else { return nil }
        return app.items.first(where: { $0.id == id })
    }

    private var selectedIndex: Int {
        guard let id = app.selectedID else { return 0 }
        return app.items.firstIndex { $0.id == id } ?? 0
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                searchBar
                Divider()
                collectionAddHintBar
                listView
            }
        }
        .frame(width: 720, height: 460)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
        // Cmd+Delete / Cmd+P / Cmd+E work even while the search field is focused.
        // (Shift+Return for plain paste is handled at the window level in
        // PanelController's key monitor, since the field swallows it here.)
        .background(
            ZStack {
                Button("", action: deleteSelected)
                    .keyboardShortcut(.delete, modifiers: .command)
                Button("", action: pinSelected)
                    .keyboardShortcut("p", modifiers: .command)
                Button("", action: editSelected)
                    .keyboardShortcut("e", modifiers: .command)
            }
            .opacity(0)
            .accessibilityHidden(true)
        )
        .onAppear {
            searchFocusTrigger += 1
            app.selectedID = app.items.first?.id
        }
        .onChange(of: app.items) { _, items in
            // Keep selection valid when the list reloads/reorders.
            if app.selectedID == nil || !items.contains(where: { $0.id == app.selectedID }) {
                app.selectedID = items.first?.id
            }
        }
        .onChange(of: app.selectionResetToken) { _, _ in
            // Always reselect the top item when entering a section / reopening.
            app.selectedID = app.items.first?.id
        }
        .modifier(PanelKeyboardHandler(isEnabled: app.editingItemID == nil, handler: handleKey))
        .overlay { itemEditOverlay }
        .onChange(of: app.editingItemID) { _, id in
            if id == nil { restorePanelFocus() }
        }
    }

    /// Return keyboard control to the search field after the edit overlay closes.
    /// AppKit fields in the overlay (IMETextField) steal first responder; SwiftUI
    /// focus state does not reliably take it back for arrow-key navigation.
    private func restorePanelFocus() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        searchFocusTrigger += 1
    }

    @ViewBuilder
    private var itemEditOverlay: some View {
        if let item = editingItem {
            let showsTextEditor = item.type == .text || item.type == .url
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        app.editingItemID = nil
                    }
                EditItemView(
                    title: item.title ?? "",
                    text: item.contentText ?? "",
                    showsTextEditor: showsTextEditor,
                    onSave: { newTitle, newText in
                        app.updateTitle(item, title: newTitle)
                        if showsTextEditor, let newText {
                            app.updateText(item, text: newText)
                        }
                        app.editingItemID = nil
                    },
                    onCancel: {
                        app.editingItemID = nil
                    }
                )
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
            }
            .onAppear { PanelDelegate.shared.suppressAutoHide = true }
            .onDisappear { PanelDelegate.shared.suppressAutoHide = false }
            .onKeyPress(phases: .down) { press in
                if press.key == .escape {
                    app.editingItemID = nil
                    return .handled
                }
                return .ignored
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            IMETextField(
                text: $app.searchText,
                placeholder: "Search clipboard…",
                bordered: false,
                font: .systemFont(ofSize: 16),
                focusTrigger: searchFocusTrigger,
                onReturn: { pasteSelected() }
            )
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
            // Whole row (including trailing empty space) is clickable.
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private var isViewingGroup: Bool {
        if case .group = app.sidebarSelection { return true }
        return false
    }

    /// Shown when a collection is selected and the list has rows (empty state has its own copy).
    @ViewBuilder private var collectionAddHintBar: some View {
        if isViewingGroup, !app.items.isEmpty {
            Text("Add more from History or Pinned: right-click a row → Add to Collection.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            Divider()
        }
    }

    @ViewBuilder private var listView: some View {
        if app.items.isEmpty {
            VStack(spacing: 6) {
                Spacer()
                Image(systemName: "tray").font(.system(size: 28)).foregroundStyle(.tertiary)
                Text(emptyMessage).font(.system(size: 13)).foregroundStyle(.secondary)
                if isViewingGroup {
                    Text("Add from History or Pinned: right-click any row → Add to Collection.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
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
                            selected: item.id == app.selectedID,
                            hovered: item.id == hoveredID,
                            app: app,
                            onActivate: { app.selectedID = item.id; pasteSelected() },
                            onHoverChange: { isHovering in
                                if isHovering { hoveredID = item.id }
                                else if hoveredID == item.id { hoveredID = nil }
                            },
                            onEdit: {
                                NSApp.keyWindow?.makeFirstResponder(nil)
                                app.editingItemID = item.id
                            }
                        )
                    }
                }
                .padding(8)
            }
            // Scroll by the row's stable element id (matches the ForEach identity).
            .onChange(of: app.selectedID) { _, id in
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
                app.selectedID = app.items[next].id
            }
            return .handled
        case .upArrow:
            if !app.items.isEmpty {
                let prev = max(selectedIndex - 1, 0)
                app.selectedID = app.items[prev].id
            }
            return .handled
        case .escape:
            PanelController.shared?.hide()
            return .handled
        case .return:
            // Paste-on-Return is handled by the search IMETextField (IME-safe).
            // Ignore here so CJK composition is not interrupted.
            return .ignored
        default:
            return .ignored
        }
    }

    private func pasteSelected(plainText: Bool = false) {
        guard selectedIndex < app.items.count, !app.items.isEmpty else { return }
        app.pasteItem(app.items[selectedIndex], plainText: plainText)
    }

    private func deleteSelected() {
        let idx = selectedIndex
        guard idx < app.items.count, !app.items.isEmpty else { return }
        let victim = app.items[idx]
        // Pick a neighbour to keep the cursor near where it was.
        let nextID: Int64? = idx + 1 < app.items.count ? app.items[idx + 1].id
            : (idx - 1 >= 0 ? app.items[idx - 1].id : nil)
        app.delete(victim)
        app.selectedID = nextID ?? app.items.first?.id
    }

    private func pinSelected() {
        guard app.editingItemID == nil else { return }
        let idx = selectedIndex
        guard idx < app.items.count, !app.items.isEmpty else { return }
        app.togglePin(app.items[idx])
    }

    private func editSelected() {
        guard app.editingItemID == nil else { return }
        let idx = selectedIndex
        guard idx < app.items.count, !app.items.isEmpty else { return }
        NSApp.keyWindow?.makeFirstResponder(nil)
        app.editingItemID = app.items[idx].id
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

    private var previewLine: String {
        let p = item.preview.trimmingCharacters(in: .whitespacesAndNewlines)
        return p.isEmpty ? "(empty)" : p
    }

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                if let title = item.trimmedTitle {
                    Text(title)
                        .lineLimit(1)
                        .font(.system(size: 13, weight: .medium))
                    Text(previewLine)
                        .lineLimit(1)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text(previewLine)
                        .lineLimit(2)
                        .font(.system(size: 13))
                }
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
            iconButton("pencil") { onEdit() }
                .help("Edit")
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
        Button("Edit…") { onEdit() }
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

/// In-panel editor for an item's title and optional text content (overlay, not
/// sheet — keeps the floating panel key so auto-hide-on-resign-key and IME work).
struct EditItemView: View {
    @State var title: String
    @State var text: String
    let showsTextEditor: Bool
    let onSave: (String, String?) -> Void
    let onCancel: () -> Void

    private var hasTitle: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formBody
            Divider()
            footer
        }
        .frame(width: 440)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Edit Item")
                    .font(.system(size: 15, weight: .semibold))
                Text(showsTextEditor ? "Update title and text content" : "Update display title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var formBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            editField(
                label: "Title",
                hint: "Shown in lists and search; does not change pasted content."
            ) {
                IMETextField(text: $title, placeholder: "Title (optional)", bordered: false)
                    .frame(height: 22)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(fieldBackground)
            }

            if showsTextEditor {
                editField(
                    label: "Text",
                    hint: "Editing drops rich formatting."
                ) {
                    TextEditor(text: $text)
                        .font(.system(size: 13, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 120, maxHeight: 180)
                        .background(fieldBackground)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

            if hasTitle {
                Button("Clear Title") {
                    onSave("", showsTextEditor ? text : nil)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("Save") {
                onSave(title, showsTextEditor ? text : nil)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func editField<Content: View>(
        label: String,
        hint: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.4)
            content()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fieldBackground: some View {
        Color.primary.opacity(0.04)
    }
}

/// AppKit text field wrapper for reliable CJK IME input (SwiftUI TextField is flaky here).
struct IMETextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var bordered: Bool = true
    var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    var autoFocus: Bool = true
    var focusTrigger: Int = 0
    var onReturn: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        if bordered {
            field.isBezeled = true
            field.bezelStyle = .roundedBezel
            field.focusRingType = .default
        } else {
            field.isBezeled = false
            field.drawsBackground = false
            field.focusRingType = .none
        }
        field.font = font
        context.coordinator.onReturn = onReturn
        if autoFocus {
            DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.onReturn = onReturn
        if field.font != font {
            field.font = font
        }
        if field.stringValue != text {
            field.stringValue = text
        }
        if focusTrigger != context.coordinator.lastFocusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    static func dismantleNSView(_ field: NSTextField, coordinator: Coordinator) {
        // Release first responder before the overlay is torn down; otherwise arrow
        // keys stop reaching panel navigation until the panel is reopened.
        if field.window?.firstResponder === field
            || field.window?.firstResponder === field.currentEditor() {
            field.window?.makeFirstResponder(nil)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onReturn: (() -> Void)?
        var lastFocusTrigger = 0

        init(text: Binding<String>) { self.text = text }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            // Let the IME consume Return while marked (pre-)text is active.
            if textView.hasMarkedText() { return false }
            onReturn?()
            return onReturn != nil
        }
    }
}

/// Applies panel navigation shortcuts only when item editing is not active.
private struct PanelKeyboardHandler: ViewModifier {
    let isEnabled: Bool
    let handler: (KeyPress) -> KeyPress.Result

    func body(content: Content) -> some View {
        if isEnabled {
            content.onKeyPress(phases: .down, action: handler)
        } else {
            content
        }
    }
}
