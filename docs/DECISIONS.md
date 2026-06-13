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

Decision: Skip recording when the pasteboard carries `org.nspasteboard.ConcealedType`
(and friends), in addition to a bundle-id blocklist.

Reason: Password managers mark secret copies as concealed/transient; honoring this
convention prevents capturing secrets even from apps not on the blocklist.

## 009

Decision: Run database access on the main thread for the MVP.

Reason: Text operations are sub-millisecond and this avoids concurrency bugs.
Moving writes off-main is tracked in the roadmap as a later performance task.
