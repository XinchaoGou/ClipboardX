# ClipboardX

A local-only macOS clipboard manager (think iPaste, but personal and offline).
No iCloud, no multi-device sync, no accounts, no subscriptions. All data stays on
your Mac in `~/Library/Application Support/ClipboardX/`.

## Docs

| File | Purpose |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Working protocol & required reading for coding agents |
| [docs/PRODUCT.md](docs/PRODUCT.md) | Why it exists, MVP, non-goals |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Current architecture & data flow |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Backlog / In Progress / Done |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Why key technical decisions were made |
| [docs/DEVLOG.md](docs/DEVLOG.md) | Append-only development log |

## Features

- **Menu bar only** — no Dock icon (`LSUIElement`), lives in the status bar.
- **Automatic history** — records text, URLs, images and Finder file paths;
  identical consecutive content is de-duplicated.
- **Global hotkeys**
  - `Shift + Cmd + V` — toggle the search panel
  - `Cmd + 1…9` (inside the panel) — quick-paste the Nth item
- **Spotlight-style panel** — live search, ↑/↓ navigation, `Enter` to paste
  (with formatting when available), `Shift+Return` for plain-text paste of the
  selected row, `Esc` to close.
- **One-click paste** — writes the item back and simulates `Cmd + V`; optionally
  restores your previous clipboard afterwards.
- **Pin** frequently used items, organize into **groups**, **edit** text items.
- **Auto cleanup** — keeps the newest N items (default 1000); deleting an item also
  removes its on-disk image/thumbnail files.

## Quick start

Requires macOS 14+ and a Swift 5.9+ toolchain.

```bash
./build_app.sh release       # build + package a signed ClipboardX.app
open "build/ClipboardX.app"  # launch (appears in the menu bar)
./scripts/relaunch_app.sh    # quit old instance, rebuild, open (handy after changes)
```

On first launch, grant **Accessibility** permission when prompted (System Settings
→ Privacy & Security → Accessibility) so the app can simulate `Cmd + V` on paste.

For development you can also run the raw executable:

```bash
swift build
swift run
```

## Project structure

```
ClipboardX/
├── Package.swift            # SwiftPM executable manifest
├── build_app.sh             # builds + packages the .app (ad-hoc signed)
├── Resources/Info.plist     # bundle metadata (LSUIElement, bundle id)
├── Sources/ClipboardX/      # all Swift source
└── docs/                    # product / architecture / roadmap / decisions / devlog
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the module map and data flow.

## Development

- Swift, 4-space indent, one primary type per file, comments in English.
- Storage uses the system `sqlite3` via a thin in-repo wrapper — no third-party
  runtime dependencies. Images/files live on disk; the DB stores paths only.
- Read [AGENTS.md](AGENTS.md) before contributing, and update
  [docs/ROADMAP.md](docs/ROADMAP.md) + [docs/DEVLOG.md](docs/DEVLOG.md) after each task.
