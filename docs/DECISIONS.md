# DECISIONS.md

Records *why* important technical decisions were made.

## 001

Decision: Local-only, no iCloud / account / sync / paid features.

Reason: The product is a personal, private tool. Keeping everything on-device
removes backend cost, privacy risk, and scope creep.

## 002

Decision: Swift Package Manager executable packaged into a `.app` (via
`build_app.sh`) instead of a checked-in Xcode project.

Reason: Buildable and reviewable from the command line with no Xcode project file
churn; the script still produces a proper signed bundle so permissions and Launch
at Login behave correctly.

## 003

Decision: Use the system `sqlite3` through a small in-repo wrapper instead of GRDB
or SwiftData.

Reason: Zero third-party runtime dependencies, offline builds, and full control
over schema/queries/cleanup. SwiftData/iCloud features are explicitly not needed.

## 004

Decision: Detect clipboard changes by polling `NSPasteboard.changeCount` (~0.4s).

Reason: macOS provides no public push notification for pasteboard changes; polling
the change counter is the standard, low-cost approach.

## 005

Decision: Store images and files on disk; keep only paths in the database.

Reason: Keeps the database small and fast, satisfies the "DB stores paths only"
requirement, and makes cleanup a simple file delete.

## 006

Decision: Quick-paste uses `Cmd+1…9` inside the panel rather than bare digit keys.

Reason: Bare digits would conflict with typing in the search field. Cmd+digit is
unambiguous and standard; can be revisited when custom hotkeys land.

## 007

Decision: Global hotkeys via Carbon `RegisterEventHotKey`.

Reason: It is the reliable, long-standing API for system-wide hotkeys that work
regardless of which app is focused, without requiring an event tap.

## 008

**Status: superseded by 012 (2026-06-14).** We previously skipped recording for
concealed/transient pasteboard types and a password-manager bundle-id blocklist.

## 009

Decision: Run database access on the main thread for the MVP.

Reason: Text operations are sub-millisecond and this avoids concurrency bugs.
Moving writes off-main is tracked in the roadmap as a later performance task.

## 010

Decision: For text/url items, compute the dedup hash from the whitespace-trimmed
text, while still storing the raw text for pasting.

Reason: Terminal "copy-on-select" (e.g. iTerm2) frequently produces copies that
differ only by a trailing newline or space. Hashing the raw text left these as
separate rows, yet the trimmed preview made them look identical — appearing as a
"duplicate" bug. Hashing the trimmed text collapses these visual duplicates into
one entry; keeping the raw text preserves byte-exact paste fidelity.

## 011

Decision: Support formatted paste by capturing the source RTF on copy and storing
it as a file (`rtf/<hash>.rtf`, path in `items.rtf_path`), rather than storing
attributed strings in the DB or doing full rich-text editing.

Reason: Users want Return = paste with formatting, Shift+Return = plain. Keeping
the RTF as a file matches the existing "DB stores paths, binaries on disk" pattern
and avoids adding BLOB support to the SQLite wrapper. We only pass formatting
through (no rich-text editor); editing a text item drops its RTF.

## 012

Decision: Record all clipboard changes regardless of source app or pasteboard
concealed/transient markers (no exclusion list, no concealed-type skip).

Reason: Product direction — the user chose not to maintain privacy filtering in
the capture path.

## 013

Decision: On macOS versions that inject automatic SF Symbol / “action” images into
`NSMenuItem` (e.g. a gear beside **Settings…**), install a one-time `image` getter
hook that returns `nil` unless the item is marked as carrying an **explicit**
leading image (Collections folder, source-app icon, image thumbnail).

Reason: `image = nil` does not suppress system-injected decoration; there is no
`preferredImageVisibility` in the project’s current SDK. The hook matches the
NetNewsWire-style opt-out while keeping intentional row icons visible.
