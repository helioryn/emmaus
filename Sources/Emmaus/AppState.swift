import Foundation
import SwiftUI
import AppKit

enum AppSection: String, CaseIterable, Identifiable {
    case home, read, search, wordStudy, dictionary, topics, plans, notebook, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: return "Home"
        case .read: return "Read"
        case .search: return "Search"
        case .wordStudy: return "Word Study"
        case .dictionary: return "Dictionary"
        case .topics: return "Topics"
        case .plans: return "Reading Plans"
        case .notebook: return "Notebook"
        case .settings: return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .home: return "house"
        case .read: return "book"
        case .search: return "magnifyingglass"
        case .wordStudy: return "character.book.closed"
        case .dictionary: return "text.book.closed"
        case .topics: return "list.bullet.rectangle"
        case .plans: return "calendar"
        case .notebook: return "square.and.pencil"
        case .settings: return "gearshape"
        }
    }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case study, word, interlinear, compare, commentary, notes
    var id: String { rawValue }
    var title: String {
        switch self {
        case .study: return "Study"
        case .word: return "Word"
        case .interlinear: return "Original"
        case .compare: return "Compare"
        case .commentary: return "Commentary"
        case .notes: return "Notes"
        }
    }
    var icon: String {
        switch self {
        case .study: return "text.magnifyingglass"
        case .word: return "character.book.closed"
        case .interlinear: return "textformat.abc.dottedunderline"
        case .compare: return "rectangle.split.3x1"
        case .commentary: return "book.pages"
        case .notes: return "note.text"
        }
    }
}

struct TheologianLink: Identifiable {
    var id: String { name }
    var name: String
    var subtitle: String
    var url: URL
}

@MainActor
final class AppState: ObservableObject {
    let bible: BibleStore
    let user: UserStore
    let speech: SpeechService
    var api: APIBibleClient

    @Published var section: AppSection = .read
    @Published var showBookOverview = false
    @Published var translationCode: String = "KJV"
    @Published var bookId: Int = 43
    @Published var chapter: Int = 1
    @Published var chapterData: ChapterData?
    @Published var selectedVerse: Int?
    @Published var selectedStrongs: String?
    @Published var inspectorTab: InspectorTab = .study
    @Published var showInspector = true
    @Published var isLoading = false
    @Published var remoteError: String?
    @Published var isUsingStaleCache = false

    @Published var themeName: AppTheme = .parchment
    @Published var fontSize: Double = 19
    @Published var lineSpacing: Double = 8
    @Published var serif: Bool = true
    @Published var showStrongs: Bool = true
    @Published var showRedLetter: Bool = true
    @Published var showVerseNumbers: Bool = true

    @Published var showCommandPalette = false
    @Published var focusMode = false
    @Published var toast: String?

    @Published var history: [Location] = []
    @Published var historyIndex: Int = 0

    @Published var searchQuery: String = ""
    @Published var searchTranslation: String = "KJV"
    @Published var searchScope: SearchScope = .all
    @Published var searchResults: [SearchHit] = []
    @Published var hasSearched = false

    @Published var wordStudyQuery: String = ""
    @Published var wordStudyResults: [StrongsEntry] = []

    @Published var noteFocusRequest: Int = 0
    private var fetchTask: Task<Void, Never>?

    init() {
        let dbURL: URL
        if let bundled = Bundle.main.url(forResource: "bible", withExtension: "db") {
            dbURL = bundled
        } else {
            dbURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/bible.db")
        }
        guard let db = try? Database(path: dbURL.path, readonly: true) else {
            fatalError("Emmaus could not open its Bible library at \(dbURL.path)")
        }
        bible = BibleStore(db: db)
        user = UserStore()
        speech = SpeechService()
        api = APIBibleClient()

        loadSettings()
        if bible.translation(translationCode) == nil {
            translationCode = bible.translations.first?.code ?? "KJV"
        }
        let current = Location(book: bookId, chapter: chapter, verse: selectedVerse)
        history = [current]
        historyIndex = 0
        loadChapter(keepSelection: true)
    }

    // MARK: - Derived

    var activeTranslation: Translation {
        bible.translation(translationCode) ?? bible.translations.first!
    }

    var activeBook: Book? { bible.book(bookId) }

    var theme: Theme { themeName.theme }

    var chapterTitle: String { "\(activeBook?.name ?? "") \(chapter)" }

    var selectedVerseText: String? {
        guard let v = selectedVerse else { return nil }
        return chapterData?.verses.first { $0.number == v }?.text
    }

