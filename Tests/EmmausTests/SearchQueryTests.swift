import XCTest
@testable import Emmaus

final class SearchQueryTests: XCTestCase {

    func testBareWordGetsPrefixExpansion() {
        XCTAssertEqual(SearchQuery.ftsExpression("love"), "\"love\"*")
    }

    func testExplicitAsteriskIsPrefix() {
        XCTAssertEqual(SearchQuery.ftsExpression("lov*"), "\"lov\"*")
    }

    func testExplicitAndIsKept() {
        XCTAssertEqual(SearchQuery.ftsExpression("faith AND works"), "\"faith\" AND \"works\"*")
    }

    func testExplicitOrIsKept() {
        XCTAssertEqual(SearchQuery.ftsExpression("love OR grace"), "\"love\" OR \"grace\"*")
    }

    func testQuotedPhraseIsPreserved() {
        XCTAssertEqual(SearchQuery.ftsExpression("\"in the beginning\""), "\"in the beginning\"")
    }

    func testLeadingOperatorIsDropped() {
        XCTAssertEqual(SearchQuery.ftsExpression("AND"), "")
        XCTAssertEqual(SearchQuery.ftsExpression("OR love"), "\"love\"*")
    }

    func testTrailingOperatorIsDropped() {
        XCTAssertEqual(SearchQuery.ftsExpression("faith AND"), "\"faith\"")
    }

    func testSingleCharacterWordIsNotPrefixExpanded() {
        XCTAssertEqual(SearchQuery.ftsExpression("a"), "\"a\"")
    }

    func testUnbalancedQuoteFallsBackToWords() {
        let expr = SearchQuery.ftsExpression("\"in the beginning")
        XCTAssertTrue(expr.contains("\"the\""))
        XCTAssertFalse(expr.contains("\"\""))
    }

    func testPunctuationCannotBecomeFtsSyntax() {
        let expr = SearchQuery.ftsExpression("love\"; DROP TABLE verses; --")
        XCTAssertTrue(expr.contains("\"love\""))
        XCTAssertTrue(expr.contains("\"DROP\""))
        XCTAssertTrue(expr.contains("\"TABLE\""))
        XCTAssertFalse(expr.contains(";"))
    }

    func testFtsOperatorsInInputAreQuotedAsWords() {
        let expr = SearchQuery.ftsExpression("NEAR(")
        XCTAssertEqual(expr, "\"NEAR\"*")
    }

    func testEmptyAndWhitespaceReturnEmpty() {
        XCTAssertEqual(SearchQuery.ftsExpression(""), "")
        XCTAssertEqual(SearchQuery.ftsExpression("   \n\t "), "")
    }

    func testQueryIsLengthCapped() {
        let input = String(repeating: "love ", count: 200)
        let expr = SearchQuery.ftsExpression(input)
        XCTAssertFalse(expr.isEmpty)
        XCTAssertLessThanOrEqual(expr.components(separatedBy: " AND ").count, 45)
    }

    func testNotIsKeptBetweenTerms() {
        XCTAssertEqual(SearchQuery.ftsExpression("faith NOT works"), "\"faith\" NOT \"works\"*")
    }

    func testLiteralTerms() {
        XCTAssertEqual(SearchQuery.literalTerms("love grace"), ["love", "grace"])
        XCTAssertEqual(SearchQuery.literalTerms("\"in the beginning\""), [])
        XCTAssertEqual(SearchQuery.literalTerms("love OR grace"), ["love", "grace"])
    }

    func testSanitizeKeepsUnicodeLetters() {
        XCTAssertEqual(SearchQuery.sanitize("Liebe", allowSpaces: false), "Liebe")
        XCTAssertEqual(SearchQuery.sanitize("ἀγάπη", allowSpaces: false), "ἀγάπη")
        XCTAssertEqual(SearchQuery.sanitize("??", allowSpaces: false), nil)
    }

    func testPlainFoldsHebrewPoints() {
        XCTAssertEqual(SearchQuery.plain("בְּרֵאשִׁ֖ית אֱלֹהִ֑ים"), "בראשית אלהים")
    }

    func testPlainFoldsGreekAccentsAndFinalSigma() {
        XCTAssertEqual(SearchQuery.plain("Ἐν ἀρχῇ"), "εν αρχη")
        XCTAssertEqual(SearchQuery.plain("θεὸς"), "θεοσ")
    }

    func testPlainDropsPunctuationButKeepsSpaces() {
        XCTAssertEqual(SearchQuery.plain("λόγος, καὶ"), "λογοσ και")
    }
}
