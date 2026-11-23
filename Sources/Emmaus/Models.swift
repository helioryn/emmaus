import Foundation

// MARK: - Core records

struct Translation: Identifiable, Hashable {
    var code: String
    var name: String
    var short: String
    var language: String
    var langCode: String
    var year: String
    var license: String
    var attribution: String
    var hasStrongs: Bool
    var hasRed: Bool
    var hasInterlinear: Bool
    var source: String
    var bibleId: String
    var sort: Int
    var direction: String

    var id: String { code }
    var isRemote: Bool { source == "api" }
    var isRTL: Bool { direction == "rtl" }
}

struct Book: Identifiable, Hashable {
    var id: Int
    var name: String
    var short: String
    var osis: String
    var testament: String
    var genre: String
    var chapters: Int
    var sort: Int
    var aliases: [String] = []

    var isOT: Bool { testament == "OT" }
    var displayTestament: String { testament == "OT" ? "Old Testament" : "New Testament" }
}

struct Token: Codable, Hashable {
    var t: String
    var s: [String]?
    var m: [String]?
    var r: Int?
    var i: Int?
    var h: Int?

    var isRed: Bool { r == 1 }
    var isItalic: Bool { i == 1 }
    var isHeading: Bool { h == 1 }
    var strongs: [String] { s ?? [] }
    var morph: [String] { m ?? [] }
}

struct Verse: Identifiable, Hashable {
    var number: Int
    var text: String
    var tokens: [Token]?
    var hasRed: Bool

    var id: Int { number }
}

struct ChapterData {
    var translation: String
    var book: Int
    var chapter: Int
    var verses: [Verse]
}

struct Location: Hashable, Codable {
    var book: Int
    var chapter: Int
    var verse: Int?
}

struct CrossRef: Identifiable {
    var fromBook: Int
    var fromChapter: Int
    var fromVerse: Int
    var toBook: Int
    var toChapter: Int
    var toVerseStart: Int
    var toVerseEnd: Int
    var votes: Int
    var preview: String

    var id: String { "\(toBook)-\(toChapter)-\(toVerseStart)-\(toVerseEnd)" }
}

struct StrongsEntry: Identifiable, Hashable {
    var id: String
    var lang: String
    var lemma: String
    var translit: String
    var pronounce: String
    var derivation: String
    var definition: String
    var kjvUsage: String
    var gloss: String
    var morph: String
    var parent: String
    var source: String
    var extended: String

    var isHebrew: Bool { id.hasPrefix("H") }
    var languageCode: String { isHebrew ? "he" : "grc" }
    var languageName: String { isHebrew ? "Hebrew" : "Greek" }
}

struct InterlinearWord: Identifiable, Hashable {
    var book: Int
    var chapter: Int
    var verse: Int
    var seq: Int
    var lang: String
    var text: String
    var translit: String
    var gloss: String
    var strongs: String
    var morph: String

    var id: Int { seq }
    var isHebrew: Bool { lang == "he" }
}

struct DictionaryEntry: Identifiable, Hashable {
    var id: Int
    var source: String
    var headword: String
    var body: String
}

struct Topic: Identifiable, Hashable {
    var id: Int
    var section: String
    var subject: String
    var entry: String
}

struct CommentaryEntry: Identifiable, Hashable {
    var id: String
    var work: String
    var book: Int
    var chapter: Int
    var verseStart: Int
    var verseEnd: Int
    var body: String
}

struct SearchHit: Identifiable {
    var translation: String
    var book: Int
    var chapter: Int
    var verse: Int
    var text: String
    var snippet: String
    var score: Double

    var id: String { "\(translation)-\(book)-\(chapter)-\(verse)" }
}

struct Occurrence: Identifiable, Hashable {
    var strongs: String
    var book: Int
    var chapter: Int
    var verse: Int
    var form: String
    var morph: String

