import Foundation
import AppKit

/// Content type of a clipboard item.
enum ItemType: String, Codable, CaseIterable {
    case text
    case url
    case image
    case file
}

/// A single clipboard history record. Mirrors the `items` table.
struct ClipboardItem: Identifiable, Hashable {
    var id: Int64
    var type: ItemType
    var contentText: String?
    var contentHash: String
    var filePaths: [String]
    var imagePath: String?
    var thumbnailPath: String?
    /// Path to a stored RTF representation for rich (formatted) paste, if captured.
    var rtfPath: String?
    var sourceAppName: String?
    var sourceAppBundleID: String?
    var sourceAppIconPath: String?
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?
    var useCount: Int
    var isPinned: Bool
    /// Optional user-defined label for quick identification in lists and search.
    var title: String?

    /// Non-empty trimmed title, if the user set one.
    var trimmedTitle: String? {
        guard let t = title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    /// Primary line for list/menu display: title when set, otherwise preview.
    var listPrimaryLine: String {
        if let t = trimmedTitle { return t }
        let p = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        return p.isEmpty ? "(empty)" : p
    }

    /// A short, single-line preview used in lists.
    var preview: String {
        switch type {
        case .text:
            return (contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        case .url:
            return contentText ?? ""
        case .image:
            return "Image"
        case .file:
            return filePaths.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
        }
    }

    /// For URL items, the host portion (e.g. "github.com").
    var urlHost: String? {
        guard type == .url, let s = contentText, let u = URL(string: s) else { return nil }
        return u.host
    }

    var thumbnailImage: NSImage? {
        guard let p = thumbnailPath ?? imagePath else { return nil }
        return NSImage(contentsOfFile: p)
    }

    var sourceAppIcon: NSImage? {
        guard let p = sourceAppIconPath else { return nil }
        return NSImage(contentsOfFile: p)
    }
}

/// A user-defined group. Mirrors the `groups` table.
struct Group: Identifiable, Hashable {
    var id: Int64
    var name: String
    var createdAt: Date
    var sortOrder: Int
}
