import XCTest
@testable import Emmaus

/// The library is generated, so these checks guard the database itself rather
/// than the SwiftUI layer that reads it.
final class LibraryIntegrityTests: XCTestCase {
    private var db: Database!

    override func setUpWithError() throws {
        db = try openLibraryDatabase()
    }

    func testEveryVerseHasText() {
        XCTAssertEqual(db.scalarInt("SELECT COUNT(*) FROM verses WHERE text IS NULL OR TRIM(text) = ''"), 0)
    }

    func testBookChapterCountsMatchTheText() {
        let mismatches = db.rows("""
            SELECT b.id, b.name, b.chapters,
                   (SELECT MAX(chapter) FROM verses v WHERE v.translation = 'KJV' AND v.book = b.id) AS last
            FROM books b
            WHERE b.chapters != (SELECT MAX(chapter) FROM verses v WHERE v.translation = 'KJV' AND v.book = b.id)
            """)
        XCTAssertTrue(mismatches.isEmpty, "\(mismatches.count) books disagree with the KJV text")
    }

    func testCrossReferencesResolve() {
        XCTAssertEqual(db.scalarInt("""
            SELECT COUNT(*) FROM cross_refs c
            LEFT JOIN verses v
              ON v.translation = 'KJV' AND v.book = c.to_book
             AND v.chapter = c.to_chapter AND v.verse = c.to_verse_start
            WHERE v.verse IS NULL
            """), 0)
    }

    func testStrongsOccurrencesResolve() {
        XCTAssertEqual(db.scalarInt("""
            SELECT COUNT(*) FROM occurrences o
            LEFT JOIN strongs s ON s.id = o.strongs
            WHERE s.id IS NULL
            """), 0)
    }

    func testEveryTranslationHasVerses() {
        let empty = db.rows("""
            SELECT t.code FROM translations t
            LEFT JOIN verses v ON v.translation = t.code
            WHERE t.source = 'local'
            GROUP BY t.code
            HAVING COUNT(v.verse) = 0
            """)
        XCTAssertTrue(empty.isEmpty, "empty translations: \(empty.compactMap { $0["code"] as? String })")
    }

    func testOriginalLanguagesKeepTheirScope() {
        XCTAssertEqual(db.scalarInt("SELECT COUNT(DISTINCT book) FROM verses WHERE translation = 'HEB'"), 39)
        XCTAssertEqual(db.scalarInt("SELECT COUNT(DISTINCT book) FROM verses WHERE translation = 'GRK'"), 27)
    }

    func testSchemaVersionIsRecorded() {
        XCTAssertEqual(db.scalarString("SELECT value FROM meta WHERE key = 'schema'"), "1")
    }
}

/// Opens `Resources/bible.db`, or skips on a checkout where it is not built.
func openLibraryDatabase() throws -> Database {
    let path = FileManager.default.currentDirectoryPath + "/Resources/bible.db"
    guard FileManager.default.fileExists(atPath: path) else {
        throw XCTSkip("Resources/bible.db is not built")
    }
    return try Database(path: path, readonly: true)
}