    var id: String { "\(book)-\(chapter)-\(verse)-\(form)" }
}

struct VerseKey: Hashable {
    var book: Int
    var chapter: Int
    var verse: Int
}

struct Note: Identifiable, Hashable {
    var id: Int
    var book: Int
    var chapter: Int
    var verse: Int
    var body: String
    var updated: Date
}

struct PlanDay: Identifiable, Hashable {
    var plan: String
    var day: Int
    var readings: [Location]
    var label: String

    var id: Int { day }
}

struct ReadingPlan: Identifiable, Hashable {
    var id: String
    var name: String
    var subtitle: String
    var days: [PlanDay]
}

// MARK: - Reference parsing

enum ReferenceParser {
    private static let alias: [String: Int] = {
        var map: [String: Int] = [:]
        for b in DemoBooks.all {
            map[b.name.lowercased()] = b.id
            map[b.short.lowercased().replacingOccurrences(of: ".", with: "")] = b.id
            map[b.osis.lowercased()] = b.id
            for a in b.aliases { map[a.lowercased()] = b.id }
        }
        return map
    }()

    static func parse(_ input: String) -> (book: Int, chapter: Int, verse: Int?)? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        s = s.replacingOccurrences(of: "  ", with: " ")
        let pattern = #"^([1-3]?\s*[a-z][a-z ]*?)\s*(\d+)(?:\s*[:.]\s*(\d+))?"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        func group(_ i: Int) -> String? {
            guard let r = Range(m.range(at: i), in: s) else { return nil }
            return String(s[r]).trimmingCharacters(in: .whitespaces)
        }
        guard let rawBook = group(1)?.trimmingCharacters(in: .whitespaces),
              let chStr = group(2), let chapter = Int(chStr) else { return nil }
        var name = rawBook
        // numeric prefix without space: "1john"
        if let first = name.first, "123".contains(first), !name.contains(" ") {
            name = String(first) + " " + name.dropFirst()
        }
        guard let book = alias[name] ?? alias[name.replacingOccurrences(of: " ", with: "")] else { return nil }
        let verse = group(3).flatMap(Int.init)
        return (book, chapter, verse)
    }

    static func label(book: Int, chapter: Int, verse: Int? = nil) -> String {
        guard let b = DemoBooks.book(book) else { return "\(book):\(chapter)" }
        if let v = verse { return "\(b.name) \(chapter):\(v)" }
        return "\(b.name) \(chapter)"
    }
}

