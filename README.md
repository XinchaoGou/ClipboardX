# ClipboardX

A local-only macOS clipboard manager (think iPaste, but personal and offline).
No iCloud, no multi-device sync, no accounts, no subscriptions. All data stays on
your Mac in `~/Library/Application Support/ClipboardX/`.

## Features

- **Menu bar only** — no Dock icon (`LSUIElement`), lives in the status bar.
- **Automatic history** — polls `NSPasteboard.general` and records text, URLs,
  images and Finder file paths. Identical consecutive content is de-duplicated.
- **Global hotkeys**
  - `Shift + Cmd + V` — toggle the search panel
  - `Ctrl + Cmd + V` — paste current clipboard as plain text
  - `Cmd + 1…9` (inside the panel) — quick-paste the Nth item
- **Spotlight-style panel** — live search, keyboard navigation (↑/↓), `Enter` to
  paste, `Esc` to close.
- **One-click paste** — writes the item back to the pasteboard and simulates
  `Cmd + V`; optionally restores your previous clipboard afterwards.
- **Pin** frequently used items (exempt from auto-cleanup).
- **Groups** — organize items (代码片段, 常用回复, …); an item can join multiple groups.
- **Edit** text items in place.
- **Excluded apps** — never records from password managers (1Password, Bitwarden,
  Keychain Access, Apple Passwords) by default; add/remove in Settings. Also
  honors the `org.nspasteboard.ConcealedType` transient marker.
- **Auto cleanup** — keeps the newest N items (default 1000); deleting an item
  also removes its on-disk image/thumbnail files.

## Requirements

- macOS 14 or newer
- Swift 5.9+ toolchain (Xcode or Command Line Tools)

## Build & Run

Package it as a proper `.app` bundle (recommended — needed for Accessibility
permission and Launch at Login to work reliably):

```bash
./build_app.sh release
open "build/ClipboardX.app"
```

Or run the raw executable for development:

```bash
swift build
swift run
```

### First launch

1. The app appears in the **menu bar** (clipboard icon).
2. Grant **Accessibility** permission when prompted (System Settings → Privacy &
   Security → Accessibility). This is required to simulate `Cmd + V` on paste.
   You can re-check status under Settings → Permissions.

## Data layout

```
~/Library/Application Support/ClipboardX/
├── clipboard.db        # SQLite (text, metadata, paths — never image blobs)
├── images/             # full-size copied images (PNG)
├── thumbs/             # list thumbnails
└── icons/              # cached source-app icons
```

## Architecture

| Module | Responsibility |
| --- | --- |
| `PasteboardMonitor` | Polls `changeCount`, filters excluded apps, stores items |
| `ClipboardItemParser` | Classifies text/url/image/file, writes image + thumb |
| `ClipboardStore` | SQLite schema, CRUD, search, pin, groups, cleanup |
| `SQLite` | Thin throwing wrapper over the SQLite3 C API |
| `MenuBarController` | `NSStatusItem` dropdown (recent / pinned / settings / quit) |
| `PanelController` + `ClipboardPanelView` | Floating Spotlight-style search panel |
| `HotkeyManager` | Global hotkeys via the Carbon Hot Key API |
| `PasteExecutor` | Writes item back + simulates `Cmd + V` + restore previous |
| `AppFilter` | Frontmost app detection + exclusion + icon caching |
| `SettingsStore` / `SettingsView` | Preferences (max count, excludes, etc.) |
| `AppState` | Shared coordinator / view model |

## Notes & deviations from spec

- **Quick-paste digits** use `Cmd + 1…9` *inside the panel* rather than bare
  global digit keys, so you can still type numbers in the search box. Easy to
  change later when custom hotkeys land.
- **Launch at Login** uses `SMAppService.mainApp`; it works best when launched
  from the signed `.app` bundle produced by `build_app.sh`.
- DB access runs on the main thread for the MVP (text ops are sub-millisecond).

## Roadmap

- v0.3: custom hotkeys, richer source-app metadata
- v0.4: performance tuning, import/export, fuller settings & error/permission UX

## License

Personal / local use.
