import XCTest
@testable import Emmaus

final class PlanTests: XCTestCase {

    private func locations(_ count: Int) -> [Location] {
        (1...count).map { Location(book: 1, chapter: $0, verse: nil) }
    }

    func testDistributeSplitsEvenly() {
        let days = PlanLibrary.distribute(locations(10), into: 3)
        XCTAssertEqual(days.count, 3)
        XCTAssertEqual(days.map(\.count), [4, 3, 3])
        XCTAssertEqual(days.flatMap { $0 }.count, 10)
    }

    func testDistributePadsShortPlans() {
        let days = PlanLibrary.distribute(locations(2), into: 5)
        XCTAssertEqual(days.count, 5)
        XCTAssertEqual(days.map(\.count), [1, 1, 0, 0, 0])
    }

    func testDistributeRejectsZeroDays() {
        XCTAssertTrue(PlanLibrary.distribute(locations(3), into: 0).isEmpty)
    }

    func testDistributePreservesOrder() {
        let items = locations(7)
        let flat = PlanLibrary.distribute(items, into: 3).flatMap { $0 }
        XCTAssertEqual(flat.map(\.chapter), items.map(\.chapter))
    }

    func testBibleInAYearCoversEveryChapter() {
        let def = PlanLibrary.definitions.first { $0.id == "bible-year" }!
        let chapters = PlanLibrary.chapters(for: def, books: DemoBooks.all)
        XCTAssertEqual(chapters.count, 1189)
    }

    func testEveryDefinitionProducesItsDayCount() {
        for def in PlanLibrary.definitions {
            let plan = PlanLibrary.plan(for: def, books: DemoBooks.all)
            XCTAssertEqual(plan.days.count, def.days, def.id)
            XCTAssertEqual(plan.days.first?.day, 1)
        }
    }

    func testLabelCollapsesConsecutiveChapters() {
        let books = DemoBooks.all
        let readings = [
            Location(book: 19, chapter: 23, verse: nil),
            Location(book: 19, chapter: 24, verse: nil)
        ]
        XCTAssertEqual(PlanLibrary.label(for: readings, books: books), "Psalms 23–24")
    }

    func testLabelHandlesEmptyDay() {
        XCTAssertEqual(PlanLibrary.label(for: [], books: DemoBooks.all), "—")
    }
}
