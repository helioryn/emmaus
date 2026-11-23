import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum DBError: Error, LocalizedError {
    case open(String)
    case prepare(String)
    case step(String)

    var errorDescription: String? {
        switch self {
        case .open(let m): return "Could not open database: \(m)"
        case .prepare(let m): return "Could not prepare database query: \(m)"
        case .step(let m): return "Database error: \(m)"
        }
    }
}

/// Thin, thread-safe SQLite wrapper. The app uses one read-only connection for
/// the Bible library and one read/write connection for personal data.
final class Database {
    private var db: OpaquePointer?
    private let lock = NSLock()
    let path: String

    init(path: String, readonly: Bool = false) throws {
        self.path = path
        var flags = readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        flags |= SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if db != nil { sqlite3_close(db) }
            throw DBError.open(msg)
        }
        sqlite3_busy_timeout(db, 4000)
        if !readonly {
            _ = exec("PRAGMA journal_mode=WAL;")
            _ = exec("PRAGMA synchronous=NORMAL;")
        }
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    @discardableResult
    func exec(_ sql: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let db else { return false }
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if let err { sqlite3_free(err) }
        return rc == SQLITE_OK
    }

    func run(_ sql: String, _ params: [Any?] = []) throws {
        lock.lock(); defer { lock.unlock() }
        guard let db else { return }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, params)
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw DBError.step(String(cString: sqlite3_errmsg(db)))
        }
    }

    func rows(_ sql: String, _ params: [Any?] = []) -> [[String: Any]] {
        lock.lock(); defer { lock.unlock() }
        guard let db else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, params)
        var result: [[String: Any]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<sqlite3_column_count(stmt) {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER:
                    row[name] = Int(sqlite3_column_int64(stmt, i))
                case SQLITE_FLOAT:
                    row[name] = sqlite3_column_double(stmt, i)
                case SQLITE_TEXT:
                    if let c = sqlite3_column_text(stmt, i) {
                        row[name] = String(cString: c)
                    } else {
                        row[name] = ""
                    }
                case SQLITE_BLOB:
                    let n = Int(sqlite3_column_bytes(stmt, i))
                    if let p = sqlite3_column_blob(stmt, i), n > 0 {
                        row[name] = Data(bytes: p, count: n)
                    } else {
                        row[name] = Data()
                    }
                default:
                    row[name] = NSNull()
                }
            }
            result.append(row)
        }
        return result
    }

    func scalarInt(_ sql: String, _ params: [Any?] = []) -> Int {
        (rows(sql, params).first?.values.first as? Int) ?? 0
    }

    func scalarString(_ sql: String, _ params: [Any?] = []) -> String? {
        rows(sql, params).first?.values.first as? String
    }

    func transaction(_ body: () throws -> Void) rethrows {
        _ = exec("BEGIN IMMEDIATE")
        do {
            try body()
            _ = exec("COMMIT")
        } catch {
            _ = exec("ROLLBACK")
            throw error
        }
    }

    private func bind(_ stmt: OpaquePointer?, _ params: [Any?]) {
        for (i, value) in params.enumerated() {
            let idx = Int32(i + 1)
            switch value {
            case nil, is NSNull:
                sqlite3_bind_null(stmt, idx)
            case let v as Int:
                sqlite3_bind_int64(stmt, idx, Int64(v))
            case let v as Int64:
                sqlite3_bind_int64(stmt, idx, v)
            case let v as Bool:
                sqlite3_bind_int64(stmt, idx, v ? 1 : 0)
            case let v as Double:
                sqlite3_bind_double(stmt, idx, v)
            case let v as String:
                sqlite3_bind_text(stmt, idx, v, -1, SQLITE_TRANSIENT)
            case let v as Data:
                _ = v.withUnsafeBytes { buf in
                    sqlite3_bind_blob(stmt, idx, buf.baseAddress, Int32(v.count), SQLITE_TRANSIENT)
                }
            default:
                sqlite3_bind_text(stmt, idx, String(describing: value), -1, SQLITE_TRANSIENT)
            }
        }
    }
}

extension Int {
    var int64: Int64 { Int64(self) }
}