// Fallback metadata used for reference parsing before the DB loads.
enum DemoBooks {
    static let all: [Book] = [
        Book(id: 1, name: "Genesis", short: "Gen", osis: "Gen", testament: "OT", genre: "Law", chapters: 50, sort: 1, aliases: ["ge","gn"]),
        Book(id: 2, name: "Exodus", short: "Exod", osis: "Exod", testament: "OT", genre: "Law", chapters: 40, sort: 2, aliases: ["ex","exo"]),
        Book(id: 3, name: "Leviticus", short: "Lev", osis: "Lev", testament: "OT", genre: "Law", chapters: 27, sort: 3, aliases: ["le","lv"]),
        Book(id: 4, name: "Numbers", short: "Num", osis: "Num", testament: "OT", genre: "Law", chapters: 36, sort: 4, aliases: ["nu","nm","nb"]),
        Book(id: 5, name: "Deuteronomy", short: "Deut", osis: "Deut", testament: "OT", genre: "Law", chapters: 34, sort: 5, aliases: ["dt","de"]),
        Book(id: 6, name: "Joshua", short: "Josh", osis: "Josh", testament: "OT", genre: "History", chapters: 24, sort: 6, aliases: ["jos"]),
        Book(id: 7, name: "Judges", short: "Judg", osis: "Judg", testament: "OT", genre: "History", chapters: 21, sort: 7, aliases: ["jdg","jg"]),
        Book(id: 8, name: "Ruth", short: "Ruth", osis: "Ruth", testament: "OT", genre: "History", chapters: 4, sort: 8, aliases: ["ru","rth"]),
        Book(id: 9, name: "1 Samuel", short: "1 Sam", osis: "1Sam", testament: "OT", genre: "History", chapters: 31, sort: 9, aliases: ["1sa","1sam"]),
        Book(id: 10, name: "2 Samuel", short: "2 Sam", osis: "2Sam", testament: "OT", genre: "History", chapters: 24, sort: 10, aliases: ["2sa","2sam"]),
        Book(id: 11, name: "1 Kings", short: "1 Kgs", osis: "1Kgs", testament: "OT", genre: "History", chapters: 22, sort: 11, aliases: ["1ki","1kgs"]),
        Book(id: 12, name: "2 Kings", short: "2 Kgs", osis: "2Kgs", testament: "OT", genre: "History", chapters: 25, sort: 12, aliases: ["2ki","2kgs"]),
        Book(id: 13, name: "1 Chronicles", short: "1 Chr", osis: "1Chr", testament: "OT", genre: "History", chapters: 29, sort: 13, aliases: ["1ch","1chr"]),
        Book(id: 14, name: "2 Chronicles", short: "2 Chr", osis: "2Chr", testament: "OT", genre: "History", chapters: 36, sort: 14, aliases: ["2ch","2chr"]),
        Book(id: 15, name: "Ezra", short: "Ezra", osis: "Ezra", testament: "OT", genre: "History", chapters: 10, sort: 15, aliases: ["ezr"]),
        Book(id: 16, name: "Nehemiah", short: "Neh", osis: "Neh", testament: "OT", genre: "History", chapters: 13, sort: 16, aliases: ["ne"]),
        Book(id: 17, name: "Esther", short: "Esth", osis: "Esth", testament: "OT", genre: "History", chapters: 10, sort: 17, aliases: ["est"]),
        Book(id: 18, name: "Job", short: "Job", osis: "Job", testament: "OT", genre: "Wisdom", chapters: 42, sort: 18, aliases: ["jb"]),
        Book(id: 19, name: "Psalms", short: "Ps", osis: "Ps", testament: "OT", genre: "Wisdom", chapters: 150, sort: 19, aliases: ["psa","pss","psalm"]),
        Book(id: 20, name: "Proverbs", short: "Prov", osis: "Prov", testament: "OT", genre: "Wisdom", chapters: 31, sort: 20, aliases: ["pr","pro"]),
        Book(id: 21, name: "Ecclesiastes", short: "Eccl", osis: "Eccl", testament: "OT", genre: "Wisdom", chapters: 12, sort: 21, aliases: ["ec","ecc"]),
        Book(id: 22, name: "Song of Solomon", short: "Song", osis: "Song", testament: "OT", genre: "Wisdom", chapters: 8, sort: 22, aliases: ["song","sos","sng"]),
        Book(id: 23, name: "Isaiah", short: "Isa", osis: "Isa", testament: "OT", genre: "Major Prophets", chapters: 66, sort: 23, aliases: ["is"]),
        Book(id: 24, name: "Jeremiah", short: "Jer", osis: "Jer", testament: "OT", genre: "Major Prophets", chapters: 52, sort: 24, aliases: ["je"]),
        Book(id: 25, name: "Lamentations", short: "Lam", osis: "Lam", testament: "OT", genre: "Major Prophets", chapters: 5, sort: 25, aliases: ["la"]),
        Book(id: 26, name: "Ezekiel", short: "Ezek", osis: "Ezek", testament: "OT", genre: "Major Prophets", chapters: 48, sort: 26, aliases: ["eze","ezk"]),
        Book(id: 27, name: "Daniel", short: "Dan", osis: "Dan", testament: "OT", genre: "Major Prophets", chapters: 12, sort: 27, aliases: ["da","dn"]),
        Book(id: 28, name: "Hosea", short: "Hos", osis: "Hos", testament: "OT", genre: "Minor Prophets", chapters: 14, sort: 28, aliases: ["ho"]),
        Book(id: 29, name: "Joel", short: "Joel", osis: "Joel", testament: "OT", genre: "Minor Prophets", chapters: 3, sort: 29, aliases: ["joe","jl"]),
        Book(id: 30, name: "Amos", short: "Amos", osis: "Amos", testament: "OT", genre: "Minor Prophets", chapters: 9, sort: 30, aliases: ["am"]),
        Book(id: 31, name: "Obadiah", short: "Obad", osis: "Obad", testament: "OT", genre: "Minor Prophets", chapters: 1, sort: 31, aliases: ["ob"]),
        Book(id: 32, name: "Jonah", short: "Jonah", osis: "Jonah", testament: "OT", genre: "Minor Prophets", chapters: 4, sort: 32, aliases: ["jon"]),
        Book(id: 33, name: "Micah", short: "Mic", osis: "Mic", testament: "OT", genre: "Minor Prophets", chapters: 7, sort: 33, aliases: ["mic"]),
        Book(id: 34, name: "Nahum", short: "Nah", osis: "Nah", testament: "OT", genre: "Minor Prophets", chapters: 3, sort: 34, aliases: ["na"]),
        Book(id: 35, name: "Habakkuk", short: "Hab", osis: "Hab", testament: "OT", genre: "Minor Prophets", chapters: 3, sort: 35, aliases: ["hab"]),
        Book(id: 36, name: "Zephaniah", short: "Zeph", osis: "Zeph", testament: "OT", genre: "Minor Prophets", chapters: 3, sort: 36, aliases: ["zep"]),
        Book(id: 37, name: "Haggai", short: "Hag", osis: "Hag", testament: "OT", genre: "Minor Prophets", chapters: 2, sort: 37, aliases: ["hag"]),
        Book(id: 38, name: "Zechariah", short: "Zech", osis: "Zech", testament: "OT", genre: "Minor Prophets", chapters: 14, sort: 38, aliases: ["zec"]),
        Book(id: 39, name: "Malachi", short: "Mal", osis: "Mal", testament: "OT", genre: "Minor Prophets", chapters: 4, sort: 39, aliases: ["mal"]),
        Book(id: 40, name: "Matthew", short: "Matt", osis: "Matt", testament: "NT", genre: "Gospels", chapters: 28, sort: 40, aliases: ["mt","mat"]),
        Book(id: 41, name: "Mark", short: "Mark", osis: "Mark", testament: "NT", genre: "Gospels", chapters: 16, sort: 41, aliases: ["mk","mr"]),
        Book(id: 42, name: "Luke", short: "Luke", osis: "Luke", testament: "NT", genre: "Gospels", chapters: 24, sort: 42, aliases: ["lk","luk"]),
        Book(id: 43, name: "John", short: "John", osis: "John", testament: "NT", genre: "Gospels", chapters: 21, sort: 43, aliases: ["jn","jhn"]),
        Book(id: 44, name: "Acts", short: "Acts", osis: "Acts", testament: "NT", genre: "History", chapters: 28, sort: 44, aliases: ["ac"]),
        Book(id: 45, name: "Romans", short: "Rom", osis: "Rom", testament: "NT", genre: "Pauline Epistles", chapters: 16, sort: 45, aliases: ["ro","rm"]),
        Book(id: 46, name: "1 Corinthians", short: "1 Cor", osis: "1Cor", testament: "NT", genre: "Pauline Epistles", chapters: 16, sort: 46, aliases: ["1co","1cor"]),
        Book(id: 47, name: "2 Corinthians", short: "2 Cor", osis: "2Cor", testament: "NT", genre: "Pauline Epistles", chapters: 13, sort: 47, aliases: ["2co","2cor"]),
        Book(id: 48, name: "Galatians", short: "Gal", osis: "Gal", testament: "NT", genre: "Pauline Epistles", chapters: 6, sort: 48, aliases: ["ga"]),
        Book(id: 49, name: "Ephesians", short: "Eph", osis: "Eph", testament: "NT", genre: "Pauline Epistles", chapters: 6, sort: 49, aliases: ["ep"]),
        Book(id: 50, name: "Philippians", short: "Phil", osis: "Phil", testament: "NT", genre: "Pauline Epistles", chapters: 4, sort: 50, aliases: ["php"]),
        Book(id: 51, name: "Colossians", short: "Col", osis: "Col", testament: "NT", genre: "Pauline Epistles", chapters: 4, sort: 51, aliases: ["col"]),
        Book(id: 52, name: "1 Thessalonians", short: "1 Thess", osis: "1Thess", testament: "NT", genre: "Pauline Epistles", chapters: 5, sort: 52, aliases: ["1th","1thess"]),
        Book(id: 53, name: "2 Thessalonians", short: "2 Thess", osis: "2Thess", testament: "NT", genre: "Pauline Epistles", chapters: 3, sort: 53, aliases: ["2th","2thess"]),
        Book(id: 54, name: "1 Timothy", short: "1 Tim", osis: "1Tim", testament: "NT", genre: "Pauline Epistles", chapters: 6, sort: 54, aliases: ["1ti","1tim"]),
        Book(id: 55, name: "2 Timothy", short: "2 Tim", osis: "2Tim", testament: "NT", genre: "Pauline Epistles", chapters: 4, sort: 55, aliases: ["2ti","2tim"]),
        Book(id: 56, name: "Titus", short: "Titus", osis: "Titus", testament: "NT", genre: "Pauline Epistles", chapters: 3, sort: 56, aliases: ["tit"]),
        Book(id: 57, name: "Philemon", short: "Phlm", osis: "Phlm", testament: "NT", genre: "Pauline Epistles", chapters: 1, sort: 57, aliases: ["phm"]),
        Book(id: 58, name: "Hebrews", short: "Heb", osis: "Heb", testament: "NT", genre: "General Epistles", chapters: 13, sort: 58, aliases: ["heb"]),
        Book(id: 59, name: "James", short: "Jas", osis: "Jas", testament: "NT", genre: "General Epistles", chapters: 5, sort: 59, aliases: ["jas","jam"]),
        Book(id: 60, name: "1 Peter", short: "1 Pet", osis: "1Pet", testament: "NT", genre: "General Epistles", chapters: 5, sort: 60, aliases: ["1pe","1pet"]),
        Book(id: 61, name: "2 Peter", short: "2 Pet", osis: "2Pet", testament: "NT", genre: "General Epistles", chapters: 3, sort: 61, aliases: ["2pe","2pet"]),
        Book(id: 62, name: "1 John", short: "1 John", osis: "1John", testament: "NT", genre: "General Epistles", chapters: 5, sort: 62, aliases: ["1jn","1jo"]),
        Book(id: 63, name: "2 John", short: "2 John", osis: "2John", testament: "NT", genre: "General Epistles", chapters: 1, sort: 63, aliases: ["2jn","2jo"]),
        Book(id: 64, name: "3 John", short: "3 John", osis: "3John", testament: "NT", genre: "General Epistles", chapters: 1, sort: 64, aliases: ["3jn","3jo"]),
        Book(id: 65, name: "Jude", short: "Jude", osis: "Jude", testament: "NT", genre: "General Epistles", chapters: 1, sort: 65, aliases: ["jud"]),
        Book(id: 66, name: "Revelation", short: "Rev", osis: "Rev", testament: "NT", genre: "Apocalyptic", chapters: 22, sort: 66, aliases: ["rev","re"]),
    ]
    static func book(_ id: Int) -> Book? { all.first { $0.id == id } }
}
