# AGENTS.md

Working protocol for any coding agent (Codex / Claude Code / Cursor Agent / others)
contributing to **ClipboardX**.

## Read First

Before doing anything, read these in order to restore project context:

1. `README.md` — what the project is and how to run it
2. `docs/PRODUCT.md` — why it exists, MVP, non-goals
3. `docs/ARCHITECTURE.md` — current real architecture and data flow
4. `docs/ROADMAP.md` — what is done / in progress / backlog
5. `docs/DEVLOG.md` — chronological development history

Do not rely on chat history or past prompts. The docs above are the source of truth.

## Project Goal

A **local-only** macOS clipboard manager (menu-bar app). No iCloud sync, no
multi-device sync, no accounts, no subscriptions. All data stays on the user's Mac.

## Constraints

- macOS 14+ only. Swift 5.9+ toolchain.
- **No third-party runtime dependencies.** Storage uses the system `sqlite3` via a
  thin in-repo wrapper. UI is SwiftUI + AppKit.
- Images and files are stored on disk; the database stores **paths only**, never blobs.

## Code Conventions

- Swift, 4-space indent. Types `UpperCamelCase`, members `lowerCamelCase`.
- One primary type per file; file name matches the type.
- Comments in English; explain intent/trade-offs, not the obvious.
- Keep AppKit/UI work on the main thread. `AppState` is `@MainActor`.
- New persisted fields require a matching change in `ClipboardStore` schema + mapping.

## Do Not

- Do not add iCloud / sync / accounts / paid features.
- Do not add a third-party dependency without a `docs/DECISIONS.md` entry first.
- Do not store image/file binary data in the database.
- Do not commit `build/`, `.build/`, or any generated artifacts.
- Do not force-push shared branches without explicit user request.

## Build Commands

```bash
swift build                 # debug build
swift run                   # run raw executable (dev)
./build_app.sh release      # package signed ClipboardX.app into build/
open "build/ClipboardX.app" # launch
./scripts/relaunch_app.sh   # quit running app, release-build, open bundle (smoke test)
```

## Relaunch after new work (agent + local)

Whenever a **user-visible** change lands (UI, hotkeys, capture, packaging, etc.),
the agent should **by default**:

1. Quit any running instance: `killall ClipboardX` (ignore errors).
2. Rebuild the app bundle: `./build_app.sh release` (must succeed).
3. Launch the fresh build: `open "build/ClipboardX.app"`.

Use `./scripts/relaunch_app.sh` to do all three in one step. For compile-only checks,
`swift build` is still enough; use the relaunch flow when validating the menu-bar
`.app` behavior.

## Test / Verify Commands

There is no XCTest target yet (see ROADMAP). Until then, verify via:

```bash
swift build                 # must succeed with no errors
# Functional smoke test (app must be running):
echo "hello $(date)" | pbcopy
sqlite3 ~/Library/Application\ Support/ClipboardX/clipboard.db \
  "SELECT id,type,substr(content_text,1,40) FROM items ORDER BY id DESC LIMIT 5;"
```

## Documentation Rules

After **every** development task:

- Update `docs/ROADMAP.md` (move items between Backlog / In Progress / Done).
- Append an entry to `docs/DEVLOG.md` (append only — never overwrite history).

Conditionally:

- If the architecture changed → update `docs/ARCHITECTURE.md`.
- If an important technical decision was made → add an entry to `docs/DECISIONS.md`.

`README.md` and `docs/PRODUCT.md` stay stable; only change them when the product
itself (not its progress) changes.

## Workflow

1. Read the docs listed in **Read First**.
2. Output a development plan and get confirmation.
3. Implement.
4. Build, verify, fix obvious issues — for GUI/menu-bar changes, follow **Relaunch
   after new work** (or run `./scripts/relaunch_app.sh`) unless the user opts out.
5. Update ROADMAP + DEVLOG (and ARCHITECTURE/DECISIONS if needed).
6. Report: 本次完成内容 / 当前项目状态 / 下一步推荐任务.
