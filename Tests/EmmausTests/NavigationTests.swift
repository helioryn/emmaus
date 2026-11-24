import XCTest
@testable import Emmaus

/// Chapter navigation is the class of bug where the header and the text
/// disagree, so it gets exercised against the real library.
@MainActor
final class NavigationTests: XCTestCase {

    private func makeApp() throws -> AppState {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("emmaus-nav-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let user = UserStore(path: dir.appendingPathComponent("user.db"))
        return AppState(bible: BibleStore(db: try openLibraryDatabase()), user: user)
    }

    func testChapterIsClampedToTheBook() throws {
        let app = try makeApp()
        app.open(book: 19, chapter: 999)
        XCTAssertEqual(app.chapter, 150)
        app.open(book: 19, chapter: 0)
        XCTAssertEqual(app.chapter, 1)
    }

    func testBookIsClampedToTheCanon() throws {
        let app = try makeApp()
        app.open(book: 99, chapter: 1)
        XCTAssertEqual(app.bookId, 66)
        app.open(book: -3, chapter: 1)
        XCTAssertEqual(app.bookId, 1)
    }

    func testNextChapterCrossesIntoTheNextBook() throws {
        let app = try makeApp()
        app.open(book: 1, chapter: 50)
        app.nextChapter()
        XCTAssertEqual(app.bookId, 2)
        XCTAssertEqual(app.chapter, 1)
        XCTAssertEqual(app.chapterData?.book, 2)
        XCTAssertEqual(app.chapterData?.chapter, 1)
    }

    func testPreviousChapterCrossesBack() throws {
        let app = try makeApp()
        app.open(book: 2, chapter: 1)
        app.previousChapter()
        XCTAssertEqual(app.bookId, 1)
        XCTAssertEqual(app.chapter, 50)
        XCTAssertEqual(app.chapterData?.book, 1)
    }

    func testNavigationStopsAtTheEnds() throws {
        let app = try makeApp()
        app.open(book: 66, chapter: 22)
        app.nextChapter()
        XCTAssertEqual(app.bookId, 66)
        XCTAssertEqual(app.chapter, 22)

        app.open(book: 1, chapter: 1)
        app.previousChapter()
        XCTAssertEqual(app.bookId, 1)
        XCTAssertEqual(app.chapter, 1)
    }

    func testHistoryBackAndForward() throws {
        let app = try makeApp()
        app.open(book: 1, chapter: 1)
        app.open(book: 2, chapter: 3)

        XCTAssertTrue(app.canGoBack)
        app.goBack()
        XCTAssertEqual(app.bookId, 1)
        XCTAssertEqual(app.chapter, 1)

        XCTAssertTrue(app.canGoForward)
        app.goForward()
        XCTAssertEqual(app.bookId, 2)
        XCTAssertEqual(app.chapter, 3)
    }

    func testNewNavigationDropsForwardHistory() throws {
        let app = try makeApp()
        app.open(book: 1, chapter: 1)
        app.open(book: 2, chapter: 2)
        app.goBack()
        app.open(book: 3, chapter: 3)
        XCTAssertFalse(app.canGoForward)
        XCTAssertEqual(app.history.last?.book, 3)
        XCTAssertEqual(app.historyIndex, app.history.count - 1)
    }

    /// The sidebar moves `bookId` without loading a chapter, so `open` cannot
    /// rely on the state variables alone to decide whether to reload.
    func testSidebarSelectionStillLoadsTheChapter() throws {
        let app = try makeApp()
        app.open(book: 43, chapter: 1)
        app.bookId = 45
        XCTAssertEqual(app.chapterData?.book, 43)

        app.open(book: 45, chapter: 1)
        XCTAssertEqual(app.chapterData?.book, 45)
        XCTAssertEqual(app.chapterData?.chapter, 1)
    }

    func testLoadedChapterFollowsTheTranslation() throws {
        let app = try makeApp()
        app.open(book: 43, chapter: 1)
        XCTAssertEqual(app.chapterData?.translation, "KJV")
        app.translationCode = "LUT"
        app.open(book: 43, chapter: 1)
        XCTAssertEqual(app.chapterData?.translation, "LUT")
    }

    func testOpenReferenceSelectsTheVerse() throws {
        let app = try makeApp()
        app.open(reference: "John 3:16")
        XCTAssertEqual(app.bookId, 43)
        XCTAssertEqual(app.chapter, 3)
        XCTAssertEqual(app.selectedVerse, 16)
    }
}
