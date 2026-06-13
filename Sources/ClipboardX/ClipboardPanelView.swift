import SwiftUI
import AppKit

/// The Spotlight-like floating panel: search field on top, history list below.
struct ClipboardPanelView: View {
    @ObservedObject var app: AppState
    @State private var selection: Int = 0
    @State private var editingItem: ClipboardItem?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if app.groups.isEmpty == false {
                groupBar
                Divider()
            }
            listView
        }
        .frame(width: 640, height: 460)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
        .onAppear {
            searchFocused = true
            selection = 0
        }
        .onChange(of: app.items.count) { _, _ in
            if selection >= app.items.count { selection = max(0, app.items.count - 1) }
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

    private var groupBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: "All", active: app.selectedGroupID == nil) { app.selectedGroupID = nil }
                ForEach(app.groups) { g in
                    chip(title: g.name, active: app.selectedGroupID == g.id) {
                        app.selectedGroupID = (app.selectedGroupID == g.id) ? nil : g.id
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(active ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(active ? Color.white : Color.primary)
                .clipShape(Capsule())
        }.buttonStyle(.plain)
    }

    private var listView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(app.items.enumerated()), id: \.element.id) { index, item in
                        ClipboardRowView(
                            item: item,
                            index: index,
                            selected: index == selection,
                            app: app,
                            onActivate: { selection = index; pasteSelected() },
                            onEdit: { editingItem = item }
                        )
                        .onTapGesture { selection = index; pasteSelected() }
                    }
                }
                .padding(8)
            }
            // Scroll by the row's stable element id (matches the ForEach identity).
            // Do NOT add an extra `.id(index)` to rows — a positional identity that
            // conflicts with the element identity causes ghost/duplicate rows when
            // the list reorders (e.g. after pinning).
            .onChange(of: selection) { _, new in
                guard new < app.items.count else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(app.items[new].id, anchor: .center)
                }
            }
        }
    }

    // MARK: - Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        // Cmd + 1...9 → quick paste
        if press.modifiers.contains(.command),
           let n = Int(press.characters), n >= 1, n <= 9 {
            let idx = n - 1
            if idx < app.items.count {
                selection = idx
                pasteSelected()
            }
            return .handled
        }
        switch press.key {
        case .downArrow:
            if !app.items.isEmpty { selection = min(selection + 1, app.items.count - 1) }
            return .handled
        case .upArrow:
            if !app.items.isEmpty { selection = max(selection - 1, 0) }
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
        guard selection < app.items.count else { return }
        app.pasteItem(app.items[selection])
    }
}

/// A single row in the panel list.
struct ClipboardRowView: View {
    let item: ClipboardItem
    let index: Int
    let selected: Bool
    @ObservedObject var app: AppState
    let onActivate: () -> Void
    let onEdit: () -> Void
    @State private var hovering = false

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
            if item.isPinned {
                Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(.orange)
            }
            if hovering || selected {
                rowActions
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(selected ? Color.accentColor.opacity(0.20) : (hovering ? Color.secondary.opacity(0.08) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering = $0 }
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
            iconButton("doc.on.clipboard") { app.copyItem(item) }
            iconButton(item.isPinned ? "pin.slash" : "pin") { app.togglePin(item) }
            if item.type == .text || item.type == .url {
                iconButton("pencil") { onEdit() }
            }
            iconButton("trash") { app.delete(item) }
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
            Menu("Add to Group") {
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
