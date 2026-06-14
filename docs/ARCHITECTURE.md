# ARCHITECTURE.md

Current, real architecture (not planned). Update when the architecture changes.

## Tech stack

- Language: Swift 5.9 (Swift 5 language mode), targeting macOS 14+.
- UI: SwiftUI for the panel/settings, AppKit for the status item, panel window,
  and global event plumbing.
- Storage: system `sqlite3` accessed through an in-repo thin wrapper (`SQLite.swift`).
- Packaging: Swift Package Manager executable, bundled into a `.app` by `build_app.sh`.
- No third-party runtime dependencies.

## Capture data flow

```
NSPasteboard.general
        │  (poll changeCount every ~0.4s)
        ▼
PasteboardMonitor
        │  frontmost app (metadata)
        ▼
AppFilter   (resolve front app + cache source icon)
        │
        ▼
ClipboardItemParser   (classify text/url/image/file,
        │              write image + thumbnail to disk)
        ▼
ClipboardStore  ──▶  SQLite (clipboard.db)  +  images/ thumbs/ icons/
        │  dedup by hash, enforce max-count cleanup
        ▼
AppState (@MainActor, ObservableObject)  ──▶  UI reload
```

## Paste data flow

```
UI (MenuBar / Panel)
        ▼
AppState.pasteItem
        ▼
PasteExecutor
   ├─ write item back to NSPasteboard
   ├─ tell PasteboardMonitor to ignore this self-write
   ├─ simulate Cmd+V via CGEvent (needs Accessibility)
   └─ optional: restore previous pasteboard contents
```

## Layers

```
UI            MenuBarController · ClipboardPanelView/PanelController · SettingsView
  ↓
Coordinator   AppState (@MainActor view model)
  ↓
Services      PasteboardMonitor · ClipboardItemParser · AppFilter ·
              PasteExecutor · HotkeyManager · SettingsStore
  ↓
Storage       ClipboardStore  →  SQLite (thin wrapper)  +  on-disk files (Storage)
```

## Modules

| File | Responsibility |
| --- | --- |
| `main.swift` | Entry point; boots `NSApplication` + `AppDelegate` |
| `AppDelegate.swift` | Wires all components, sets `.accessory` policy, registers hotkeys |
| `AppState.swift` | `@MainActor` coordinator/view model shared by all UI |
| `PasteboardMonitor.swift` | Polls `changeCount`, filters, stores; ignores self-writes |
| `ClipboardItemParser.swift` | Classifies content, persists images/thumbnails |
| `AppFilter.swift` | Frontmost app for metadata, source-app icon caching |
| `ClipboardStore.swift` | Schema, CRUD, search, pin, groups, max-count cleanup |
| `SQLite.swift` | Throwing wrapper over the SQLite3 C API |
| `Models.swift` | `ClipboardItem`, `Group`, `ItemType` |
| `Storage.swift` | On-disk path resolution + directory creation |
| `Hashing.swift` | SHA-256 content hashing (dedup + file naming) |
| `MenuBarController.swift` | `NSStatusItem` dropdown menu |
| `PanelController.swift` | Floating `NSPanel` host + show/hide/focus handling |
| `ClipboardPanelView.swift` | SwiftUI search panel, list rows, edit sheet |
| `HotkeyManager.swift` | Global hotkeys via Carbon `RegisterEventHotKey` (toggle panel `Shift+Cmd+V`) |
| `PasteExecutor.swift` | Pasteboard write-back + simulated Cmd+V + restore |
| `SettingsStore.swift` | `UserDefaults`-backed preferences |
| `SettingsView.swift` | SwiftUI settings + settings window controller |

## Favorites model (boards)

There is a single `items` table. An item is a "favorite" — and therefore exempt
from auto-cleanup and from "clear history (keep favorites)" — when it is
**pinned** (`is_pinned = 1`) OR it belongs to **at least one board** (a row in
`item_groups`). Boards are the user's named collections (the `groups` table).
History, Pinned and each board are filtered views over the same rows
(`AppState.SidebarSelection`). **Pinned items are excluded from the History view**
(they live only in Pinned); board members still appear in History.

## Data model

`items` (clipboard records), `groups` (a.k.a. boards/collections),
`item_groups` (many-to-many join, with `sort_order` for per-board manual ordering).
Item fields: id, type, content_text, content_hash, file_paths_json, image_path,
thumbnail_path, source_app_name/bundle_id/icon_path, created_at, updated_at,
last_used_at, use_count, is_pinned, deleted_at.

## On-disk layout

```
~/Library/Application Support/ClipboardX/
├── clipboard.db      # SQLite (WAL mode)
├── images/           # full-size copied images (PNG)
├── thumbs/           # list thumbnails
├── icons/            # cached source-app icons
└── rtf/              # captured RTF for formatted paste (path in items.rtf_path)
```

## Rich text (formatted paste)

When a text item is recorded, the source app's RTF (or HTML converted to RTF) is
saved to `rtf/<hash>.rtf` and referenced by `items.rtf_path`. Pasting with
**Return** writes the RTF plus a plain-text fallback (the target app picks the
richest it supports); **Shift+Return** writes plain text only. Editing a text
item clears its RTF.

## Permissions

- **Accessibility** — required to synthesize Cmd+V on paste.
- **Launch at Login** — via `SMAppService.mainApp` (works from the signed `.app`).
