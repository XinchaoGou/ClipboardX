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

## 2026-06-13 (chore: app icon + install to /Applications)

### Done

- Added an app icon: generated a clipboard-stack artwork, then `scripts/make_icon.swift`
  detects the artwork bounds, crops square, and re-rounds the corners with a
  transparent mask → `Resources/AppIcon-1024.png`. Built `Resources/AppIcon.icns`
  via `sips` + `iconutil`. `build_app.sh` copies the icns into the bundle and
  `Info.plist` sets `CFBundleIconFile`.
- Installed the release build to `/Applications/ClipboardX.app` (ad-hoc signed),
  refreshed the icon cache. Menu-bar glyph stays the monochrome SF Symbol template.

### Files Changed

- `Resources/Info.plist`, `build_app.sh`, `.gitignore`,
  `Resources/icon.png`, `Resources/AppIcon-1024.png`, `Resources/AppIcon.icns`,
  `scripts/make_icon.swift`

### Current Status

- v0.2 installed in /Applications with an icon and running.

### Note

- Moving the app to /Applications changes its path, so Accessibility permission
  must be re-granted for the installed copy.

## 2026-06-13 (fix: Shift+Return plain paste — take 2, local event monitor)

### Done

- First attempt (SwiftUI `keyboardShortcut`, then `performKeyEquivalent`) didn't
  work: Shift+Return was still treated as submit (formatted paste). `performKey-
  Equivalent` isn't reliably invoked for shift-only Return.
- Moved panel selection (`selectedID`) into `AppState` with `pasteSelected(plain:)`.
  `PanelController` now installs an `NSEvent.addLocalMonitorForEvents(.keyDown)`
  that, while the panel is the key window, consumes Shift+Return (keyCode 36,
  shift-only) and pastes the selection as plain text — intercepting it before the
  field editor can submit. Cmd+Delete button kept.

### Files Changed

- `Sources/ClipboardX/AppState.swift`, `ClipboardPanelView.swift`,
  `PanelController.swift`

### Current Status

- Builds, packages, relaunched. Return = formatted, Shift+Return = plain
  (via local key monitor).

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- The local monitor only acts while our panel is key; other windows unaffected.

## 2026-06-13 (feature: formatted paste — Return vs Shift+Return)

### Done

- Capture rich text on copy: the parser saves the pasteboard's RTF (or HTML→RTF)
  to `rtf/<hash>.rtf`; new `items.rtf_path` column (appended last, with migration)
  + `Storage.rtfDir`. `removeFiles`/cleanup delete the RTF; `updateText` clears it.
