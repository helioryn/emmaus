import Foundation

enum PlanLibrary {
    struct Definition {
        var id: String
        var name: String
        var subtitle: String
        var days: Int
        var bookRange: ClosedRange<Int>
    }

    static let definitions: [Definition] = [
        Definition(id: "bible-year", name: "The Bible in a Year", subtitle: "Every chapter, Old and New Testaments", days: 365, bookRange: 1...66),
        Definition(id: "nt-90", name: "New Testament in 90 Days", subtitle: "Matthew through Revelation", days: 90, bookRange: 40...66),
        Definition(id: "gospels-60", name: "The Gospels in 60 Days", subtitle: "Walk with Jesus through all four accounts", days: 60, bookRange: 40...43),
        Definition(id: "psalms-proverbs-31", name: "Psalms & Proverbs in 31 Days", subtitle: "A month of wisdom and prayer", days: 31, bookRange: 19...20),
        Definition(id: "paul-30", name: "Paul in 30 Days", subtitle: "Romans through Philemon", days: 30, bookRange: 45...57),
        Definition(id: "wisdom-30", name: "Wisdom Literature in 30 Days", subtitle: "Job, Psalms, Proverbs, Ecclesiastes, Song", days: 30, bookRange: 18...22),
    ]

    static func chapters(for def: Definition, books: [Book]) -> [Location] {
        var out: [Location] = []
        for b in books where def.bookRange.contains(b.id) {
            for c in 1...max(1, b.chapters) {
                out.append(Location(book: b.id, chapter: c, verse: nil))
            }
        }
        return out
    }

    static func plan(for def: Definition, books: [Book]) -> ReadingPlan {
        let chapters = chapters(for: def, books: books)
        let days = distribute(chapters, into: def.days)
        var planDays: [PlanDay] = []
        for (i, chunk) in days.enumerated() {
            planDays.append(PlanDay(plan: def.id, day: i + 1, readings: chunk, label: label(for: chunk, books: books)))
        }
        return ReadingPlan(id: def.id, name: def.name, subtitle: def.subtitle, days: planDays)
    }

    static func distribute(_ items: [Location], into dayCount: Int) -> [[Location]] {
        guard dayCount > 0 else { return [] }
        let base = items.count / dayCount
        let extra = items.count % dayCount
        var result: [[Location]] = []
        var idx = 0
        for d in 0..<dayCount {
            let n = base + (d < extra ? 1 : 0)
            let end = min(items.count, idx + n)
            result.append(Array(items[idx..<end]))
            idx = end
        }
        // Fill empty days at the end (short plans) with no readings.
        while result.count < dayCount { result.append([]) }
        return result
    }

    static func label(for readings: [Location], books: [Book]) -> String {
        guard !readings.isEmpty else { return "—" }
        var parts: [String] = []
        var i = 0
        while i < readings.count {
            let start = readings[i]
            var j = i
            while j + 1 < readings.count,
                  readings[j + 1].book == start.book,
                  readings[j + 1].chapter == readings[j].chapter + 1 {
                j += 1
            }
            let book = books.first(where: { $0.id == start.book })?.name ?? ""
            if j > i {
                parts.append("\(book) \(start.chapter)–\(readings[j].chapter)")
            } else {
                parts.append("\(book) \(start.chapter)")
            }
            i = j + 1
        }
        return parts.joined(separator: " · ")
    }
}
