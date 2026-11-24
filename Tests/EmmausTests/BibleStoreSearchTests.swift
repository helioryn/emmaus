import XCTest
@testable import Emmaus

/// Exercises the real database when it is present. The library is generated,
/// not committed, so these tests skip on a fresh checkout.
final class BibleStoreSearchTests: XCTestCase {
    private var store: BibleStore?

    override func setUpWithError() throws {
        store = BibleStore(db: try openLibraryDatabase())
    }

    func testFullTextTranslationReturnsPythonMarkedSnippets() throws {
        let store = try XCTUnwrap(store)
        let hits = store.search("love", translation: "KJV")
        XCTAssertFalse(hits.isEmpty)
        XCTAssertTrue(hits.contains { $0.snippet.contains("⟦") })
        XCTAssertTrue(hits.allSatisfy { $0.translation == "KJV" })
    }

    func testTranslationsOutsideTheIndexStillSearch() throws {
        let store = try XCTUnwrap(store)
        // Luther 1912 is bundled from eBible.org and has no FTS rows.
        let hits = store.search("Liebe", translation: "LUT")
        XCTAssertFalse(hits.isEmpty, "literal fallback returned nothing")
        XCTAssertTrue(hits.allSatisfy { $0.translation == "LUT" })
        XCTAssertTrue(hits.contains { $0.snippet.contains("⟦") })
    }

    func testChineseFallbackSearch() throws {
        let store = try XCTUnwrap(store)
        let hits = store.search("神", translation: "CUVS")
        XCTAssertFalse(hits.isEmpty, "CJK literal fallback returned nothing")
    }

    func testHebrewSearchIgnoresPoints() throws {
        let store = try XCTUnwrap(store)
        let hits = store.search("אלהים", translation: "HEB")
        XCTAssertFalse(hits.isEmpty, "unpointed Hebrew query returned nothing")
        XCTAssertTrue(hits.allSatisfy { $0.translation == "HEB" })
    }

    func testGreekSearchIgnoresAccents() throws {
        let store = try XCTUnwrap(store)
        let hits = store.search("θεος", translation: "GRK")
        XCTAssertFalse(hits.isEmpty, "unaccented Greek query returned nothing")
    }

    func testGreekAccentedQueryStillWorks() throws {
        let store = try XCTUnwrap(store)
        XCTAssertFalse(store.search("ἀγάπη", translation: "GRK").isEmpty)
    }

    func testScopeLimitsResults() throws {
        let store = try XCTUnwrap(store)
        let psalmHits = store.search("shepherd", translation: "KJV", scope: .book(19))
        XCTAssertFalse(psalmHits.isEmpty)
        XCTAssertTrue(psalmHits.allSatisfy { $0.book == 19 })
    }

    func testNonsenseQueryReturnsNothing() throws {
        let store = try XCTUnwrap(store)
        XCTAssertTrue(store.search("zzzzqqqxx", translation: "LUT").isEmpty)
    }

    func testOperatorsDoNotThrow() throws {
        let store = try XCTUnwrap(store)
        for query in ["AND", "OR", "NOT", "faith AND", "\"", "NEAR(", "a*"] {
            _ = store.search(query, translation: "KJV")
        }
    }
}
