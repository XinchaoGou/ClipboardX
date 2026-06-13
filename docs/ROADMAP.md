# ROADMAP.md

Project progress. Agents update this after every task.

## Backlog

- Custom hotkey recording UI (let users rebind `Shift+Cmd+V`, `Ctrl+Cmd+V`, quick-paste).
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

## Done

- v0.1 core loop: pasteboard monitoring → SQLite storage → menu bar → hotkey panel
  → search → select-to-paste → delete.
- v0.2: pin, groups, edit text items, paste-as-plain-text, sensitive-app exclusion
  (+ concealed-type detection).
- v0.3 (partial): image support, file-path support, source-app icon capture.
- SwiftPM project + `.app` packaging script (`build_app.sh`) with ad-hoc signing.
- Dedup by content hash; max-count auto-cleanup that also deletes on-disk files.
- Project documentation system (README, AGENTS, docs/*).
