# DEVLOG.md

Append-only development log. Newest entries at the bottom. Never overwrite history.

## 2026-06-13

### Done

- Bootstrapped the ClipboardX MVP from scratch as a Swift Package Manager
  executable + AppKit/SwiftUI menu-bar app.
- Implemented the full core loop and most of v0.1–v0.3:
  - PasteboardMonitor (polls `changeCount`), AppFilter (excluded apps +
    concealed-type), ClipboardItemParser (text/url/image/file).
  - ClipboardStore over a thin SQLite3 wrapper: schema, dedup by hash, search,
    pin, groups, max-count cleanup with on-disk file deletion.
  - MenuBarController, Spotlight-style PanelController/ClipboardPanelView with
    keyboard nav and Cmd+1…9 quick-paste, HotkeyManager (Carbon), PasteExecutor
    (write-back + simulated Cmd+V + optional restore), SettingsStore/SettingsView.
  - `build_app.sh` packages a signed `.app`; `Resources/Info.plist` sets `LSUIElement`.
- Verified via terminal smoke tests: text, URL (auto-classified), image (saved to
  `images/` + `thumbs/`, DB stores paths), and file-path capture all work; dedup
  holds; search returns matches; DB + directories auto-create. Resident memory ~45MB.

### Files Changed

- Added `Package.swift`, `build_app.sh`, `Resources/Info.plist`, `README.md`,
  `.gitignore`, and all `Sources/ClipboardX/*.swift` modules.

### Current Status

- Builds cleanly (`swift build`, `./build_app.sh release`). MVP functional.
- Synced to GitHub `git@github.com:XinchaoGou/ClipboardX.git` (`main`).

### Next

- Add custom hotkey recording UI.
- Add an XCTest target for the store/parser.

### Risks

- Accessibility permission must be granted by the user for paste to work.
- DB access is on the main thread (fine for text; revisit for heavy image use).

## 2026-06-13 (later)

### Done

