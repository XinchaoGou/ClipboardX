# PRODUCT.md

## Why this project exists

macOS only keeps the most recent clipboard entry. Anything copied earlier is lost.
ClipboardX gives the user a persistent, searchable, local clipboard history and a
fast way to paste any past item back into the current app.

## Problem it solves

- "I copied something a minute ago and overwrote it."
- "I keep re-typing the same snippets / replies / addresses / commands."
- "I want clipboard history but I don't want my data leaving this Mac."

## Target user

A single individual using one Mac who wants a fast, private, offline clipboard
manager. Not teams, not multi-device users.

## MVP

- Continuously record clipboard history: text, URL, image, Finder file paths.
- Menu-bar app with no Dock icon.
- Global hotkey to summon a Spotlight-style search panel.
- Search history; press Enter to paste the selected item into the front app.
- Quick-paste the Nth item, pin frequently used items, organize into groups.
- Edit text items.
- Keep the newest N items (default 1000); auto-clean older non-pinned items.
- All data stored locally under `~/Library/Application Support/ClipboardX/`.

## Non-goals (explicitly out of scope)

- No iCloud sync.
- No multi-device sync.
- No account / login.
- No subscription / paid features.
- No rich-text *editing*. (Formatting is preserved for pass-through paste: the
  RTF representation is captured on copy so Return pastes with formatting and
  Shift+Return pastes plain text. Editing a text item drops its formatting.)
- No OCR.
- No AI summarization / rewriting.
- No browser extension.
- No team collaboration.

## Success criteria

- Copied text appears in history within ~1 second.
- `Shift+Cmd+V` reliably summons the panel.
- Enter pastes the selected item; quick-paste works for the first 9 items.
- Search responds in well under 100ms.
- 1000 items remain responsive.
- History survives app restart.
- No Dock icon; menu-bar only.
- Resident memory comfortably under 100MB.
- Image/file binaries live on disk, not in the database; deleting an item removes
  its on-disk files.
