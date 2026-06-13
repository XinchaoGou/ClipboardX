import Foundation

/// Persists clipboard items and groups in SQLite and owns the on-disk schema.
///
/// All public methods are intended to be called from the main thread for the MVP;
/// text operations are sub-millisecond and image writes are handled by the parser
/// before reaching the store.
final class ClipboardStore {
    private let db: SQLiteDatabase

    init() throws {
        Storage.ensureDirectories()
        db = try SQLiteDatabase(path: Storage.databaseURL.path)
        try createSchema()
    }

    private func createSchema() throws {
        try db.execute("""
        CREATE TABLE IF NOT EXISTS items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            content_text TEXT,
            content_hash TEXT NOT NULL,
            file_paths_json TEXT,
            image_path TEXT,
            thumbnail_path TEXT,
            rtf_path TEXT,
            source_app_name TEXT,
            source_app_bundle_id TEXT,
            source_app_icon_path TEXT,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            last_used_at REAL,
            use_count INTEGER NOT NULL DEFAULT 0,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            deleted_at REAL
        );
        """)
        try db.execute("CREATE INDEX IF NOT EXISTS idx_items_created ON items(created_at DESC);")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_items_hash ON items(content_hash);")

        try db.execute("""
        CREATE TABLE IF NOT EXISTS groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at REAL NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        );
        """)

        try db.execute("""
        CREATE TABLE IF NOT EXISTS item_groups (
            item_id INTEGER NOT NULL,
            group_id INTEGER NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (item_id, group_id),
            FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
            FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
        );
        """)

        // Migrations for pre-existing DBs. ALTER throws if the column already
        // exists, which is fine to ignore.
        try? db.execute("ALTER TABLE item_groups ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;")
        try? db.execute("ALTER TABLE items ADD COLUMN rtf_path TEXT;")
    }

    // MARK: - Row mapping

