# ROADMAP.md

Project progress. Agents update this after every task.

## Backlog

- Custom hotkey recording UI (let users rebind `Shift+Cmd+V`, quick-paste, and
  other shortcuts as needed).
- Drag-to-reorder within a board (currently move up/down buttons).
- Verify / harden Launch at Login from the signed `.app` bundle.
- Import / export history.
- Performance pass: move DB writes off the main thread; lazy thumbnail loading.
- XCTest target for `ClipboardStore` / `ClipboardItemParser`.
- Fuller settings UX and permission onboarding flow.
- App icon + status-bar icon polish.

Explicit non-goals (will not do): iCloud sync, multi-device sync, accounts,
subscriptions, full rich-text, OCR, AI summarize/rewrite, browser extension, teams.

## In Progress

- (none)

## Done (recent additions continued)

- Formatted paste: capture RTF on copy (`rtf/`, `items.rtf_path`); Return pastes
  with formatting, Shift+Return pastes plain text; editing clears RTF.
- Removed excluded-apps settings, default password-manager bundle blocklist, and
  concealed/transient pasteboard skipping; all supported clipboard changes are recorded.
- Removed global `Ctrl+Cmd+V` “paste clipboard as plain text” hotkey and the
  `enablePlainTextPaste` setting; plain vs formatted paste is only via the panel
  (Return / Shift+Return).

## Done

- v0.1 core loop: pasteboard monitoring → SQLite storage → menu bar → hotkey panel
  → search → select-to-paste → delete.
- v0.2: pin, groups, edit text items; panel Shift+Return for plain paste of a row.
- v0.3 (partial): image support, file-path support, source-app icon capture.
- SwiftPM project + `.app` packaging script (`build_app.sh`) with ad-hoc signing.
- Dedup by content hash; max-count auto-cleanup that also deletes on-disk files.
- Project documentation system (README, AGENTS, docs/*).
- Bugfix: dedup text/url on trimmed content so whitespace-only variants
  (e.g. iTerm2 copy-on-select) no longer create visually identical duplicate rows.
- Bugfix: reliable panel hover/selection (tracked by item id) + full-row hit testing.
- Boards/favorites Phase 1 (iPaste-style): unified `items` table where pinned or
  board-member items are exempt from auto-cleanup; panel left sidebar to switch
  between History / Pinned / each board; "clear history" keeps favorites. Board
  create/delete lives in Settings.
- Boards/favorites Phase 2: per-board manual ordering (`item_groups.sort_order`,
  move up/down buttons + context menu); Collections submenu in the menu bar.
  Section switching inside the panel via `Shift+Cmd+↑/↓` (History / Pinned /
  collections). (Earlier global `Ctrl+Cmd+0/1…9` board hotkeys were removed by
  request in favor of in-panel switching.)
