import Foundation

final class BibleStore {
    let db: Database
    private(set) var translations: [Translation] = []
    private(set) var books: [Book] = []
    private(set) var bookById: [Int: Book] = [:]

    init(db: Database) {
        self.db = db
        loadMetadata()
    }

    private func loadMetadata() {
        translations = db.rows("SELECT * FROM translations ORDER BY sort").compactMap { r in
            guard let code = r["code"] as? String else { return nil }
            return Translation(
                code: code,
                name: r["name"] as? String ?? code,
                short: r["short"] as? String ?? code,
                language: r["language"] as? String ?? "",
                langCode: r["lang_code"] as? String ?? "en",
                year: r["year"] as? String ?? "",
                license: r["license"] as? String ?? "",
                attribution: r["attribution"] as? String ?? "",
                hasStrongs: (r["has_strongs"] as? Int ?? 0) == 1,
                hasRed: (r["has_red"] as? Int ?? 0) == 1,
                hasInterlinear: (r["has_interlinear"] as? Int ?? 0) == 1,
                source: r["source"] as? String ?? "local",
                bibleId: r["bible_id"] as? String ?? "",
                sort: r["sort"] as? Int ?? 0,
                direction: r["direction"] as? String ?? "ltr"
            )
        }
        books = db.rows("SELECT * FROM books ORDER BY sort").compactMap { r in
            guard let id = r["id"] as? Int else { return nil }
            return Book(
                id: id,
                name: r["name"] as? String ?? "",
                short: r["short"] as? String ?? "",
                osis: r["osis"] as? String ?? "",
                testament: r["testament"] as? String ?? "OT",
                genre: r["genre"] as? String ?? "",
                chapters: r["chapters"] as? Int ?? 0,
                sort: r["sort"] as? Int ?? id,
                aliases: DemoBooks.book(id)?.aliases ?? []
            )
        }
        bookById = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
    }

    func translation(_ code: String) -> Translation? {
        translations.first { $0.code == code }
    }

    func book(_ id: Int) -> Book? { bookById[id] }

    func book(named name: String) -> Book? {
        books.first { $0.name.lowercased() == name.lowercased() || $0.osis.lowercased() == name.lowercased() }
    }

    // MARK: - Reading

    func chapter(translation: String, book: Int, chapter: Int) -> ChapterData? {
        let rows = db.rows(
            "SELECT verse, text, tokens, has_red FROM verses WHERE translation=? AND book=? AND chapter=? ORDER BY verse",
            [translation, book, chapter]
        )
        guard !rows.isEmpty else { return nil }
        let verses: [Verse] = rows.compactMap { r in
            guard let v = r["verse"] as? Int else { return nil }
            var tokens: [Token]? = nil
            if let raw = r["tokens"] as? String, let data = raw.data(using: .utf8) {
                tokens = try? JSONDecoder().decode([Token].self, from: data)
            }
            return Verse(
                number: v,
                text: r["text"] as? String ?? "",
                tokens: tokens,
                hasRed: (r["has_red"] as? Int ?? 0) == 1
            )
        }
        return ChapterData(translation: translation, book: book, chapter: chapter, verses: verses)
    }

    func verse(translation: String, book: Int, chapter: Int, verse: Int) -> Verse? {
        let rows = db.rows(
            "SELECT verse, text, tokens, has_red FROM verses WHERE translation=? AND book=? AND chapter=? AND verse=?",
            [translation, book, chapter, verse]
        )
        guard let r = rows.first else { return nil }
        var tokens: [Token]? = nil
        if let raw = r["tokens"] as? String, let data = raw.data(using: .utf8) {
            tokens = try? JSONDecoder().decode([Token].self, from: data)
        }
        return Verse(
            number: r["verse"] as? Int ?? verse,
            text: r["text"] as? String ?? "",
            tokens: tokens,
            hasRed: (r["has_red"] as? Int ?? 0) == 1
        )
    }

    func chapterCount(translation: String, book: Int) -> Int {
        db.scalarInt("SELECT COUNT(*) FROM verses WHERE translation=? AND book=?", [translation, book])
    }

