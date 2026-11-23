import Foundation

enum AppPaths {
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Emmaus", isDirectory: true)
    }

    static var userDatabase: URL {
        supportDirectory.appendingPathComponent("user.db")
    }

    static var config: URL {
        supportDirectory.appendingPathComponent("config.json")
    }

    static func migrateIfNeeded() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let new = supportDirectory
        let old = base.appendingPathComponent("Selah", isDirectory: true)
        guard fm.fileExists(atPath: old.path) else { return }
        try? fm.createDirectory(at: new, withIntermediateDirectories: true)
        for name in ["user.db", "user.db-wal", "user.db-shm", "config.json"] {
            let src = old.appendingPathComponent(name)
            let dst = new.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path), !fm.fileExists(atPath: dst.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }

    static func ensureSupportDirectory() {
        migrateIfNeeded()
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
    }
}

final class UserStore: ObservableObject {
    let db: Database

    @Published private(set) var notes: [VerseKey: Note] = [:]
    @Published private(set) var highlights: [VerseKey: Int] = [:]
    @Published private(set) var bookmarks: Set<VerseKey> = []
    @Published private(set) var settings: [String: String] = [:]
    @Published private(set) var completedDays: Set<String> = []
    @Published private(set) var activityDays: Set<String> = []
    @Published private(set) var recentReadings: [Location] = []

    init() {
        AppPaths.ensureSupportDirectory()
        do {
            db = try Database(path: AppPaths.userDatabase.path, readonly: false)
        } catch {
            fatalError("Could not open personal database: \(error)")
        }
        createSchema()
        loadAll()
        purgeOldCloudCache()
    }

    private func createSchema() {
        db.exec("""
        CREATE TABLE IF NOT EXISTS notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT, book INT, chapter INT, verse INT,
            body TEXT, created REAL, updated REAL, UNIQUE(book, chapter, verse));
        CREATE TABLE IF NOT EXISTS highlights(
            book INT, chapter INT, verse INT, color INT, created REAL,
            PRIMARY KEY(book, chapter, verse));
        CREATE TABLE IF NOT EXISTS bookmarks(
            book INT, chapter INT, verse INT, created REAL,
            PRIMARY KEY(book, chapter, verse));
        CREATE TABLE IF NOT EXISTS history(
            book INT, chapter INT, last_read REAL, reads INT,
            PRIMARY KEY(book, chapter));
        CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT);
        CREATE TABLE IF NOT EXISTS plan_progress(plan TEXT, day INT, completed REAL, PRIMARY KEY(plan, day));
        CREATE TABLE IF NOT EXISTS activity_days(day TEXT PRIMARY KEY, last REAL);
        CREATE TABLE IF NOT EXISTS cloud_verses(
            translation TEXT, book INT, chapter INT, verse INT, text TEXT, fetched REAL,
            PRIMARY KEY(translation, book, chapter, verse));
        CREATE TABLE IF NOT EXISTS search_history(query TEXT PRIMARY KEY, last_used REAL);
        """)
    }

    private func loadAll() {
        notes = [:]
        for r in db.rows("SELECT * FROM notes") {
            let k = VerseKey(book: r["book"] as? Int ?? 0, chapter: r["chapter"] as? Int ?? 0, verse: r["verse"] as? Int ?? 0)
            notes[k] = Note(
                id: r["id"] as? Int ?? 0,
                book: k.book, chapter: k.chapter, verse: k.verse,
                body: r["body"] as? String ?? "",
                updated: Date(timeIntervalSince1970: r["updated"] as? Double ?? 0)
            )
        }
        highlights = [:]
        for r in db.rows("SELECT * FROM highlights") {
            let k = VerseKey(book: r["book"] as? Int ?? 0, chapter: r["chapter"] as? Int ?? 0, verse: r["verse"] as? Int ?? 0)
            highlights[k] = r["color"] as? Int ?? 0
        }
        bookmarks = Set(db.rows("SELECT * FROM bookmarks").map {
            VerseKey(book: $0["book"] as? Int ?? 0, chapter: $0["chapter"] as? Int ?? 0, verse: $0["verse"] as? Int ?? 0)
        })
        settings = [:]
        for r in db.rows("SELECT * FROM settings") {
            if let k = r["key"] as? String, let v = r["value"] as? String { settings[k] = v }
        }
        completedDays = Set(db.rows("SELECT plan, day FROM plan_progress").compactMap {
            guard let p = $0["plan"] as? String, let d = $0["day"] as? Int else { return nil }
            return "\(p)#\(d)"
        })
        activityDays = Set(db.rows("SELECT day FROM activity_days").compactMap { $0["day"] as? String })
        recentReadings = db.rows("SELECT book, chapter FROM history ORDER BY last_read DESC LIMIT 12").compactMap {
            guard let b = $0["book"] as? Int, let c = $0["chapter"] as? Int else { return nil }
            return Location(book: b, chapter: c, verse: nil)
        }
    }

