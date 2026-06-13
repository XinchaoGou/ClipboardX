import Foundation

/// Resolves the on-disk locations used by the app.
enum Storage {
    static let appName = "ClipboardX"

    static var supportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(appName, isDirectory: true)
    }

    static var imagesDir: URL { supportDir.appendingPathComponent("images", isDirectory: true) }
    static var thumbsDir: URL { supportDir.appendingPathComponent("thumbs", isDirectory: true) }
    static var iconsDir: URL { supportDir.appendingPathComponent("icons", isDirectory: true) }
    static var rtfDir: URL { supportDir.appendingPathComponent("rtf", isDirectory: true) }
    static var databaseURL: URL { supportDir.appendingPathComponent("clipboard.db") }

    /// Create all required directories. Safe to call repeatedly.
    static func ensureDirectories() {
        let fm = FileManager.default
        for dir in [supportDir, imagesDir, thumbsDir, iconsDir, rtfDir] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