    func displayVerseText(translation: String, book: Int, chapter: Int, verse: Int) -> String? {
        guard let v = self.verse(translation: translation, book: book, chapter: chapter, verse: verse) else { return nil }
        if let tokens = v.tokens {
            let body = tokens.filter { $0.h != 1 }.map { $0.t }.joined()
            let t = body.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return v.text
    }

    func verseText(translation: String, book: Int, chapter: Int, verse: Int) -> String? {
        db.scalarString(
            "SELECT text FROM verses WHERE translation=? AND book=? AND chapter=? AND verse=?",
            [translation, book, chapter, verse]
        )
    }

    // MARK: - Strong's

    private func strongsFromRow(_ r: [String: Any]) -> StrongsEntry {
        StrongsEntry(
            id: r["id"] as? String ?? "",
            lang: r["lang"] as? String ?? "",
            lemma: r["lemma"] as? String ?? "",
            translit: r["translit"] as? String ?? "",
            pronounce: r["pronounce"] as? String ?? "",
            derivation: r["derivation"] as? String ?? "",
            definition: r["definition"] as? String ?? "",
            kjvUsage: r["kjv_usage"] as? String ?? "",
            gloss: r["gloss"] as? String ?? "",
            morph: r["morph"] as? String ?? "",
            parent: r["parent"] as? String ?? "",
            source: r["source"] as? String ?? "",
            extended: r["extended"] as? String ?? ""
        )
    }

    func strongs(id raw: String) -> StrongsEntry? {
        var id = raw.uppercased().trimmingCharacters(in: .whitespaces)
        if let m = id.range(of: #"[HG]0+\d+[A-Z]?"#, options: .regularExpression) {
            let s = String(id[m])
            let prefix = s.prefix(1)
            let digits = s.dropFirst().prefix { $0.isNumber }
            let suffix = s.dropFirst().drop { $0.isNumber }
            id = "\(prefix)\(Int(digits) ?? 0)\(suffix)"
        }
        if let r = db.rows("SELECT * FROM strongs WHERE id=?", [id]).first {
            return strongsFromRow(r)
        }
        let base = id.replacingOccurrences(of: #"[A-Z]$"#, with: "", options: .regularExpression)
        if let r = db.rows("SELECT * FROM strongs WHERE id=?", [base]).first {
            return strongsFromRow(r)
        }
        if let r = db.rows("SELECT * FROM strongs WHERE id LIKE ? ORDER BY LENGTH(id) LIMIT 1", [base + "%"]).first {
            return strongsFromRow(r)
        }
        return nil
    }

    func strongsFamily(id raw: String) -> [StrongsEntry] {
        let base = raw.uppercased().replacingOccurrences(of: #"(?<=[HG]\d{1,5})[A-Z]$"#, with: "", options: .regularExpression)
        let rows = db.rows("SELECT * FROM strongs WHERE id=? OR parent=? ORDER BY id", [base, base])
        return rows.map(strongsFromRow)
    }

    func searchStrongs(_ query: String, limit: Int = 60) -> [StrongsEntry] {
        let q = "%\(query)%"
        let rows = db.rows(
            "SELECT * FROM strongs WHERE id LIKE ? OR lemma LIKE ? OR translit LIKE ? OR gloss LIKE ? OR definition LIKE ? ORDER BY id LIMIT ?",
            [q, q, q, q, q, limit]
        )
        return rows.map(strongsFromRow)
    }

    func occurrences(strongs: String, limit: Int = 500) -> [Occurrence] {
        let rows = db.rows(
            "SELECT strongs,book,chapter,verse,form,morph FROM occurrences WHERE strongs=? ORDER BY book,chapter,verse LIMIT ?",
            [strongs, limit]
        )
        return rows.map {
            Occurrence(
                strongs: $0["strongs"] as? String ?? strongs,
                book: $0["book"] as? Int ?? 0,
                chapter: $0["chapter"] as? Int ?? 0,
                verse: $0["verse"] as? Int ?? 0,
                form: $0["form"] as? String ?? "",
                morph: $0["morph"] as? String ?? ""
            )
        }
    }

    func occurrenceCount(strongs: String) -> Int {
        db.scalarInt("SELECT COUNT(*) FROM occurrences WHERE strongs=?", [strongs])
    }

    func morphExpansion(_ code: String) -> String? {
        guard !code.isEmpty else { return nil }
        if let s = db.scalarString("SELECT expansion FROM morph WHERE codes=?", [code]) { return s }
        let stripped = code.replacingOccurrences(of: "TH", with: "H")
        if let s = db.scalarString("SELECT expansion FROM morph WHERE codes=?", [stripped]) { return s }
        return nil
    }

    // MARK: - Interlinear

    func interlinear(book: Int, chapter: Int, verse: Int) -> [InterlinearWord] {
        let rows = db.rows(
            "SELECT book,chapter,verse,seq,lang,text,translit,gloss,strongs,morph FROM interlinear WHERE book=? AND chapter=? AND verse=? ORDER BY seq",
            [book, chapter, verse]
        )
        return rows.map {
            InterlinearWord(
                book: $0["book"] as? Int ?? book,
                chapter: $0["chapter"] as? Int ?? chapter,
                verse: $0["verse"] as? Int ?? verse,
                seq: $0["seq"] as? Int ?? 0,
                lang: $0["lang"] as? String ?? "",
                text: $0["text"] as? String ?? "",
                translit: $0["translit"] as? String ?? "",
                gloss: $0["gloss"] as? String ?? "",
                strongs: $0["strongs"] as? String ?? "",
                morph: $0["morph"] as? String ?? ""
            )
        }
    }

    func hasInterlinear(book: Int, chapter: Int, verse: Int) -> Bool {
        db.scalarInt("SELECT COUNT(*) FROM interlinear WHERE book=? AND chapter=? AND verse=?", [book, chapter, verse]) > 0
    }

    // MARK: - Cross references

    func crossReferences(book: Int, chapter: Int, verse: Int, limit: Int = 40) -> [CrossRef] {
        let rows = db.rows(
            """
            SELECT cr.*, COALESCE(v.text, '') AS preview
            FROM cross_refs cr
            LEFT JOIN verses v ON v.translation='KJV' AND v.book=cr.to_book
                 AND v.chapter=cr.to_chapter AND v.verse=cr.to_verse_start
            WHERE cr.from_book=? AND cr.from_chapter=? AND cr.from_verse=?
            ORDER BY cr.votes DESC LIMIT ?
            """,
            [book, chapter, verse, limit]
        )
        return rows.map {
            CrossRef(
                fromBook: $0["from_book"] as? Int ?? book,
                fromChapter: $0["from_chapter"] as? Int ?? chapter,
                fromVerse: $0["from_verse"] as? Int ?? verse,
                toBook: $0["to_book"] as? Int ?? 0,
                toChapter: $0["to_chapter"] as? Int ?? 0,
                toVerseStart: $0["to_verse_start"] as? Int ?? 0,
                toVerseEnd: $0["to_verse_end"] as? Int ?? 0,
                votes: $0["votes"] as? Int ?? 0,
                preview: $0["preview"] as? String ?? ""
            )
        }
    }

    // MARK: - Commentary

    static let commentaryNames: [String: String] = [
        "matthew-henry": "Matthew Henry",
        "jamieson-fausset-brown": "Jamieson–Fausset–Brown",
        "tyndale": "Tyndale Open Study Notes",
        "geneva": "Geneva Bible Notes",
        "scofield": "Scofield Reference Notes",
    ]

    func commentary(book: Int, chapter: Int, verse: Int) -> [CommentaryEntry] {
        let rows = db.rows(
            """
            SELECT work,book,chapter,verse_start,verse_end,body FROM commentaries
            WHERE book=? AND chapter=? AND verse_start<=? AND verse_end>=?
            ORDER BY work, verse_start
            """,
            [book, chapter, verse, verse]
        )
        return rows.map {
            let work = $0["work"] as? String ?? ""
            return CommentaryEntry(
                id: "\(work)-\(book)-\(chapter)-\($0["verse_start"] as? Int ?? 0)-\($0["verse_end"] as? Int ?? 0)",
                work: work,
                book: book,
                chapter: chapter,
                verseStart: $0["verse_start"] as? Int ?? 0,
                verseEnd: $0["verse_end"] as? Int ?? 0,
                body: $0["body"] as? String ?? ""
            )
        }
    }

    func commentaryWorks() -> [String] {
        let rows = db.rows("SELECT DISTINCT work FROM commentaries ORDER BY work")
        return rows.compactMap { $0["work"] as? String }
    }

    // MARK: - Dictionary

    func dictionarySearch(_ query: String, source: String? = nil, limit: Int = 80) -> [DictionaryEntry] {
        let q = "%\(query)%"
        var sql = "SELECT * FROM dictionary WHERE (headword LIKE ? OR body LIKE ?)"
        var params: [Any?] = [q, q]
        if let source, !source.isEmpty {
            sql += " AND source=?"
            params.append(source)
        }
        sql += " ORDER BY CASE WHEN headword LIKE ? THEN 0 ELSE 1 END, LENGTH(headword), headword LIMIT ?"
        params.append(query + "%")
        params.append(limit)
        return db.rows(sql, params).map {
            DictionaryEntry(
                id: $0["id"] as? Int ?? 0,
                source: $0["source"] as? String ?? "",
                headword: $0["headword"] as? String ?? "",
                body: $0["body"] as? String ?? ""
            )
        }
    }

    func dictionary(source: String? = nil, letter: String? = nil, limit: Int = 400) -> [DictionaryEntry] {
        var sql = "SELECT * FROM dictionary WHERE 1=1"
        var params: [Any?] = []
        if let source, !source.isEmpty { sql += " AND source=?"; params.append(source) }
        if let letter, !letter.isEmpty { sql += " AND headword LIKE ?"; params.append(letter + "%") }
        sql += " ORDER BY headword LIMIT ?"
        params.append(limit)
        return db.rows(sql, params).map {
            DictionaryEntry(
                id: $0["id"] as? Int ?? 0,
                source: $0["source"] as? String ?? "",
                headword: $0["headword"] as? String ?? "",
                body: $0["body"] as? String ?? ""
            )
        }
    }

    func dictionarySources() -> [String] {
        db.rows("SELECT DISTINCT source FROM dictionary ORDER BY source").compactMap { $0["source"] as? String }
    }

    // MARK: - Topics

    func topicSections() -> [String] {
        db.rows("SELECT DISTINCT section FROM topics ORDER BY section").compactMap { $0["section"] as? String }
    }

    func topics(section: String, limit: Int = 600) -> [Topic] {
        db.rows("SELECT * FROM topics WHERE section=? ORDER BY subject LIMIT ?", [section, limit]).map {
            Topic(
                id: $0["id"] as? Int ?? 0,
                section: $0["section"] as? String ?? "",
                subject: $0["subject"] as? String ?? "",
                entry: $0["entry"] as? String ?? ""
            )
        }
    }

    func topicSearch(_ query: String, limit: Int = 100) -> [Topic] {
        let q = "%\(query)%"
        return db.rows(
            "SELECT * FROM topics WHERE subject LIKE ? OR entry LIKE ? ORDER BY subject LIMIT ?",
            [q, q, limit]
        ).map {
            Topic(
                id: $0["id"] as? Int ?? 0,
                section: $0["section"] as? String ?? "",
                subject: $0["subject"] as? String ?? "",
                entry: $0["entry"] as? String ?? ""
            )
        }
    }

    // MARK: - Search

    /// Which translations live in the FTS index, discovered once each.
    private var indexedTranslations: [String: Bool] = [:]
    /// Guards `indexedTranslations`; searches can arrive from a background task.
    private let indexLock = NSLock()

    func search(_ raw: String, translation: String, scope: SearchScope = .all, limit: Int = 200) -> [SearchHit] {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        if isIndexed(translation) {
            let hits = fullTextSearch(query, translation: translation, scope: scope)
            if !hits.isEmpty { return Array(hits.prefix(limit)) }
            return []
        }

        // Translations imported from eBible.org are not tokenised into the FTS
        // index. Scan their verses directly instead of returning nothing.
        return literalSearch(query, translation: translation, scope: scope, limit: limit)
    }

    private func isIndexed(_ translation: String) -> Bool {
        indexLock.lock()
        if let cached = indexedTranslations[translation] {
            indexLock.unlock()
            return cached
        }
        indexLock.unlock()

        let found = !db.rows("SELECT 1 FROM search WHERE translation = ? LIMIT 1", [translation]).isEmpty

        indexLock.lock()
        indexedTranslations[translation] = found
        indexLock.unlock()
        return found
    }

    private func fullTextSearch(_ raw: String, translation: String, scope: SearchScope) -> [SearchHit] {
        let expr = SearchQuery.ftsExpression(raw)
        guard !expr.isEmpty else { return [] }
        var sql = """
            SELECT translation, book, chapter, verse, text,
                   snippet(search, '⟦', '⟧', '…', -1, 14) AS snip,
                   matchinfo(search, 'pcx') AS mi
            FROM search WHERE search MATCH ? AND translation=?
            """
        var params: [Any?] = [expr, translation]
        switch scope {
        case .all: break
        case .oldTestament: sql += " AND book<=39"
        case .newTestament: sql += " AND book>=40"
        case .book(let b): sql += " AND book=?"; params.append(b)
        }
        sql += " LIMIT 400"
        let rows = db.rows(sql, params)
        var hits: [SearchHit] = []
        hits.reserveCapacity(rows.count)
        for r in rows {
            let text = r["text"] as? String ?? ""
            let score = Self.score(matchInfo: r["mi"] as? Data, textLength: text.count)
            hits.append(SearchHit(
                translation: r["translation"] as? String ?? translation,
                book: r["book"] as? Int ?? 1,
                chapter: r["chapter"] as? Int ?? 1,
                verse: r["verse"] as? Int ?? 1,
                text: text,
                snippet: r["snip"] as? String ?? text,
                score: score
            ))
        }
        return hits.sorted {
            if abs($0.score - $1.score) > 0.0001 { return $0.score > $1.score }
            if $0.book != $1.book { return $0.book < $1.book }
            if $0.chapter != $1.chapter { return $0.chapter < $1.chapter }
            return $0.verse < $1.verse
        }
    }

    /// Plain substring search for translations the FTS index does not cover.
    /// The verses table is keyed by translation, so this stays a narrow scan.
    private func literalSearch(_ raw: String, translation: String, scope: SearchScope, limit: Int) -> [SearchHit] {
        var terms = SearchQuery.literalTerms(raw)
        if terms.isEmpty,
           let phrase = SearchQuery.sanitize(raw, allowSpaces: true) {
            terms = [phrase]
        }
        guard !terms.isEmpty else { return [] }

        var sql = "SELECT translation, book, chapter, verse, text FROM verses WHERE translation = ?"
        var params: [Any?] = [translation]
        for term in terms.prefix(8) {
            sql += " AND text LIKE ? ESCAPE '\\'"
            params.append("%\(Self.escapeLike(term))%")
        }
        switch scope {
        case .all: break
        case .oldTestament: sql += " AND book <= 39"
        case .newTestament: sql += " AND book >= 40"
        case .book(let b): sql += " AND book = ?"; params.append(b)
        }
        sql += " ORDER BY book, chapter, verse LIMIT ?"
        params.append(max(limit, 1))

        let rows = db.rows(sql, params)
        if rows.isEmpty, usesDiacritics(translation) {
            return normalizedSearch(raw, translation: translation, scope: scope, limit: limit)
        }

        return rows.map { r in
            let text = r["text"] as? String ?? ""
            return SearchHit(
                translation: r["translation"] as? String ?? translation,
                book: r["book"] as? Int ?? 1,
                chapter: r["chapter"] as? Int ?? 1,
                verse: r["verse"] as? Int ?? 1,
                text: text,
                snippet: Self.highlight(text, terms: terms),
                score: 1
            )
        }
    }

    /// Languages whose bundled text is written with points or accents.
    private static let diacriticLanguages: Set<String> = ["he", "grc", "el", "ar"]

    private func usesDiacritics(_ code: String) -> Bool {
        guard let lang = translation(code)?.langCode else { return false }
        return Self.diacriticLanguages.contains(lang)
    }

    private struct PlainVerse {
        var book: Int
        var chapter: Int
        var verse: Int
        var text: String
        var plain: String
    }

    private var plainCorpora: [String: [PlainVerse]] = [:]
    private let plainLock = NSLock()

    /// Folded verses for one translation, built once. A few megabytes at most,
    /// and only for the languages that need it.
    private func plainCorpus(_ code: String) -> [PlainVerse] {
        plainLock.lock()
        defer { plainLock.unlock() }
        if let cached = plainCorpora[code] { return cached }
        let corpus = db.rows(
            "SELECT book, chapter, verse, text FROM verses WHERE translation = ? ORDER BY book, chapter, verse",
            [code]
        ).compactMap { r -> PlainVerse? in
            guard let text = r["text"] as? String else { return nil }
            return PlainVerse(
                book: r["book"] as? Int ?? 0,
                chapter: r["chapter"] as? Int ?? 0,
                verse: r["verse"] as? Int ?? 0,
                text: text,
                plain: SearchQuery.plain(text)
            )
        }
        plainCorpora[code] = corpus
        return corpus
    }

    /// Matches an unpointed query against pointed text. Runs only when the plain
    /// scan found nothing, and only for Hebrew, Greek and Arabic.
    private func normalizedSearch(_ raw: String, translation: String, scope: SearchScope, limit: Int) -> [SearchHit] {
        var needles = SearchQuery.literalTerms(raw).map(SearchQuery.plain).filter { !$0.isEmpty }
        if needles.isEmpty {
            let phrase = SearchQuery.plain(raw)
            if !phrase.isEmpty { needles = [phrase] }
        }
        guard !needles.isEmpty else { return [] }

        var hits: [SearchHit] = []
        for verse in plainCorpus(translation) {
            switch scope {
            case .all: break
            case .oldTestament: if verse.book > 39 { continue }
            case .newTestament: if verse.book < 40 { continue }
            case .book(let b): if verse.book != b { continue }
            }
            guard needles.allSatisfy({ verse.plain.contains($0) }) else { continue }
            hits.append(SearchHit(
                translation: translation,
                book: verse.book,
                chapter: verse.chapter,
                verse: verse.verse,
                text: verse.text,
                snippet: verse.text,
                score: 1
            ))
            if hits.count >= limit { break }
        }
        return hits
    }

    private static func escapeLike(_ term: String) -> String {
        term.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    private static func highlight(_ text: String, terms: [String]) -> String {
        var marked = text
        for term in terms where !term.isEmpty {
            marked = markOccurrences(of: term, in: marked)
        }
        return marked
    }

    private static func markOccurrences(of term: String, in text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: NSRegularExpression.escapedPattern(for: term),
            options: [.caseInsensitive]
        ) else { return text }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return text }
        var out = ""
        var cursor = 0
        for match in matches where match.range.location >= cursor {
            out += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            out += "⟦" + ns.substring(with: match.range) + "⟧"
            cursor = match.range.location + match.range.length
        }
        out += ns.substring(from: cursor)
        return out
    }

    private static func score(matchInfo: Data?, textLength: Int) -> Double {
        guard let data = matchInfo, data.count >= 8 else { return 0 }
        let ints: [UInt32] = data.withUnsafeBytes { raw in
            let buf = raw.bindMemory(to: UInt32.self)
            return Array(buf)
        }
        guard ints.count >= 2 else { return 0 }
        let phrases = Int(ints[0])
        let cols = Int(ints[1])
        var idx = 2
        var score = 0.0
        for _ in 0..<phrases {
            for _ in 0..<cols {
                guard idx + 2 < ints.count else { return score }
                let hits = Double(ints[idx])
                if hits > 0 {
                    score += hits * 8.0 + hits / Double(max(textLength, 1)) * 100.0
                }
                idx += 3
            }
        }
        return score
    }
}

enum SearchScope: Hashable {
    case all
    case oldTestament
    case newTestament
    case book(Int)

    var label: String {
        switch self {
        case .all: return "All"
        case .oldTestament: return "Old Testament"
        case .newTestament: return "New Testament"
        case .book(let b): return DemoBooks.book(b)?.name ?? "Book"
        }
    }
}
