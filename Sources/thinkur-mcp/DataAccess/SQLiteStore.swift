import Foundation
import SQLite3

/// Read-only SQLite wrapper for querying thinkur's SwiftData stores.
final class SQLiteStore {
    private let db: OpaquePointer?
    let path: String

    init(path: String) throws {
        self.path = path
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let rc = sqlite3_open_v2(path, &handle, flags, nil)
        guard rc == SQLITE_OK else {
            let msg = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw SQLiteError.openFailed(path: path, message: msg)
        }
        self.db = handle
    }

    deinit {
        sqlite3_close(db)
    }

    /// Execute a query and map each row to a value using the provided closure.
    func query<T>(_ sql: String, bind: [Any] = [], map: (OpaquePointer) -> T) throws -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw SQLiteError.prepareFailed(message: msg)
        }
        defer { sqlite3_finalize(stmt) }

        for (i, value) in bind.enumerated() {
            let idx = Int32(i + 1)
            switch value {
            case let v as String:
                sqlite3_bind_text(stmt, idx, (v as NSString).utf8String, -1, nil)
            case let v as Int:
                sqlite3_bind_int64(stmt, idx, Int64(v))
            case let v as Double:
                sqlite3_bind_double(stmt, idx, v)
            default:
                break
            }
        }

        var results: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(map(stmt!))
        }
        return results
    }

    // MARK: - Column helpers

    static func text(_ stmt: OpaquePointer, _ col: Int32) -> String {
        sqlite3_column_text(stmt, col).map { String(cString: $0) } ?? ""
    }

    static func int(_ stmt: OpaquePointer, _ col: Int32) -> Int {
        Int(sqlite3_column_int64(stmt, col))
    }

    static func double(_ stmt: OpaquePointer, _ col: Int32) -> Double {
        sqlite3_column_double(stmt, col)
    }

    static func optionalText(_ stmt: OpaquePointer, _ col: Int32) -> String? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL else { return nil }
        return sqlite3_column_text(stmt, col).map { String(cString: $0) }
    }

    static func optionalBlob(_ stmt: OpaquePointer, _ col: Int32) -> Data? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL else { return nil }
        let bytes = sqlite3_column_blob(stmt, col)
        let len = sqlite3_column_bytes(stmt, col)
        guard let bytes, len > 0 else { return nil }
        return Data(bytes: bytes, count: Int(len))
    }
}

enum SQLiteError: Error, CustomStringConvertible {
    case openFailed(path: String, message: String)
    case prepareFailed(message: String)

    var description: String {
        switch self {
        case .openFailed(let path, let message):
            return "Failed to open database at \(path): \(message)"
        case .prepareFailed(let message):
            return "SQL prepare failed: \(message)"
        }
    }
}
