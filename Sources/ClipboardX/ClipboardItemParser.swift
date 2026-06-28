import Foundation
import AppKit

/// Converts the current `NSPasteboard` contents into a `ClipboardItem`,
/// persisting images and thumbnails to disk when needed.
enum ClipboardItemParser {

    static func parse(_ pasteboard: NSPasteboard, source: AppFilter.FrontApp) -> ClipboardItem? {
        let iconPath = AppFilter.cacheIcon(for: source.app)

        // 1. File URLs from Finder etc.
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self],
                                                 options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !fileURLs.isEmpty {
            let paths = fileURLs.map { $0.path }
            let hash = Hashing.sha256(paths.joined(separator: "\n"))
            return base(type: .file, source: source, iconPath: iconPath, hash: hash,
                        text: nil, filePaths: paths)
        }

        // 2. Plain text / URL
        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let isURL = looksLikeURL(trimmed)
            // Dedup on the trimmed text so copies differing only by leading/trailing
            // whitespace or newlines (common with terminal copy-on-select) collapse
            // into one entry. The raw text is still stored for byte-exact pasting.
            let hash = Hashing.sha256(trimmed)
            // Capture a rich (RTF) representation for formatted paste, if present.
            let rtfPath = saveRichText(from: pasteboard, hash: hash)
            return base(type: isURL ? .url : .text, source: source, iconPath: iconPath,
                        hash: hash, text: text, filePaths: [], rtfPath: rtfPath)
        }

        // 3. Image data
        if let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            let hash = Hashing.sha256(png)
            let base = "\(hash).png"
            let imageURL = Storage.imagesDir.appendingPathComponent(base)
            let thumbURL = Storage.thumbsDir.appendingPathComponent(base)
            try? png.write(to: imageURL)
            writeThumbnail(from: image, to: thumbURL)
            return self.base(type: .image, source: source, iconPath: iconPath, hash: hash,
                             text: nil, filePaths: [], imagePath: imageURL.path,
                             thumbnailPath: thumbURL.path)
        }

        return nil
    }

    private static func base(type: ItemType, source: AppFilter.FrontApp, iconPath: String?,
                             hash: String, text: String?, filePaths: [String],
                             imagePath: String? = nil, thumbnailPath: String? = nil,
                             rtfPath: String? = nil) -> ClipboardItem {
        let now = Date()
        return ClipboardItem(
            id: 0, type: type, contentText: text, contentHash: hash,
            filePaths: filePaths, imagePath: imagePath, thumbnailPath: thumbnailPath,
            rtfPath: rtfPath,
            sourceAppName: source.name, sourceAppBundleID: source.bundleID,
            sourceAppIconPath: iconPath, createdAt: now, updatedAt: now,
            lastUsedAt: nil, useCount: 0, isPinned: false, title: nil
        )
    }

    /// Persist an RTF representation of the current text selection, if the source
    /// app provided one (directly as RTF, or convertible from HTML). Returns the
    /// file path, or nil when there is no usable formatting.
    private static func saveRichText(from pasteboard: NSPasteboard, hash: String) -> String? {
        var rtf: Data?
        if let data = pasteboard.data(forType: .rtf) {
            rtf = data
        } else if let html = pasteboard.data(forType: .html),
                  let attr = try? NSAttributedString(
                      data: html,
                      options: [.documentType: NSAttributedString.DocumentType.html],
                      documentAttributes: nil) {
            rtf = try? attr.data(from: NSRange(location: 0, length: attr.length),
                                 documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        }
        guard let rtf else { return nil }
        let url = Storage.rtfDir.appendingPathComponent("\(hash).rtf")
        do {
            try rtf.write(to: url)
            return url.path
        } catch {
            return nil
        }
    }

    private static func looksLikeURL(_ s: String) -> Bool {
        guard !s.contains(" "), !s.contains("\n") else { return false }
        guard let u = URL(string: s), let scheme = u.scheme?.lowercased() else { return false }
        return ["http", "https", "ftp", "file"].contains(scheme) && u.host != nil
    }

    private static func writeThumbnail(from image: NSImage, to url: URL, maxDimension: CGFloat = 256) {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        let scale = min(1.0, maxDimension / max(size.width, size.height))
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let thumb = NSImage(size: target)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1.0)
        thumb.unlockFocus()
        guard let tiff = thumb.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}