    // MARK: - Settings

    func string(_ key: String, _ fallback: String = "") -> String { settings[key] ?? fallback }
    func int(_ key: String, _ fallback: Int = 0) -> Int { Int(settings[key] ?? "") ?? fallback }
    func double(_ key: String, _ fallback: Double = 0) -> Double { Double(settings[key] ?? "") ?? fallback }
    func bool(_ key: String, _ fallback: Bool = false) -> Bool { settings[key].map { $0 == "1" } ?? fallback }

    func setSetting(_ key: String, _ value: String) {
        settings[key] = value
        try? db.run("INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)", [key, value])
    }

    func setSetting(_ key: String, _ value: Int) { setSetting(key, String(value)) }
    func setSetting(_ key: String, _ value: Double) { setSetting(key, String(value)) }
    func setSetting(_ key: String, _ value: Bool) { setSetting(key, value ? "1" : "0") }

    // MARK: - History & activity

    func recordHistory(book: Int, chapter: Int) {
        let now = Date().timeIntervalSince1970
        try? db.run("""
            INSERT INTO history(book,chapter,last_read,reads) VALUES(?,?,?,1)
            ON CONFLICT(book,chapter) DO UPDATE SET last_read=excluded.last_read, reads=reads+1
            """, [book, chapter, now])
        let day = Self.dayKey(Date())
        try? db.run("INSERT OR REPLACE INTO activity_days(day,last) VALUES(?,?)", [day, now])
        activityDays.insert(day)
        recentReadings.removeAll { $0.book == book && $0.chapter == chapter }
        recentReadings.insert(Location(book: book, chapter: chapter, verse: nil), at: 0)
        if recentReadings.count > 12 { recentReadings = Array(recentReadings.prefix(12)) }
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        var count = 0
        // A streak is alive if today or yesterday was read.
        if !activityDays.contains(Self.dayKey(day)) {
            guard let y = cal.date(byAdding: .day, value: -1, to: day), activityDays.contains(Self.dayKey(y)) else { return 0 }
            day = y
        }
        while activityDays.contains(Self.dayKey(day)) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    var chaptersRead: Int {
        db.scalarInt("SELECT COUNT(*) FROM history")
    }

    func lastChapter(book: Int) -> Int? {
        db.rows("SELECT chapter FROM history WHERE book=? ORDER BY last_read DESC LIMIT 1", [book]).first?["chapter"] as? Int
    }

    func readChapters(book: Int) -> Set<Int> {
        Set(db.rows("SELECT chapter FROM history WHERE book=?", [book]).compactMap { $0["chapter"] as? Int })
    }

    func chapterHasMarks(book: Int, chapter: Int) -> Bool {
        if notes.keys.contains(where: { $0.book == book && $0.chapter == chapter }) { return true }
        if highlights.keys.contains(where: { $0.book == book && $0.chapter == chapter }) { return true }
        if bookmarks.contains(where: { $0.book == book && $0.chapter == chapter }) { return true }
        return false
    }

    func notes(in book: Int) -> [Note] {
        notes.values.filter { $0.book == book }.sorted { $0.updated > $1.updated }
    }

    var lastReading: Location? {
        db.rows("SELECT book, chapter FROM history ORDER BY last_read DESC LIMIT 1").first.flatMap {
            guard let b = $0["book"] as? Int, let c = $0["chapter"] as? Int else { return nil }
            return Location(book: b, chapter: c, verse: nil)
        }
    }

    // MARK: - Notes

    func note(book: Int, chapter: Int, verse: Int) -> Note? {
        notes[VerseKey(book: book, chapter: chapter, verse: verse)]
    }

    func saveNote(book: Int, chapter: Int, verse: Int, body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = VerseKey(book: book, chapter: chapter, verse: verse)
        let now = Date().timeIntervalSince1970
        if trimmed.isEmpty {
            notes.removeValue(forKey: key)
            try? db.run("DELETE FROM notes WHERE book=? AND chapter=? AND verse=?", [book, chapter, verse])
            return
        }
        try? db.run("""
            INSERT INTO notes(book,chapter,verse,body,created,updated) VALUES(?,?,?,?,?,?)
            ON CONFLICT(book,chapter,verse) DO UPDATE SET body=excluded.body, updated=excluded.updated
            """, [book, chapter, verse, trimmed, now, now])
        if let existing = notes[key] {
            notes[key] = Note(id: existing.id, book: book, chapter: chapter, verse: verse, body: trimmed, updated: Date())
        } else if let id = db.rows("SELECT id FROM notes WHERE book=? AND chapter=? AND verse=?", [book, chapter, verse]).first?["id"] as? Int {
            notes[key] = Note(id: id, book: book, chapter: chapter, verse: verse, body: trimmed, updated: Date())
        }
    }

    func deleteNote(_ note: Note) {
        notes.removeValue(forKey: VerseKey(book: note.book, chapter: note.chapter, verse: note.verse))
        try? db.run("DELETE FROM notes WHERE id=?", [note.id])
    }

    var allNotes: [Note] {
        notes.values.sorted { $0.updated > $1.updated }
    }

    // MARK: - Highlights & bookmarks

    func highlight(book: Int, chapter: Int, verse: Int) -> Int? {
        highlights[VerseKey(book: book, chapter: chapter, verse: verse)]
    }

    func setHighlight(book: Int, chapter: Int, verse: Int, color: Int?) {
        let key = VerseKey(book: book, chapter: chapter, verse: verse)
        if let color {
            highlights[key] = color
            try? db.run("INSERT OR REPLACE INTO highlights(book,chapter,verse,color,created) VALUES(?,?,?,?,?)",
                        [book, chapter, verse, color, Date().timeIntervalSince1970])
        } else {
            highlights.removeValue(forKey: key)
            try? db.run("DELETE FROM highlights WHERE book=? AND chapter=? AND verse=?", [book, chapter, verse])
        }
    }

    func isBookmarked(book: Int, chapter: Int, verse: Int) -> Bool {
        bookmarks.contains(VerseKey(book: book, chapter: chapter, verse: verse))
    }

    func toggleBookmark(book: Int, chapter: Int, verse: Int) {
        let key = VerseKey(book: book, chapter: chapter, verse: verse)
        if bookmarks.contains(key) {
            bookmarks.remove(key)
            try? db.run("DELETE FROM bookmarks WHERE book=? AND chapter=? AND verse=?", [book, chapter, verse])
        } else {
            bookmarks.insert(key)
            try? db.run("INSERT OR REPLACE INTO bookmarks(book,chapter,verse,created) VALUES(?,?,?,?)",
                        [book, chapter, verse, Date().timeIntervalSince1970])
        }
    }

    var allBookmarks: [VerseKey] {
        bookmarks.sorted { a, b in
            if a.book != b.book { return a.book < b.book }
            if a.chapter != b.chapter { return a.chapter < b.chapter }
            return a.verse < b.verse
        }
    }

    // MARK: - Plans

    func isPlanDayComplete(_ plan: String, _ day: Int) -> Bool {
        completedDays.contains("\(plan)#\(day)")
    }

    func setPlanDayComplete(_ plan: String, _ day: Int, complete: Bool) {
        let key = "\(plan)#\(day)"
        if complete {
            completedDays.insert(key)
            try? db.run("INSERT OR REPLACE INTO plan_progress(plan,day,completed) VALUES(?,?,?)",
                        [plan, day, Date().timeIntervalSince1970])
            markActivityToday()
        } else {
            completedDays.remove(key)
            try? db.run("DELETE FROM plan_progress WHERE plan=? AND day=?", [plan, day])
        }
    }

    func markActivityToday() {
        let now = Date().timeIntervalSince1970
        let day = Self.dayKey(Date())
        try? db.run("INSERT OR REPLACE INTO activity_days(day,last) VALUES(?,?)", [day, now])
        activityDays.insert(day)
    }

    // MARK: - Cloud cache

    func cachedCloudChapter(translation: String, book: Int, chapter: Int) -> (verses: [Int: String], fetched: Date)? {
        let rows = db.rows("""
            SELECT verse,text,fetched FROM cloud_verses
            WHERE translation=? AND book=? AND chapter=? ORDER BY verse
            """, [translation, book, chapter])
        guard !rows.isEmpty else { return nil }
        var verses: [Int: String] = [:]
        var newest = Date(timeIntervalSince1970: 0)
        for r in rows {
            if let v = r["verse"] as? Int, let t = r["text"] as? String { verses[v] = t }
            if let f = r["fetched"] as? Double { newest = max(newest, Date(timeIntervalSince1970: f)) }
        }
        return (verses, newest)
    }

    func cacheCloudChapter(translation: String, book: Int, chapter: Int, verses: [Int: String]) {
        let now = Date().timeIntervalSince1970
        db.transaction {
            for (v, t) in verses {
                try? db.run("""
                    INSERT OR REPLACE INTO cloud_verses(translation,book,chapter,verse,text,fetched)
                    VALUES(?,?,?,?,?,?)
                    """, [translation, book, chapter, v, t, now])
            }
        }
        trimCloudCache(maxVerses: 480)
    }

    func cloudCacheStats() -> (chapters: Int, verses: Int) {
        let chapters = db.scalarInt("SELECT COUNT(*) FROM (SELECT DISTINCT translation,book,chapter FROM cloud_verses)")
        let verses = db.scalarInt("SELECT COUNT(*) FROM cloud_verses")
        return (chapters, verses)
    }

    func clearCloudCache() {
        db.exec("DELETE FROM cloud_verses")
    }

    private func trimCloudCache(maxVerses: Int) {
        while db.scalarInt("SELECT COUNT(*) FROM cloud_verses") > maxVerses {
            let oldest = db.rows("""
                SELECT translation, book, chapter, MAX(fetched) AS f
                FROM cloud_verses GROUP BY translation,book,chapter ORDER BY f ASC LIMIT 1
                """).first
            guard let t = oldest?["translation"] as? String,
                  let b = oldest?["book"] as? Int,
                  let c = oldest?["chapter"] as? Int else { break }
            db.exec("DELETE FROM cloud_verses WHERE translation='\(t.replacingOccurrences(of: "'", with: "''"))' AND book=\(b) AND chapter=\(c)")
        }
    }

    private func purgeOldCloudCache() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600).timeIntervalSince1970
        db.exec("DELETE FROM cloud_verses WHERE fetched < \(Int(cutoff))")
    }