    var currentKey: VerseKey? {
        guard let v = selectedVerse else { return nil }
        return VerseKey(book: bookId, chapter: chapter, verse: v)
    }

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex < history.count - 1 }

    var localTranslations: [Translation] { bible.translations.filter { !$0.isRemote } }
    var remoteTranslations: [Translation] { bible.translations.filter { $0.isRemote } }

    // MARK: - Settings

    private func loadSettings() {
        themeName = AppTheme(rawValue: user.string("theme", "parchment")) ?? .parchment
        fontSize = user.double("fontSize", 19)
        lineSpacing = user.double("lineSpacing", 8)
        serif = user.bool("serif", true)
        showStrongs = user.bool("showStrongs", true)
        showRedLetter = user.bool("redLetter", true)
        showVerseNumbers = user.bool("verseNumbers", true)
        showInspector = user.bool("showInspector", true)
        translationCode = user.string("translation", "KJV")
        bookId = user.int("book", 43)
        chapter = user.int("chapter", 1)
        selectedVerse = user.int("selectedVerse", 0) > 0 ? user.int("selectedVerse", 0) : nil
        searchTranslation = user.string("searchTranslation", "KJV")
    }

    func saveSettings() {
        user.setSetting("theme", themeName.rawValue)
        user.setSetting("fontSize", fontSize)
        user.setSetting("lineSpacing", lineSpacing)
        user.setSetting("serif", serif)
        user.setSetting("showStrongs", showStrongs)
        user.setSetting("redLetter", showRedLetter)
        user.setSetting("verseNumbers", showVerseNumbers)
        user.setSetting("showInspector", showInspector)
        user.setSetting("searchTranslation", searchTranslation)
    }

    private func savePosition() {
        user.setSetting("translation", translationCode)
        user.setSetting("book", bookId)
        user.setSetting("chapter", chapter)
        user.setSetting("selectedVerse", selectedVerse ?? 0)
    }

    // MARK: - Chapter loading

    func loadChapter(keepSelection: Bool = false) {
        fetchTask?.cancel()
        let tr = activeTranslation
        remoteError = nil
        isUsingStaleCache = false
        if !keepSelection { selectedVerse = nil }

        if tr.isRemote {
            if let cached = user.cachedCloudChapter(translation: tr.code, book: bookId, chapter: chapter),
               Date().timeIntervalSince(cached.fetched) < 30 * 24 * 3600 {
                chapterData = plainChapter(verses: cached.verses)
                isLoading = false
            } else {
                chapterData = nil
                fetchRemote(tr)
            }
        } else {
            chapterData = bible.chapter(translation: tr.code, book: bookId, chapter: chapter)
            isLoading = false
            if chapterData == nil {
                remoteError = "This chapter is not available in \(tr.short)."
            }
        }
        user.recordHistory(book: bookId, chapter: chapter)
        savePosition()
    }

    private func plainChapter(verses: [Int: String]) -> ChapterData {
        ChapterData(
            translation: translationCode,
            book: bookId,
            chapter: chapter,
            verses: verses.keys.sorted().map {
                Verse(number: $0, text: verses[$0] ?? "", tokens: nil, hasRed: false)
            }
        )
    }

    private func fetchRemote(_ tr: Translation) {
        guard api.isConfigured else {
            remoteError = "Add your API.Bible key in Settings to read \(tr.short)."
            return
        }
        let book = bookId
        let ch = chapter
        isLoading = true
        fetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.api.chapter(translation: tr, bookIndex: book, chapter: ch)
                guard !Task.isCancelled else { return }
                self.user.cacheCloudChapter(translation: tr.code, book: book, chapter: ch, verses: result.verses)
                if !result.copyright.isEmpty { self.user.setSetting("copyright-\(tr.code)", result.copyright) }
                if self.bookId == book && self.chapter == ch && self.translationCode == tr.code {
                    self.chapterData = ChapterData(
                        translation: tr.code, book: book, chapter: ch,
                        verses: result.verses.keys.sorted().map {
                            Verse(number: $0, text: result.verses[$0] ?? "", tokens: nil, hasRed: false)
                        }
                    )
                    self.isLoading = false
                    self.remoteError = nil
                }
            } catch {
                if self.bookId == book && self.chapter == ch {
                    if let stale = self.user.cachedCloudChapter(translation: tr.code, book: book, chapter: ch) {
                        self.chapterData = ChapterData(
                            translation: tr.code, book: book, chapter: ch,
                            verses: stale.verses.keys.sorted().map {
                                Verse(number: $0, text: stale.verses[$0] ?? "", tokens: nil, hasRed: false)
                            }
                        )
                        self.isUsingStaleCache = true
                    } else {
                        self.chapterData = nil
                    }
                    self.remoteError = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Navigation

    func openBookOverview(book: Int? = nil) {
        if let book {
            bookId = max(1, min(66, book))
        }
        showBookOverview = true
        section = .read
        selectedVerse = nil
        selectedStrongs = nil
        user.setSetting("book", bookId)
    }

    func open(book: Int, chapter: Int, verse: Int? = nil, push: Bool = true) {
        showBookOverview = false
        let newBook = max(1, min(66, book))
        let bookMeta = bible.book(newBook)
        let newChapter = max(1, min(bookMeta?.chapters ?? 150, chapter))
        let changed = newBook != bookId || newChapter != self.chapter
        bookId = newBook
        self.chapter = newChapter
        section = .read
        if changed {
            loadChapter(keepSelection: true)
        }
        if let verse {
            selectedVerse = verse
            if !showInspector { showInspector = true }
        }
        if push { pushHistory(Location(book: newBook, chapter: newChapter, verse: verse)) }
        savePosition()
    }

    func open(_ location: Location, push: Bool = true) {
        open(book: location.book, chapter: location.chapter, verse: location.verse, push: push)
    }

    func open(reference: String) {
        if let r = ReferenceParser.parse(reference) {
            open(book: r.book, chapter: r.chapter, verse: r.verse)
        } else {
            searchQuery = reference
            section = .search
            runSearch()
        }
    }

    func nextChapter() {
        let total = activeBook?.chapters ?? 1
        if chapter < total {
            open(book: bookId, chapter: chapter + 1)
        } else if bookId < 66 {
            open(book: bookId + 1, chapter: 1)
        }
    }

    func previousChapter() {
        if chapter > 1 {
            open(book: bookId, chapter: chapter - 1)
        } else if bookId > 1 {
            let prev = bible.book(bookId - 1)
            open(book: bookId - 1, chapter: prev?.chapters ?? 1)
        }
    }

    private func pushHistory(_ loc: Location) {
        if historyIndex < history.count - 1 {
            history.removeSubrange((historyIndex + 1)...)
        }
        if history.last != loc {
            history.append(loc)
            if history.count > 100 { history.removeFirst(history.count - 100) }
            historyIndex = history.count - 1
        }
    }

    func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        let loc = history[historyIndex]
        open(loc, push: false)
    }

    func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        let loc = history[historyIndex]
        open(loc, push: false)
    }

    func changeTranslation(_ code: String) {
        guard let tr = bible.translation(code) else { return }
        if tr.isRemote && !api.isConfigured {
            toast = "Add your API.Bible key in Settings to read \(tr.short)."
            return
        }
        translationCode = code
        selectedStrongs = nil
        user.setSetting("translation", code)
        loadChapter(keepSelection: true)
    }

    func selectVerse(_ v: Int) {
        selectedVerse = v
        savePosition()
    }

    func selectWord(_ token: Token, verse: Int) {
        selectedVerse = verse
        if let s = token.strongs.first {
            selectedStrongs = s
            inspectorTab = .word
            showInspector = true
        } else {
            inspectorTab = .study
            showInspector = true
        }
        savePosition()
    }

    func lookupStrongs(_ id: String) {
        selectedStrongs = id
        inspectorTab = .word
        showInspector = true
    }

    func requestNoteFocus() {
        guard let v = selectedVerse else { return }
        selectedVerse = v
        inspectorTab = .notes
        showInspector = true
        noteFocusRequest += 1
    }

    func toggleBookmark() {
        guard let v = selectedVerse else { return }
        user.toggleBookmark(book: bookId, chapter: chapter, verse: v)
        toast = user.isBookmarked(book: bookId, chapter: chapter, verse: v) ? "Bookmarked" : "Bookmark removed"
    }

    func setHighlight(_ color: Int?) {
        guard let v = selectedVerse else { return }
        user.setHighlight(book: bookId, chapter: chapter, verse: v, color: color)
    }

    func copyVerse() -> String {
        guard let v = selectedVerse, let text = selectedVerseText else { return "" }
        return "\(chapterTitle):\(v) (\(activeTranslation.short))\n\(text)"
    }

    // MARK: - Search

    func runSearch() {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { searchResults = []; hasSearched = false; return }
        if let ref = ReferenceParser.parse(q), q.rangeOfCharacter(from: .decimalDigits) != nil {
            open(book: ref.book, chapter: ref.chapter, verse: ref.verse)
            return
        }
        if q.uppercased().range(of: #"^[HG]\s*0*\d{1,5}[A-Z]?$"#, options: .regularExpression) != nil {
            wordStudyQuery = q
            section = .wordStudy
            runWordStudy()
            return
        }
        if bible.translation(searchTranslation)?.isRemote == true {
            searchTranslation = "KJV"
        }
        searchResults = bible.search(q, translation: searchTranslation, scope: searchScope)
        hasSearched = true
        user.addSearchHistory(q)
    }

    func runWordStudy() {
        let q = wordStudyQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { wordStudyResults = []; return }
        let upper = q.uppercased()
        if upper.range(of: #"^[HG]\s*0*\d{1,5}[A-Z]?$"#, options: .regularExpression) != nil {
            let id = upper.replacingOccurrences(of: " ", with: "")
            if let e = bible.strongs(id: id) {
                wordStudyResults = [e]
                selectedStrongs = e.id
                return
            }
        }
        wordStudyResults = bible.searchStrongs(q)
    }

    // MARK: - Bible tools

    func theologianLinks() -> [TheologianLink] {
        let ref = chapterTitle.replacingOccurrences(of: " ", with: "+")
        let q = (ReferenceParser.label(book: bookId, chapter: chapter, verse: selectedVerse)).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ref
        func url(_ s: String) -> URL { URL(string: s) ?? URL(string: "https://www.gty.org")! }
        return [
            TheologianLink(name: "Grace to You", subtitle: "John MacArthur sermons & resources", url: url("https://www.gty.org/search?q=\(q)")),
            TheologianLink(name: "Desiring God", subtitle: "John Piper sermons & articles", url: url("https://www.desiringgod.org/search/results?q=\(q)")),
            TheologianLink(name: "Ligonier", subtitle: "R.C. Sproul teaching", url: url("https://learn.ligonier.org/search?q=\(q)")),
            TheologianLink(name: "The Gospel Coalition", subtitle: "Essays, sermons and commentary", url: url("https://www.thegospelcoalition.org/search/?q=\(q)")),
            TheologianLink(name: "Bible Hub", subtitle: "Parallel commentaries & lexicons", url: url("https://biblehub.com/search/?q=\(q)")),
        ]
    }

    func openInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func toastMessage(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toast == message { toast = nil }
        }
    }

    // MARK: - Speech

    func toggleSpeech() {
        if speech.isSpeaking {
            speech.stop()
            return
        }
        guard let verses = chapterData?.verses else { return }
        speech.speakChapter(verses.map { ($0.number, $0.text) }, language: activeTranslation.langCode)
    }

    func speakVerse() {
        guard let v = selectedVerse, let text = selectedVerseText else { return }
        speech.speakWord(text, language: activeTranslation.langCode)
        _ = v
    }

    // MARK: - Daily verse

    static let dailyReferences: [(Int, Int, Int)] = [
        (43, 3, 16), (45, 8, 28), (19, 23, 1), (23, 40, 31), (24, 29, 11),
        (40, 11, 28), (50, 4, 13), (48, 2, 8), (49, 2, 8), (58, 11, 1),
        (20, 3, 5), (19, 46, 1), (19, 27, 1), (19, 91, 1), (19, 121, 1),
        (23, 53, 5), (26, 36, 26), (43, 14, 6), (43, 15, 5), (44, 1, 8),
        (45, 12, 1), (46, 13, 4), (47, 5, 17), (48, 5, 22), (50, 4, 6),
        (51, 3, 23), (52, 5, 16), (53, 2, 16), (55, 1, 7), (58, 4, 12),
        (59, 1, 5), (60, 5, 7), (62, 1, 9), (62, 4, 18), (63, 1, 7),
        (65, 1, 24), (66, 21, 4), (42, 6, 31), (41, 10, 45), (40, 6, 33),
        (19, 34, 8), (19, 37, 4), (19, 119, 105), (23, 41, 10), (24, 33, 3),
    ]

    var dailyVerse: (Location, String) {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let ref = Self.dailyReferences[day % Self.dailyReferences.count]
        let loc = Location(book: ref.0, chapter: ref.1, verse: ref.2)
        let text = bible.verseText(translation: "KJV", book: ref.0, chapter: ref.1, verse: ref.2) ?? ""
        return (loc, text)
    }

    // MARK: - Styling helpers

    var readingFontSize: CGFloat { CGFloat(fontSize) }
    var readingLineSpacing: CGFloat { CGFloat(lineSpacing) }

    func setTheme(_ t: AppTheme) {
        themeName = t
        saveSettings()
    }
}
