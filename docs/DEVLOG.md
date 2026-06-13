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
