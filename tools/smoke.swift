// Framework-free checks for the search path.
//
// XCTest is not shipped with the Command Line Tools, so `swift test` only runs
// on a machine with full Xcode. This harness compiles the pure sources directly
// and fails loudly, which keeps the search fixes verifiable everywhere:
//
//   bash tools/smoke.sh
//
// The same expectations live in Tests/EmmausTests for CI.

import Foundation

@main
struct Smoke {
    static var failures = 0

    static func check(_ name: String, _ condition: @autoclosure () -> Bool) {
        if condition() {
            print("  ok   \(name)")
        } else {
            failures += 1
            print("  FAIL \(name)")
        }
    }

    static func equal<T: Equatable>(_ name: String, _ actual: T, _ expected: T) {
        check("\(name) — got \(actual)", actual == expected)
    }

    static func main() throws {
        print("SearchQuery")
        equal("bare word", SearchQuery.ftsExpression("love"), "\"love\"*")
        equal("explicit prefix", SearchQuery.ftsExpression("lov*"), "\"lov\"*")
        equal("AND kept", SearchQuery.ftsExpression("faith AND works"), "\"faith\" AND \"works\"*")
        equal("OR kept", SearchQuery.ftsExpression("love OR grace"), "\"love\" OR \"grace\"*")
        equal("phrase preserved", SearchQuery.ftsExpression("\"in the beginning\""), "\"in the beginning\"")
        equal("lone operator dropped", SearchQuery.ftsExpression("AND"), "")
        equal("leading operator dropped", SearchQuery.ftsExpression("OR love"), "\"love\"*")
        equal("trailing operator dropped", SearchQuery.ftsExpression("faith AND"), "\"faith\"")
        equal("NOT kept", SearchQuery.ftsExpression("faith NOT works"), "\"faith\" NOT \"works\"*")
        equal("one letter", SearchQuery.ftsExpression("a"), "\"a\"")
        equal("FTS operator quoted", SearchQuery.ftsExpression("NEAR("), "\"NEAR\"*")
        equal("empty", SearchQuery.ftsExpression("   "), "")

        let injected = SearchQuery.ftsExpression("love\"; DROP TABLE verses; --")
        check("injection quoted", injected.contains("\"DROP\"") && !injected.contains(";"))
        check("unbalanced quote survives", !SearchQuery.ftsExpression("\"in the beginning").isEmpty)
        check("query capped", SearchQuery.ftsExpression(String(repeating: "love ", count: 200))
            .components(separatedBy: " AND ").count <= 45)
        equal("literal terms", SearchQuery.literalTerms("love grace"), ["love", "grace"])
        equal("literal phrase only", SearchQuery.literalTerms("\"in the beginning\""), [])

        print("Database")
        let path = FileManager.default.currentDirectoryPath + "/Resources/bible.db"
        guard FileManager.default.fileExists(atPath: path) else {
            print("  skip no bible.db")
            finish()
        }
        let store = BibleStore(db: try Database(path: path, readonly: true))

        let kjv = store.search("love", translation: "KJV")
        check("KJV finds love", !kjv.isEmpty)
        check("KJV marks snippets", kjv.contains { $0.snippet.contains("⟦") })

        let luther = store.search("Liebe", translation: "LUT")
        check("Luther fallback finds Liebe", !luther.isEmpty)
        check("Luther hits tagged", luther.allSatisfy { $0.translation == "LUT" })
        check("Luther snippets marked", luther.contains { $0.snippet.contains("⟦") })

        let chinese = store.search("神", translation: "CUVS")
        check("CUVS fallback finds 神", !chinese.isEmpty)

        check("plain folds Hebrew points", SearchQuery.plain("בְּרֵאשִׁ֖ית") == "בראשית")
        check("plain folds Greek accents", SearchQuery.plain("ἀγάπη") == "αγαπη")
        check("plain folds final sigma", SearchQuery.plain("θεὸς") == "θεοσ")

        let hebrew = store.search("אלהים", translation: "HEB")
        check("HEB unpointed finds אלהים", !hebrew.isEmpty)
        let greek = store.search("θεος", translation: "GRK")
        check("GRK unaccented finds θεος", !greek.isEmpty)
        let greekBook = store.search("λογος", translation: "GRK", scope: .book(43))
        check("GRK scope holds", !greekBook.isEmpty && greekBook.allSatisfy { $0.book == 43 })

        let psalms = store.search("shepherd", translation: "KJV", scope: .book(19))
        check("scope limits to Psalms", !psalms.isEmpty && psalms.allSatisfy { $0.book == 19 })

        check("nonsense is empty", store.search("zzzzqqqxx", translation: "LUT").isEmpty)
        for query in ["AND", "OR", "NOT", "faith AND", "\"", "a*"] {
            _ = store.search(query, translation: "KJV")
        }
        check("hostile queries do not crash", true)

        finish()
    }

    static func finish() -> Never {
        if failures == 0 {
            print("\nAll checks passed.")
            exit(0)
        }
        print("\n\(failures) check(s) failed.")
        exit(1)
    }
}
