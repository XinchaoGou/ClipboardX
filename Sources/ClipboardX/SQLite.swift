import Foundation
import SQLite3

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Minimal, throwing wrapper around the SQLite3 C API.
final class SQLiteDatabase {
    private var db: OpaquePointer?

    init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.open(msg)
        }
        // Improve durability/concurrency for a desktop app.
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA foreign_keys = ON;")
    }

    deinit { sqlite3_close(db) }

    var lastInsertRowID: Int64 { sqlite3_last_insert_rowid(db) }

    /// Run a statement that returns no rows.
    func execute(_ sql: String) throws {
        var err: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(err)
            throw SQLiteError.exec(msg)
        }
    }

    /// Prepare a statement for binding/stepping.
    func prepare(_ sql: String) throws -> Statement {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.prepare(msg)
        }
        return Statement(stmt: stmt!)
    }

    /// Convenience for an INSERT/UPDATE/DELETE with positional bindings.
    @discardableResult
    func run(_ sql: String, _ params: [SQLiteValue] = []) throws -> Int64 {
        let stmt = try prepare(sql)
        defer { stmt.finalize() }
        stmt.bind(params)
        try stmt.stepDone()
        return lastInsertRowID
    }

    /// Convenience for a SELECT returning rows mapped by `map`.
    func query<T>(_ sql: String, _ params: [SQLiteValue] = [], map: (Row) -> T) throws -> [T] {
        let stmt = try prepare(sql)
        defer { stmt.finalize() }
        stmt.bind(params)
        var result: [T] = []
        while try stmt.step() {
            result.append(map(Row(stmt: stmt.handle)))
        }
        return result
    }
}

enum SQLiteError: Error {
    case open(String)
    case exec(String)
    case prepare(String)
    case step(String)
}

/// Bindable value types.
enum SQLiteValue {
    case int(Int64)
    case double(Double)
    case text(String)
    case null
}

extension Int64 { var sql: SQLiteValue { .int(self) } }
extension Int { var sql: SQLiteValue { .int(Int64(self)) } }
extension Double { var sql: SQLiteValue { .double(self) } }
extension Bool { var sql: SQLiteValue { .int(self ? 1 : 0) } }
extension String { var sql: SQLiteValue { .text(self) } }
extension Optional where Wrapped == String {
    var sql: SQLiteValue { self.map { .text($0) } ?? .null }
}

final class Statement {
    fileprivate let handle: OpaquePointer
    init(stmt: OpaquePointer) { self.handle = stmt }

    func bind(_ params: [SQLiteValue]) {
        for (i, value) in params.enumerated() {
            let idx = Int32(i + 1)
            switch value {
            case .int(let v): sqlite3_bind_int64(handle, idx, v)
            case .double(let v): sqlite3_bind_double(handle, idx, v)
            case .text(let v): sqlite3_bind_text(handle, idx, v, -1, SQLITE_TRANSIENT)
            case .null: sqlite3_bind_null(handle, idx)
            }
        }
    }

    /// Step expecting at least one row available; returns true while rows remain.
    @discardableResult
    func step() throws -> Bool {
        let rc = sqlite3_step(handle)
        if rc == SQLITE_ROW { return true }
        if rc == SQLITE_DONE { return false }
        throw SQLiteError.step("step rc=\(rc)")
    }

    /// Step a statement that should not return rows.
    func stepDone() throws {
        let rc = sqlite3_step(handle)
        if rc != SQLITE_DONE && rc != SQLITE_ROW {
            throw SQLiteError.step("stepDone rc=\(rc)")
        }
    }

    func finalize() { sqlite3_finalize(handle) }
}

/// Column accessor for the current row of a stepped statement.
struct Row {
    let stmt: OpaquePointer

    func int(_ i: Int32) -> Int64 { sqlite3_column_int64(stmt, i) }
    func double(_ i: Int32) -> Double { sqlite3_column_double(stmt, i) }
    func bool(_ i: Int32) -> Bool { sqlite3_column_int64(stmt, i) != 0 }

    func string(_ i: Int32) -> String? {
        guard sqlite3_column_type(stmt, i) != SQLITE_NULL else { return nil }
        guard let c = sqlite3_column_text(stmt, i) else { return nil }
        return String(cString: c)
    }

    func date(_ i: Int32) -> Date {
        Date(timeIntervalSince1970: double(i))
    }

    func optionalDate(_ i: Int32) -> Date? {
        guard sqlite3_column_type(stmt, i) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSince1970: double(i))
    }
}
