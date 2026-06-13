import Foundation
import AppKit

/// Determines the frontmost application and whether recording should be skipped.
enum AppFilter {
    struct FrontApp {
        var name: String?
        var bundleID: String?
        var app: NSRunningApplication?
    }

    static func frontmostApp() -> FrontApp {
        let app = NSWorkspace.shared.frontmostApplication
        return FrontApp(name: app?.localizedName, bundleID: app?.bundleIdentifier, app: app)
    }

    static func shouldSkip(bundleID: String?, excluded: [String]) -> Bool {
        guard let bundleID = bundleID else { return false }
        return excluded.contains(bundleID)
    }

    /// Cache a source app icon to disk so list views don't need the running app.
    static func cacheIcon(for app: NSRunningApplication?) -> String? {
        guard let app = app, let bundleID = app.bundleIdentifier else { return nil }
        let dest = Storage.iconsDir.appendingPathComponent("\(bundleID).png")
        if FileManager.default.fileExists(atPath: dest.path) { return dest.path }
        guard let icon = app.icon else { return nil }
        let target = NSSize(width: 32, height: 32)
        let resized = NSImage(size: target)
        resized.lockFocus()
        icon.draw(in: NSRect(origin: .zero, size: target),
                  from: NSRect(origin: .zero, size: icon.size),
                  operation: .copy, fraction: 1.0)
        resized.unlockFocus()
        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        try? png.write(to: dest)
        return dest.path
    }
}