    private func mapItem(_ r: Row) -> ClipboardItem {
        let filePaths: [String]
        if let json = r.string(4), let data = json.data(using: .utf8),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            filePaths = arr
        } else {
            filePaths = []
        }
        return ClipboardItem(
            id: r.int(0),
            type: ItemType(rawValue: r.string(1) ?? "text") ?? .text,
            contentText: r.string(2),
            contentHash: r.string(3) ?? "",
            filePaths: filePaths,
            imagePath: r.string(5),
            thumbnailPath: r.string(6),
            rtfPath: r.string(15),
            sourceAppName: r.string(7),
            sourceAppBundleID: r.string(8),
            sourceAppIconPath: r.string(9),
            createdAt: r.date(10),
            updatedAt: r.date(11),
            lastUsedAt: r.optionalDate(12),
            useCount: Int(r.int(13)),
            isPinned: r.bool(14)
        )
    }

    // NOTE: rtf_path is appended last so existing column indices (0…14) are stable.
    private let itemColumns = """
    id, type, content_text, content_hash, file_paths_json, image_path, thumbnail_path,
    source_app_name, source_app_bundle_id, source_app_icon_path,
    created_at, updated_at, last_used_at, use_count, is_pinned, rtf_path
    """

    // MARK: - Inserts

    /// Insert a new item. If an identical (hash) non-deleted item already exists,
    /// the existing row is "touched" (moved to top) instead of duplicating.
    @discardableResult
    func insert(_ item: ClipboardItem) throws -> Int64 {
        if let existing = try findByHash(item.contentHash) {
            try touch(id: existing.id)
            return existing.id
        }
        let now = Date().timeIntervalSince1970
        let filePathsJSON = (try? JSONEncoder().encode(item.filePaths))
            .flatMap { String(data: $0, encoding: .utf8) }
        return try db.run("""
            INSERT INTO items
            (type, content_text, content_hash, file_paths_json, image_path, thumbnail_path, rtf_path,
             source_app_name, source_app_bundle_id, source_app_icon_path,
             created_at, updated_at, last_used_at, use_count, is_pinned, deleted_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,0,0,NULL)
            """, [
                item.type.rawValue.sql,
                item.contentText.sql,
                item.contentHash.sql,
                filePathsJSON.sql,
                item.imagePath.sql,
                item.thumbnailPath.sql,
                item.rtfPath.sql,
                item.sourceAppName.sql,
                item.sourceAppBundleID.sql,
                item.sourceAppIconPath.sql,
                now.sql, now.sql, SQLiteValue.null
            ])
    }

    private func findByHash(_ hash: String) throws -> ClipboardItem? {
        try db.query(
            "SELECT \(itemColumns) FROM items WHERE content_hash = ? AND deleted_at IS NULL LIMIT 1",
            [hash.sql], map: mapItem
        ).first
    }

    /// Move an item to the top of history and bump its usage counters.
    func touch(id: Int64) throws {
        let now = Date().timeIntervalSince1970
        try db.run("UPDATE items SET updated_at = ?, last_used_at = ?, use_count = use_count + 1 WHERE id = ?",
                   [now.sql, now.sql, id.sql])
    }

    // MARK: - Queries

    /// Recent history items, newest first. Pinned items are excluded — they live
    /// only in the Pinned view (collections members still appear here).
    func recentItems(limit: Int = 200) throws -> [ClipboardItem] {
        try db.query("""
            SELECT \(itemColumns) FROM items
            WHERE deleted_at IS NULL AND is_pinned = 0
            ORDER BY updated_at DESC
            LIMIT ?
            """, [limit.sql], map: mapItem)
    }

    func pinnedItems() throws -> [ClipboardItem] {
        try db.query("""
            SELECT \(itemColumns) FROM items
            WHERE deleted_at IS NULL AND is_pinned = 1
            ORDER BY updated_at DESC
            """, map: mapItem)
    }

    /// Full-text-ish search across content, file names, source app and group names.
    func search(_ query: String, limit: Int = 200) throws -> [ClipboardItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return try recentItems(limit: limit) }
        let like = "%\(q)%"
        return try db.query("""
            SELECT DISTINCT \(itemColumns.split(separator: ",").map { "i.\($0.trimmingCharacters(in: .whitespaces))" }.joined(separator: ", "))
            FROM items i
            LEFT JOIN item_groups ig ON ig.item_id = i.id
            LEFT JOIN groups g ON g.id = ig.group_id
            WHERE i.deleted_at IS NULL AND i.is_pinned = 0 AND (
                i.content_text LIKE ? OR
                i.file_paths_json LIKE ? OR
                i.source_app_name LIKE ? OR
                g.name LIKE ?
            )
            ORDER BY i.updated_at DESC
            LIMIT ?
            """, [like.sql, like.sql, like.sql, like.sql, limit.sql], map: mapItem)
    }

    func item(id: Int64) throws -> ClipboardItem? {
        try db.query("SELECT \(itemColumns) FROM items WHERE id = ? AND deleted_at IS NULL",
                     [id.sql], map: mapItem).first
    }

    func count() throws -> Int {
        try db.query("SELECT COUNT(*) FROM items WHERE deleted_at IS NULL", map: { Int($0.int(0)) }).first ?? 0
    }

    // MARK: - Mutations

    func setPinned(id: Int64, pinned: Bool) throws {
        try db.run("UPDATE items SET is_pinned = ?, updated_at = ? WHERE id = ?",
                   [pinned.sql, Date().timeIntervalSince1970.sql, id.sql])
    }

    func updateText(id: Int64, text: String) throws {
        let now = Date().timeIntervalSince1970
        let hash = Hashing.sha256(text.trimmingCharacters(in: .whitespacesAndNewlines))
        // Editing drops the original formatting; remove the stored RTF.
        if let old = try item(id: id), let rtf = old.rtfPath {
            try? FileManager.default.removeItem(atPath: rtf)
        }
        try db.run("UPDATE items SET content_text = ?, content_hash = ?, rtf_path = NULL, updated_at = ? WHERE id = ?",
                   [text.sql, hash.sql, now.sql, id.sql])
    }

    /// Hard-delete an item and clean up its on-disk image/thumb files.
    func delete(id: Int64) throws {
        if let it = try item(id: id) {
            removeFiles(for: it)
        }
        try db.run("DELETE FROM items WHERE id = ?", [id.sql])
    }

    /// An item is a "favorite" (protected from auto-cleanup and from
    /// "clear history") when it is pinned or belongs to at least one board.
    private static let notFavoriteClause =
        "is_pinned = 0 AND id NOT IN (SELECT item_id FROM item_groups)"

    /// Clear history. When `keepFavorites` is true, pinned items and items that
    /// belong to any board are preserved.
    func clearAll(keepFavorites: Bool) throws {
        let whereClause = keepFavorites ? " AND \(Self.notFavoriteClause)" : ""
        let items = try db.query(
            "SELECT \(itemColumns) FROM items WHERE deleted_at IS NULL" + whereClause,
            map: mapItem
        )
        for it in items { removeFiles(for: it) }
        if keepFavorites {
            try db.run("DELETE FROM items WHERE \(Self.notFavoriteClause)")
        } else {
            try db.run("DELETE FROM items")
        }
    }

    /// Remove oldest non-favorite items beyond `maxCount`, cleaning files too.
    /// Pinned items and board members are never auto-deleted.
    func enforceLimit(maxCount: Int) throws {
        let total = try db.query(
            "SELECT COUNT(*) FROM items WHERE deleted_at IS NULL AND \(Self.notFavoriteClause)",
            map: { Int($0.int(0)) }).first ?? 0
        guard total > maxCount else { return }
        let overflow = total - maxCount
        let victims = try db.query("""
            SELECT \(itemColumns) FROM items
            WHERE deleted_at IS NULL AND \(Self.notFavoriteClause)
            ORDER BY updated_at ASC
            LIMIT ?
            """, [overflow.sql], map: mapItem)
        for it in victims {
            removeFiles(for: it)
            try db.run("DELETE FROM items WHERE id = ?", [it.id.sql])
        }
    }

    private func removeFiles(for item: ClipboardItem) {
        let fm = FileManager.default
        for p in [item.imagePath, item.thumbnailPath, item.rtfPath].compactMap({ $0 }) {
            try? fm.removeItem(atPath: p)
        }
    }

    // MARK: - Groups

    func groups() throws -> [Group] {
        try db.query("SELECT id, name, created_at, sort_order FROM groups ORDER BY sort_order, name",
                     map: { Group(id: $0.int(0), name: $0.string(1) ?? "", createdAt: $0.date(2), sortOrder: Int($0.int(3))) })
    }

    @discardableResult
    func createGroup(name: String) throws -> Int64 {
        try db.run("INSERT INTO groups (name, created_at, sort_order) VALUES (?,?,?)",
                   [name.sql, Date().timeIntervalSince1970.sql, 0.sql])
    }

    func deleteGroup(id: Int64) throws {
        try db.run("DELETE FROM groups WHERE id = ?", [id.sql])
    }

    func addItem(_ itemID: Int64, toGroup groupID: Int64) throws {
        // Append to the end of the board's manual order.
        let next = try db.query("SELECT COALESCE(MAX(sort_order), -1) + 1 FROM item_groups WHERE group_id = ?",
                                [groupID.sql], map: { Int($0.int(0)) }).first ?? 0
        try db.run("INSERT OR IGNORE INTO item_groups (item_id, group_id, sort_order) VALUES (?,?,?)",
                   [itemID.sql, groupID.sql, next.sql])
    }

    func removeItem(_ itemID: Int64, fromGroup groupID: Int64) throws {
        try db.run("DELETE FROM item_groups WHERE item_id = ? AND group_id = ?",
                   [itemID.sql, groupID.sql])
    }

    func itemsInGroup(_ groupID: Int64) throws -> [ClipboardItem] {
        try db.query("""
            SELECT \(itemColumns.split(separator: ",").map { "i.\($0.trimmingCharacters(in: .whitespaces))" }.joined(separator: ", "))
            FROM items i
            JOIN item_groups ig ON ig.item_id = i.id
            WHERE ig.group_id = ? AND i.deleted_at IS NULL
            ORDER BY ig.sort_order ASC, i.updated_at DESC
            """, [groupID.sql], map: mapItem)
    }

    /// Persist a manual ordering for a board (sort_order = position in the array).
    func setGroupOrder(groupID: Int64, orderedItemIDs: [Int64]) throws {
        for (index, id) in orderedItemIDs.enumerated() {
            try db.run("UPDATE item_groups SET sort_order = ? WHERE group_id = ? AND item_id = ?",
                       [index.sql, groupID.sql, id.sql])
        }
    }

    func groupIDs(forItem itemID: Int64) throws -> [Int64] {
        try db.query("SELECT group_id FROM item_groups WHERE item_id = ?", [itemID.sql], map: { $0.int(0) })
    }
}