- Paste: `PasteExecutor.writeToPasteboard` writes RTF + plain fallback when not
  plain; plain string only when plain. Panel: **Return** = formatted (existing
  onSubmit), **Shift+Return** = plain via a hidden `keyboardShortcut(.return,
  modifiers: .shift)` button (so the focused search field doesn't swallow it).
- Verified capture against the live DB (bold/red RTF copied → `rtf_path` set, file
  written). Updated PRODUCT/ARCHITECTURE/DECISIONS/ROADMAP.

### Files Changed

- `Sources/ClipboardX/Storage.swift`, `Models.swift`, `ClipboardStore.swift`,
  `ClipboardItemParser.swift`, `PasteExecutor.swift`, `ClipboardPanelView.swift`,
  `AppDelegate.swift`; docs.

### Current Status

- Builds, packages, relaunched. Return = formatted, Shift+Return = plain.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- Formatting fidelity depends on the source app providing RTF/HTML; if absent,
  formatted paste is identical to plain (no harm).

## 2026-06-13 (fix: Cmd+Delete not firing)

### Done

- Cmd+Delete did nothing because the focused search `TextField` consumed it
  (delete-to-start-of-line). Replaced the `onKeyPress` branch with a hidden
  `Button(...).keyboardShortcut(.delete, modifiers: .command)`, which is dispatched
  via the window's key-equivalent path before the text field's keyDown, so it works
  regardless of focus.

### Files Changed

- `Sources/ClipboardX/ClipboardPanelView.swift`

### Current Status

- Builds, packages, relaunched.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- None.

## 2026-06-13 (change: remove copy/delete row buttons; Cmd+Delete to delete)

### Done

- Removed the per-row Copy and Delete buttons. Row actions are now: move up/down
  (in a board), the pin toggle, and edit (text/url). Delete is via `Cmd+Delete` on
  the selected item; selection moves to a neighbour afterwards. (Copy/Delete are
  still available in the right-click context menu.)

### Files Changed

- `Sources/ClipboardX/ClipboardPanelView.swift`

### Current Status

- Builds, packages, relaunched.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- None.

## 2026-06-13 (change: single pin toggle button)

### Done

- Replaced the separate pin / unpin (`pin` vs `pin.slash`) icons with one toggle
  button whose state is shown by colour/fill: orange `pin.fill` when pinned, grey
  `pin` when not. The standalone status pin is hidden while the row is active to
  avoid showing two pins on hover.

### Files Changed

- `Sources/ClipboardX/ClipboardPanelView.swift`

### Current Status

- Builds, packages, relaunched.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- None.

## 2026-06-13 (change: always select top item when entering a section)

### Done

- Switching sections (sidebar click / `Shift+Cmd+↑↓`), searching, or reopening the
  panel now always reselects the first item instead of remembering the previous
  selection. Implemented via `AppState.selectionResetToken` (bumped from the
  `searchText` / `sidebarSelection` setters); the panel resets `selectedID` on
  token change. Live clipboard updates while viewing do not move the selection.

### Files Changed

- `Sources/ClipboardX/AppState.swift`, `ClipboardPanelView.swift`

### Current Status

- Builds, packages, relaunched.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- None.

## 2026-06-14

### Done

- Removed privacy filtering from capture: no `excludedBundleIDs` in settings, no
  Settings "Excluded Apps" tab, no skip for concealed/transient/auto-generated
  pasteboard types, no `AppFilter.shouldSkip`. `PasteboardMonitor` always records
  parseable changes (still ignores self-writes from `PasteExecutor`).

### Files Changed

- `Sources/ClipboardX/AppFilter.swift`, `PasteboardMonitor.swift`, `SettingsStore.swift`,
  `SettingsView.swift`
- `AGENTS.md`, `README.md`, `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`,
  `docs/DECISIONS.md`

### Current Status

- `swift build` + `./build_app.sh release` succeed.
- Smoke test: launched `build/ClipboardX.app`, `pbcopy` a unique line, confirmed new
  row in `~/Library/Application Support/ClipboardX/clipboard.db` within ~1s.
- Static check: no `Excluded` / `excludedBundle` / `shouldSkip` / `isConcealed` in
  `Sources/**/*.swift`.
- Settings UI not screenshot-verified here: `osascript` + System Events needs
  assistive access for this environment (blocked with -25211); please open
  Settings and confirm only General / Groups / Permissions tabs.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- Users who relied on exclusions will now have passwords/secrets in history if they
  copy from password managers; product choice to record everything.

## 2026-06-14 (settings copy: plain paste vs ^⌘V)

### Done

- Clarified that **^⌘V** is a global shortcut (current clipboard → plain paste) and
  is the only behavior gated by `enablePlainTextPaste`. **Shift+Return** in the
  panel pastes the **selected history row** as plain text and is always available;
  it is not controlled by that toggle. Updated `SettingsView` labels/caption and
  README panel bullet.

### Files Changed

- `Sources/ClipboardX/SettingsView.swift`, `README.md`, `docs/ROADMAP.md`,
  `docs/DEVLOG.md`

### Current Status

- `swift build` succeeds.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- None.

## 2026-06-14 (remove global ^⌘V plain paste)

### Done

- Removed the global `Ctrl+Cmd+V` hotkey, `pastePlainTextFromClipboard()`, and
  `SettingsStore.enablePlainTextPaste` / settings UI. Plain vs formatted paste is
  only in the history panel: **Return** vs **Shift+Return** (`PanelController` local
  monitor + existing `PasteExecutor` path).

### Files Changed

- `Sources/ClipboardX/HotkeyManager.swift`, `AppDelegate.swift`, `SettingsStore.swift`,
  `SettingsView.swift`
- `README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/DEVLOG.md`

### Current Status

- `swift build` succeeds.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- Users who relied on ^⌘V to strip formatting from the live clipboard without opening
  the panel lose that shortcut; use the panel or copy plain text from source instead.

## 2026-06-14 (settings: confirm before clear history)

### Done

- Added SwiftUI `confirmationDialog` for **Clear history (keep favorites)** and
  **Clear all** so the user must confirm before `AppState.clearHistory` runs.

### Files Changed

- `Sources/ClipboardX/SettingsView.swift`, `docs/ROADMAP.md`, `docs/DEVLOG.md`

### Current Status

- `swift build` succeeds.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- None.

## 2026-06-14 (agent workflow: relaunch script)

### Done

- Documented default post-feature verification: quit `ClipboardX`, `./build_app.sh
  release`, `open build/ClipboardX.app` (see `AGENTS.md` **Relaunch after new work**).
- Added `./scripts/relaunch_app.sh` and mentioned it in `README.md` Quick start.

### Files Changed

- `AGENTS.md`, `README.md`, `scripts/relaunch_app.sh`, `docs/ROADMAP.md`,
  `docs/DEVLOG.md`

### Current Status

- Ran `./scripts/relaunch_app.sh` successfully in this environment.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- `killall ClipboardX` stops every process with that name; avoid running two different
  builds under the same binary name simultaneously.

## 2026-06-14 (fix: open Accessibility settings from Permissions)

### Done

- **Request / Open System Settings** now also calls `NSWorkspace` to open Privacy &
  Security → Accessibility. `AXIsProcessTrustedWithOptions(prompt:)` does not open
  Settings and often does nothing when access is already granted, which made the
  button feel broken.
- macOS 15+ uses `com.apple.settings.PrivacySecurity?Privacy_Accessibility` with a
  delayed second `open` for flaky sub-pane navigation; macOS 14 uses the legacy
  `com.apple.preference.security` URL.
- When paste runs without AX trust, we now open the same settings pane after prompting.

### Files Changed

- `Sources/ClipboardX/PasteExecutor.swift`, `Sources/ClipboardX/SettingsView.swift`,
  `docs/ROADMAP.md`, `docs/DEVLOG.md`

### Current Status

- `swift build` succeeds.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- Apple may change preference URL schemes on future macOS; keep an eye on Settings
  deep links if reports return.

## 2026-06-14 (menu bar: collections order + add hint)

### Done

- Reordered status menu: **Collections** (board submenus) now appears **before**
  **Recent**, so the ⌘1…9 quick-paste block stays the last content section above
  Settings. Added a disabled tip row: add items via panel **right-click → Add to
  Collection**.
- README: note that collections are created in Settings → Groups and items are added
  from the panel context menu.

### Files Changed

- `Sources/ClipboardX/MenuBarController.swift`, `README.md`, `docs/ARCHITECTURE.md`,
  `docs/ROADMAP.md`, `docs/DEVLOG.md`

### Current Status

- `swift build` succeeds.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- None.

## 2026-06-14 (menu bar alignment + collection hint in panel)

### Done

- Removed the status-menu tip row; **add-to-collection** guidance now appears in the
  main panel when a **collection** sidebar section is selected (hint bar when the
  list has items; extra caption in the empty state).
- Menu: **section headers** use a 16pt leading spacer image so labels line up with
  rows that show icons; **rows without icons** use the same spacer; board submenu
  parents use `indentationLevel = 0`.

### Files Changed

- `Sources/ClipboardX/MenuBarController.swift`, `Sources/ClipboardX/ClipboardPanelView.swift`,
  `README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/DEVLOG.md`

### Current Status

- `swift build` succeeds.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- NSMenu layout varies slightly by macOS theme; spacer uses a near-transparent fill
  so AppKit still reserves the 16pt column.

## 2026-06-14 (menu bar footer: Settings / Quit flush with Open)

### Done

- **Settings** uses a small **`NSMenuItem` + custom `NSView`** (`SettingsMenuRowView`):
  borderless `NSButton` draws **Settings…** with **⌘,** on the right via an attributed
  string tab stop — **no `keyEquivalent` on the menu item**, so macOS does not add the
  automatic gear or widen the leading image column. Activation calls the same
  handler as before (opens the settings window). **Keyboard ⌘, while the status menu
  is open** may no longer trigger Settings (click still works); avoiding a global
  Carbon `⌘,` hotkey keeps other apps’ **⌘,** behavior intact.
- **Quit** and **Open** keep explicit `image = nil` and `indentationLevel = 0`.

### Files Changed

- `Sources/ClipboardX/MenuBarController.swift`, `README.md`, `docs/ARCHITECTURE.md`,
  `docs/ROADMAP.md`, `docs/DEVLOG.md`

### Current Status

- `swift build` succeeds.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- If we later need **global ⌘,** for Settings, it must be optional and off by default
  so it does not steal the shortcut from other applications.

## 2026-06-14 (menu bar: remove section spacer, Settings text inset)

### Done

- Removed the **16×16 transparent leading spacer** from section headers, history rows
  without icons, and empty placeholders; deleted `menuSectionLeadingSpacer`. Middle
  sections (**Collections** / **Recent**) now share the same **left text margin** as
  **Open Clipboard Panel** and **Quit** (rows that show an app/thumbnail/folder icon
  still shift right by the icon column, which matches system menus).
- **`SettingsMenuRowView`**: **~13pt** leading/trailing inset on the borderless button
  and matching **tab stop** position so **Settings…** lines up with standard menu titles.

### Files Changed

- `Sources/ClipboardX/MenuBarController.swift`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`,
  `docs/DEVLOG.md`

### Current Status

- `swift build` succeeds.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- Exact title inset can differ by macOS version or menu font metrics; tweak the
  `13` constant if a future OS shifts default menu padding.

## 2026-06-14 (menu bar Settings: plain item, no shortcut)

### Done

- **Settings…** is again a standard **`NSMenuItem`** (no `keyEquivalent`, no custom
  view). Aligns with **Open** / **Quit** using the same AppKit layout; removes the
  previous `SettingsMenuRowView` workaround that existed to show **⌘,** without the
  system gear. Users can still open Settings from the **panel** or other UI; the
  status menu no longer advertises **⌘,** for Settings.

### Files Changed

- `Sources/ClipboardX/MenuBarController.swift`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`,
  `docs/DEVLOG.md`

### Current Status

- `swift build` succeeds.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- None specific; restoring **⌘,** on this row would reintroduce gear / alignment tradeoffs
  on some macOS versions unless we revisit a custom view or accept the system decoration.

## 2026-06-14 (suppress automatic NSMenuItem action images, keep explicit row icons)

### Done

- Added **`MenuItemImagePolicy`**: one-time replacement of `NSMenuItem.image`’s getter
  so rows **without** an explicit leading image return **`nil`** (hides macOS 26+
  injected symbols such as Settings gear). Rows we care about (**source app icon**,
  **image thumbnail**) call **`setExplicitMenuImage`** so the original getter runs and
  icons still show.
- **`AppDelegate.applicationDidFinishLaunching`**: call **`installIfNeeded()`** before
  building the status menu.

### Files Changed

- `Sources/ClipboardX/MenuItemImagePolicy.swift`, `Sources/ClipboardX/AppDelegate.swift`,
  `Sources/ClipboardX/MenuBarController.swift`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`,
  `docs/DECISIONS.md`, `docs/DEVLOG.md`

### Current Status

- `swift build` succeeds.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- The hook applies to **all** `NSMenuItem`s in the process; only items that pass
  through **`setExplicitMenuImage(..., image: non-nil)`** keep a visible leading image.
  If a future menu is built without that helper, its icons would be suppressed too.

## 2026-06-14 (status menu: drop Collections, boards in panel only)

### Done

- Removed the **Collections** block (board submenus) from **`MenuBarController`**’s
  status-item menu. **Pinned**, **Recent**, **Settings…**, and **Quit** unchanged.
  Users open collections from the **floating panel** sidebar.

### Files Changed

- `Sources/ClipboardX/MenuBarController.swift`, `Sources/ClipboardX/MenuItemImagePolicy.swift`,
  `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/DECISIONS.md`, `docs/DEVLOG.md`

### Current Status

- `swift build` succeeds.

### Next

- Custom hotkey recording UI; drag-to-reorder within a board.

### Risks

- None.