    // MARK: - Search history

    func addSearchHistory(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        try? db.run("INSERT OR REPLACE INTO search_history(query,last_used) VALUES(?,?)",
                    [q, Date().timeIntervalSince1970])
    }

    func recentSearches(limit: Int = 8) -> [String] {
        db.rows("SELECT query FROM search_history ORDER BY last_used DESC LIMIT ?", [limit]).compactMap { $0["query"] as? String }
    }

    // MARK: - Export

    func exportMarkdown(bookName: (Int) -> String) -> String {
        var out = "# Emmaus Study Notes\n\n"
        out += "_Exported \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))_\n\n"
        let grouped = Dictionary(grouping: allNotes) { $0.book }
        for bookId in grouped.keys.sorted() {
            guard let entries = grouped[bookId] else { continue }
            out += "## \(bookName(bookId))\n\n"
            for n in entries.sorted(by: { ($0.chapter, $0.verse) < ($1.chapter, $1.verse) }) {
                out += "### \(bookName(bookId)) \(n.chapter):\(n.verse)\n\n\(n.body)\n\n"
            }
        }
        if !bookmarks.isEmpty {
            out += "## Bookmarks\n\n"
            for k in allBookmarks {
                out += "- \(bookName(k.book)) \(k.chapter):\(k.verse)\n"
            }
        }
        return out
    }
}
