import XCTest
@testable import Emmaus

final class ReferenceParserTests: XCTestCase {

    func testReferenceWithVerse() {
        let ref = ReferenceParser.parse("John 3:16")
        XCTAssertEqual(ref?.book, 43)
        XCTAssertEqual(ref?.chapter, 3)
        XCTAssertEqual(ref?.verse, 16)
    }

    func testReferenceWithoutVerse() {
        let ref = ReferenceParser.parse("Ps 23")
        XCTAssertEqual(ref?.book, 19)
        XCTAssertEqual(ref?.chapter, 23)
        XCTAssertNil(ref?.verse)
    }

    func testNumberedBook() {
        let ref = ReferenceParser.parse("1 Cor 13:4")
        XCTAssertEqual(ref?.book, 46)
        XCTAssertEqual(ref?.chapter, 13)
        XCTAssertEqual(ref?.verse, 4)
    }

    func testCompactNumberedBook() {
        XCTAssertEqual(ReferenceParser.parse("1john 4")?.book, 62)
    }

    func testLowercaseAndPeriodSpacing() {
        let ref = ReferenceParser.parse("  gen. 1:1 ")
        XCTAssertEqual(ref?.book, 1)
        XCTAssertEqual(ref?.chapter, 1)
        XCTAssertEqual(ref?.verse, 1)
    }

    func testNonReferenceIsNil() {
        XCTAssertNil(ReferenceParser.parse("love"))
        XCTAssertNil(ReferenceParser.parse(""))
        XCTAssertNil(ReferenceParser.parse("Narnia 1:1"))
    }

    func testLabel() {
        XCTAssertEqual(ReferenceParser.label(book: 43, chapter: 3, verse: 16), "John 3:16")
        XCTAssertEqual(ReferenceParser.label(book: 19, chapter: 23), "Psalms 23")
    }
}

final class APIBibleParsingTests: XCTestCase {

    func testVerseMarkersAreSplit() {
        let verses = APIBibleClient.parseVerses("[1] In the beginning God created [2] And the earth was formless")
        XCTAssertEqual(verses[1], "In the beginning God created")
        XCTAssertEqual(verses[2], "And the earth was formless")
    }

    func testTextWithoutMarkersBecomesVerseOne() {
        let verses = APIBibleClient.parseVerses("  In the beginning  ")
        XCTAssertEqual(verses, [1: "In the beginning"])
    }

    func testWhitespaceIsCollapsed() {
        let verses = APIBibleClient.parseVerses("[1] a\n\n  b\u{00a0}c")
        XCTAssertEqual(verses[1], "a b c")
    }

    func testEmptyContent() {
        XCTAssertTrue(APIBibleClient.parseVerses("").isEmpty)
    }
}