- Applied the Project Bootstrap Protocol: added `AGENTS.md` and `docs/`
  (`PRODUCT.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `DECISIONS.md`, `DEVLOG.md`).
- Trimmed `README.md` to "what it is + how to run" and added a docs index.

### Files Changed

- Added `AGENTS.md`, `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`,
  `docs/DECISIONS.md`, `docs/DEVLOG.md`. Edited `README.md`.

### Current Status

- Documentation system in place; code unchanged and still building.

### Next

- Proceed with the top Backlog item (custom hotkey recording UI) after confirmation.

### Risks

- None introduced by documentation changes.

## 2026-06-13 (bugfix: whitespace duplicate entries)

### Done

- Fixed a bug where copies differing only by trailing/leading whitespace or
  newlines (common with iTerm2 copy-on-select) created multiple history rows that
  looked identical in the preview (the preview is trimmed). Dedup hash for
  text/url is now computed from the trimmed text; raw text is still stored for
  byte-exact pasting. `ClipboardStore.updateText` hashes trimmed text too.
- Reproduced via terminal (3 whitespace variants → 3 rows before; 4 variants → 1
  row after the fix). Cleaned up test rows.

### Files Changed

- `Sources/ClipboardX/ClipboardItemParser.swift`, `Sources/ClipboardX/ClipboardStore.swift`
- `docs/DECISIONS.md` (entry 010), `docs/ROADMAP.md`

### Current Status

- Builds and packages cleanly; dedup now collapses whitespace-only variants.
- Note: pre-existing rows are not retroactively merged; only new copies dedup.

### Next

- Resume Backlog: custom hotkey recording UI (pending user confirmation).

### Risks

- Leading whitespace of a snippet's first line is ignored for dedup purposes
  only; stored/pasted content is unchanged, so paste fidelity is preserved.

## 2026-06-13 (bugfix: pin reorder / ghost rows in panel)

### Done

- Fixed panel rows rendering incorrectly after the list reorders (e.g. after
  pinning): rows could appear duplicated or keep stale hover/selection highlights
  on the wrong position. Cause: each row had an extra `.id(index)` (positional
  identity) on top of the `ForEach(id: \.element.id)` element identity. The two
  identities conflicted, so `@State` (hover) and view reuse tracked position
  instead of the item. Removed `.id(index)`; `scrollTo` now targets the row's
  stable element id. Verified pin works at the data layer (item flagged
  `is_pinned` and sorted to the top of the list).

### Files Changed

- `Sources/ClipboardX/ClipboardPanelView.swift`

### Current Status

- Builds, packages, relaunched. Pin moves items to the top cleanly without
  ghost/duplicate rows.

### Next

- Resume Backlog: custom hotkey recording UI (pending user confirmation).

### Risks

- Index-based `selection` still points to a position; after a reorder it may land
  on a neighbouring item. Cosmetic only; can switch selection to track item id later.

## 2026-06-13 (bugfix: panel hover/selection)

### Done

- Reworked the panel's selection/hover model. Previously hover lived in each
  row's `@State` (unreliable under `LazyVStack` view reuse — some rows wouldn't
  highlight, one stayed stuck selected) and selection was an index.
- Now both selection and hover are tracked in the parent by stable item id
  (`selectedID` / `hoveredID`); keyboard nav derives the index from the id.
- Made the whole row hit-testable with `frame(maxWidth:.infinity)` +
  `contentShape`, so hovering/clicking the empty area of a row works (previously
  only the text/icons responded). Tap-to-paste and onHover moved into the row.
- Cleared all local history (DB + images/thumbs/icons) at the user's request for
  a clean re-test.

### Files Changed

- `Sources/ClipboardX/ClipboardPanelView.swift`

### Current Status

- Builds, packages, relaunched with an empty history. Hover highlights every row
  consistently; selection follows the item across reloads/reorders.

### Next

- Resume Backlog: custom hotkey recording UI (pending user confirmation).

### Risks

- None known for selection/hover after this change.

## 2026-06-13 (feature: favorites/boards Phase 1 — iPaste-style)

### Done

- Discussed the favorites model against iPaste (Pin for single items, Groups as
  named collections summonable on their own). Decided on Plan A: a single `items`
  table where an item is a favorite (exempt from auto-cleanup) when pinned OR in
  any board; favorites still appear in History; History/Pinned/board are filtered
  views. Board create/delete stays in Settings; the panel uses a left sidebar.
- `ClipboardStore`: auto-cleanup (`enforceLimit`) and `clearAll` now exempt
  pinned items AND board members via `is_pinned = 0 AND id NOT IN (SELECT item_id
  FROM item_groups)`. `clearAll(keepPinned:)` → `clearAll(keepFavorites:)`.
- `AppState`: replaced `selectedGroupID` with a `SidebarSelection` enum
  (`history` / `pinned` / `group(id)`); `reload()` switches on it.
- `ClipboardPanelView`: replaced the top chip bar with a left sidebar (History,
  Pinned, COLLECTIONS list); widened the panel to 720pt; added empty-state views.
- `SettingsView`: relabeled clear buttons to "keep favorites".
- Verified cleanup-exemption SQL on a throwaway DB (pinned + board members spared).

### Files Changed

- `Sources/ClipboardX/ClipboardStore.swift`, `AppState.swift`,
  `ClipboardPanelView.swift`, `PanelController.swift`, `SettingsView.swift`
- `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`

### Current Status

- Builds, packages, relaunched. Sidebar switches between History / Pinned /
  collections; favorites survive auto-cleanup and "clear history (keep favorites)".

### Next

- Phase 2: manual ordering in boards (`item_groups.sort_order`), per-board and
  pinned quick hotkeys, boards submenu in the menu bar.

### Risks

- Existing rows created before this change are unaffected; board membership is
  evaluated live so no migration is needed.

## 2026-06-13 (feature: favorites/boards Phase 2)

### Done

- Per-board manual ordering: added `item_groups.sort_order` (with an idempotent
  `ALTER TABLE` migration for existing DBs). `addItem(toGroup:)` appends to the
  end; `itemsInGroup` orders by `sort_order`; new `setGroupOrder` persists a full
  ordering. `AppState.moveItemInBoard(_:up:)` swaps neighbours. Panel shows
  up/down buttons (and context-menu Move Up/Down + "Remove from <board>") only
  when viewing a board.
- Menu bar: added a "Collections" section where each board is a submenu of its
  items (click to paste).
- Global hotkeys: `Ctrl+Cmd+0` opens Pinned, `Ctrl+Cmd+1…9` open the first 9
  boards pre-filtered. Keys are registered once; the board is looked up live at
  trigger time (no re-registration when boards change). `PanelController.show`
  now takes a `selection`; `AppState.open(_:)` added. Sidebar shows hotkey hints.

### Files Changed

- `Sources/ClipboardX/ClipboardStore.swift`, `AppState.swift`,
  `ClipboardPanelView.swift`, `MenuBarController.swift`, `HotkeyManager.swift`,
  `AppDelegate.swift`, `PanelController.swift`
- `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`

### Current Status

- Builds, packages, relaunched. Verified `sort_order` migration + ordering and
  reorder against the live DB.

### Next

- Custom hotkey recording UI (also lets users remap the auto-assigned board keys).
- Drag-to-reorder within a board.

### Risks

- Board global hotkeys are auto-assigned by board order (first 9); remapping waits
  for the custom-hotkey UI. `Ctrl+Cmd+1…9` could in theory clash with a user's own
  global shortcuts.

## 2026-06-13 (change: in-panel section switch instead of global board hotkeys)

### Done

- Per user request, removed the global `Ctrl+Cmd+0` / `Ctrl+Cmd+1…9` hotkeys for
  Pinned/boards (no longer want global bindings for these).
- Added in-panel `Shift+Cmd+↑/↓` to cycle the sidebar selection through
  History → Pinned → each collection. Sidebar shows a "⇧⌘↑/↓ switch" hint and the
  per-row `Ctrl+Cmd` hints were removed.

### Files Changed

- `Sources/ClipboardX/AppDelegate.swift` (dropped board hotkey registration),
  `ClipboardPanelView.swift` (section switching + hints), `docs/ARCHITECTURE.md`

### Current Status

- Builds, packages, relaunched. Global hotkeys are now just `Shift+Cmd+V` (panel)
  and `Ctrl+Cmd+V` (plain-text paste).

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- None.

## 2026-06-13 (change: pinned items hidden from History)

### Done

- Per request, pinned items no longer appear in the History view. `recentItems`
  and `search` now filter `is_pinned = 0` (board members still show in History).
  The menu bar "Recent" section uses `store.recentItems()` directly so it is
  independent of the panel's current sidebar selection.
- Verified against the live DB: a pinned item shows only in Pinned, not History.

### Files Changed

- `Sources/ClipboardX/ClipboardStore.swift`, `MenuBarController.swift`,
  `docs/ARCHITECTURE.md`

### Current Status

- Builds, packages, relaunched. History = non-pinned; Pinned = pinned only.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- None.
