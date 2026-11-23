package com.btaylor.emmaus

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.btaylor.emmaus.audio.TtsManager
import com.btaylor.emmaus.data.BibleDb
import com.btaylor.emmaus.data.Book
import com.btaylor.emmaus.data.ChapterData
import com.btaylor.emmaus.data.CommentaryEntry
import com.btaylor.emmaus.data.CrossRef
import com.btaylor.emmaus.data.InterlinearWord
import com.btaylor.emmaus.data.SearchHit
import com.btaylor.emmaus.data.StrongsEntry
import com.btaylor.emmaus.data.Translation
import com.btaylor.emmaus.data.Token
import com.btaylor.emmaus.data.UserStore
import com.btaylor.emmaus.data.Verse
import com.btaylor.emmaus.data.refLabel
import com.btaylor.emmaus.data.verseKey
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

enum class Screen { READ, SEARCH, WORD, NOTEBOOK }
enum class SheetTab(val label: String) {
    STUDY("Study"), WORD("Word"), ORIGINAL("Original"), COMPARE("Compare"), NOTES("Notes")
}

class AppViewModel(app: Application) : AndroidViewModel(app) {
    val bible = BibleDb(app)
    val user = UserStore(app)
    val tts = TtsManager(app)

    var screen by mutableStateOf(Screen.READ)
    var translationCode by mutableStateOf(user.setting("translation", "KJV"))
    var bookId by mutableStateOf(user.intSetting("book", 43))
    var chapter by mutableStateOf(user.intSetting("chapter", 1))

    var chapterData by mutableStateOf<ChapterData?>(null)
    var loading by mutableStateOf(true)
    var error by mutableStateOf<String?>(null)

    var selectedVerse by mutableStateOf<Int?>(null)
    var sheetOpen by mutableStateOf(false)
    var sheetTab by mutableStateOf(SheetTab.STUDY)
    var overviewOpen by mutableStateOf(false)
    var bookPickerOpen by mutableStateOf(false)
    var settingsOpen by mutableStateOf(false)

    var selectedStrongs by mutableStateOf<StrongsEntry?>(null)
    var crossRefs by mutableStateOf<List<CrossRef>>(emptyList())
    var commentary by mutableStateOf<List<CommentaryEntry>>(emptyList())
    var interlinear by mutableStateOf<List<InterlinearWord>>(emptyList())
    var studyWords by mutableStateOf<List<StrongsEntry>>(emptyList())
    var selectedWork by mutableStateOf("tyndale")

    var searchQuery by mutableStateOf("")
    var searchResults by mutableStateOf<List<SearchHit>>(emptyList())
    var searching by mutableStateOf(false)
    var hasSearched by mutableStateOf(false)

    var wordQuery by mutableStateOf("")
    var wordResults by mutableStateOf<List<StrongsEntry>>(emptyList())
    var wordSelected by mutableStateOf<StrongsEntry?>(null)

    var themeName by mutableStateOf(user.setting("theme", "parchment"))
    var fontSize by mutableStateOf(user.intSetting("fontSize", 19))
    var showStrongs by mutableStateOf(user.boolSetting("showStrongs", true))
    var redLetter by mutableStateOf(user.boolSetting("redLetter", true))

    var toast by mutableStateOf<String?>(null)

    val activeTranslation: Translation
        get() = bible.translation(translationCode) ?: bible.translations.first()
    val activeBook: Book?
        get() = bible.book(bookId)

    init {
        loadChapter(record = true)
    }

    fun loadChapter(record: Boolean = false) {
        loading = true
        error = null
        val requestedBook = bookId
        val requestedChapter = chapter
        val requestedTranslation = translationCode
        viewModelScope.launch {
            val data = withContext(Dispatchers.IO) {
                bible.chapter(requestedTranslation, requestedBook, requestedChapter)
            }
            if (requestedBook != bookId || requestedChapter != chapter || requestedTranslation != translationCode) {
                return@launch
            }
            chapterData = data
            loading = false
            if (data == null) error = "This chapter is not available in ${activeTranslation.short}."
            user.setSetting("book", bookId)
            user.setSetting("chapter", chapter)
            user.setSetting("translation", translationCode)
            if (record) user.recordRead(requestedBook, requestedChapter)
            val verse = selectedVerse
            if (sheetOpen && verse != null) loadStudy(verse)
        }
    }

    fun showBookOverview(book: Int = bookId) {
        val target = book.coerceIn(1, 66)
        screen = Screen.READ
        sheetOpen = false
        selectedVerse = null
        selectedStrongs = null
        overviewOpen = true
        if (target != bookId) {
            bookId = target
            chapter = user.lastChapter(target) ?: 1
            user.setSetting("book", bookId)
            user.setSetting("chapter", chapter)
            loadChapter(record = false)
        }
    }

    fun closeOverview() {
        overviewOpen = false
    }

    fun open(book: Int, chapter: Int, verse: Int? = null) {
        overviewOpen = false
        bookId = book.coerceIn(1, 66)
        this.chapter = chapter.coerceAtLeast(1)
        selectedVerse = verse
        sheetOpen = false
        screen = Screen.READ
        loadChapter(record = true)
    }

    fun openNote(book: Int, chapter: Int, verse: Int) {
        open(book, chapter, verse)
        sheetTab = SheetTab.NOTES
        sheetOpen = true
        loadStudy(verse)
    }

    fun continueReading(book: Int) {
        open(book, user.lastChapter(book) ?: 1)
    }

    fun readChapters(book: Int): Set<Int> = user.readChapters(book)
    fun lastChapter(book: Int): Int? = user.lastChapter(book)
    fun chapterHasMarks(book: Int, chapter: Int): Boolean = user.chapterHasMarks(book, chapter)
    fun notesInBook(book: Int): List<com.btaylor.emmaus.data.BookNote> = user.notesInBook(book)
    val streak: Int get() = user.streak

    fun openReference(reference: String): Boolean {
        val r = parseReference(reference) ?: return false
        open(r.first, r.second, r.third)
        return true
    }

    fun nextChapter() {
        val book = activeBook ?: return
        if (chapter < book.chapters) open(bookId, chapter + 1)
        else if (bookId < 66) open(bookId + 1, 1)
    }

    fun previousChapter() {
        if (chapter > 1) open(bookId, chapter - 1)
        else if (bookId > 1) {
            val prev = bible.book(bookId - 1)
            open(bookId - 1, prev?.chapters ?: 1)
        }
    }

    fun changeTranslation(code: String) {
        if (bible.translation(code) == null) return
        translationCode = code
        selectedStrongs = null
        user.setSetting("translation", code)
        loadChapter()
    }

    fun selectVerse(verse: Int) {
        selectedVerse = verse
        selectedStrongs = null
        loadStudy(verse)
        sheetTab = SheetTab.STUDY
        sheetOpen = true
    }

    fun selectWord(verse: Int, strongsId: String) {
        selectedVerse = verse
        selectedStrongs = bible.strongs(strongsId)
        loadStudy(verse)
        sheetTab = SheetTab.WORD
        sheetOpen = true
    }

    fun openStrongs(id: String) {
        selectedStrongs = bible.strongs(id)
        sheetTab = SheetTab.WORD
        sheetOpen = true
    }

    private fun loadStudy(verse: Int) {
        selectedVerse = verse
        viewModelScope.launch {
            val b = bookId
            val c = chapter
            val result = withContext(Dispatchers.IO) {
                val refs = bible.crossReferences(b, c, verse, 30)
                val comm = bible.commentary(b, c, verse)
                val inter = bible.interlinear(b, c, verse)
                val v = chapterData?.verses?.firstOrNull { it.number == verse }
                val ids = v?.tokens?.flatMap { it.strongs }?.distinct() ?: emptyList()
                val words = ids.mapNotNull { bible.strongs(it) }
                Quad(refs, comm, inter, words)
            }
            crossRefs = result.refs
            commentary = result.commentary
            interlinear = result.interlinear
            studyWords = result.words
            if (commentary.isNotEmpty()) {
                val works = commentary.map { it.work }.distinct()
                if (selectedWork !in works) selectedWork = preferredWork(works)
            }
            if (selectedStrongs == null) studyWords.firstOrNull()?.let { selectedStrongs = it }
        }
    }

    fun selectTab(tab: SheetTab) {
        sheetTab = tab
        if (tab == SheetTab.WORD && selectedStrongs == null) {
            selectedStrongs = studyWords.firstOrNull()
        }
    }

    fun preferenceWork(work: String) {
        selectedWork = work
    }

    fun commentaryWorks(): List<String> = commentary.map { it.work }.distinct()

    fun commentaryForSelected(): List<CommentaryEntry> =
        commentary.filter { it.work == selectedWork }

    private fun preferredWork(works: List<String>): String {
        for (w in listOf("tyndale", "matthew-henry", "jamieson-fausset-brown", "geneva", "scofield")) {
            if (w in works) return w
        }
        return works.firstOrNull() ?: "tyndale"
    }

    // Search

    fun runSearch() {
        val q = searchQuery.trim()
        if (q.isEmpty()) {
            searchResults = emptyList()
            hasSearched = false
            return
        }
        if (q.uppercase().matches(Regex("^[HG]\\s*0*\\d{1,5}[A-Z]?$"))) {
            wordQuery = q
            screen = Screen.WORD
            runWordStudy()
            return
        }
        if (parseReference(q) != null && q.any { it.isDigit() }) {
            openReference(q)
            return
        }
        searching = true
        viewModelScope.launch {
            searchResults = withContext(Dispatchers.IO) { bible.search(q, translationCode) }
            searching = false
            hasSearched = true
        }
    }

    // Word study

    fun runWordStudy() {
        val q = wordQuery.trim()
        if (q.isEmpty()) {
            wordResults = emptyList()
            wordSelected = null
            return
        }
        val strongMatch = Regex("^[HG]\\s*0*\\d{1,5}[A-Z]?$").matches(q.uppercase())
        viewModelScope.launch {
            val result = withContext(Dispatchers.IO) {
                if (strongMatch) {
                    listOfNotNull(bible.strongs(q))
                } else {
                    bible.searchStrongs(q)
                }
            }
            wordResults = result
            wordSelected = result.firstOrNull()
        }
    }

    // Notes & marks

    fun note(verse: Int): String = user.note(bookId, chapter, verse) ?: ""
    fun saveNote(verse: Int, text: String) = user.saveNote(bookId, chapter, verse, text)
    fun highlight(verse: Int): Int? = user.highlight(bookId, chapter, verse)
    fun setHighlight(verse: Int, color: Int?) = user.setHighlight(bookId, chapter, verse, color)
    fun isBookmarked(verse: Int): Boolean = user.isBookmarked(bookId, chapter, verse)
    fun toggleBookmark(verse: Int) {
        user.toggleBookmark(bookId, chapter, verse)
        toast = if (isBookmarked(verse)) "Bookmarked" else "Bookmark removed"
    }

    // Appearance

    fun setTheme(theme: String) {
        themeName = theme
        user.setSetting("theme", theme)
    }

    fun updateFontSize(size: Int) {
        fontSize = size.coerceIn(15, 28)
        user.setSetting("fontSize", fontSize)
    }

    fun updateShowStrongs(value: Boolean) {
        showStrongs = value
        user.setSetting("showStrongs", value)
    }

    fun updateRedLetter(value: Boolean) {
        redLetter = value
        user.setSetting("redLetter", value)
    }

    // Audio

    fun speakWord(text: String, lang: String, slow: Boolean = false) {
        tts.speakWord(text, lang, slow)
    }

    fun speakChapter() {
        val verses = chapterData?.verses ?: return
        if (verses.isEmpty()) return
        tts.speakChapter(verses.map { it.number to it.text }, activeTranslation.langCode)
    }

    fun toggleSpeech() {
        if (tts.speaking) tts.stop() else speakChapter()
    }

    // Reference parser

    private val aliases: Map<String, Int> = buildMap {
        bible.books.forEach { b ->
            put(b.name.lowercase(), b.id)
            put(b.short.lowercase(), b.id)
        }
        val extra = mapOf(
            "gen" to 1, "ge" to 1, "ex" to 2, "exo" to 2, "lev" to 3, "num" to 4, "deut" to 5,
            "josh" to 6, "judg" to 7, "ruth" to 8, "1sa" to 9, "2sa" to 10, "1ki" to 11, "2ki" to 12,
            "1ch" to 13, "2ch" to 14, "ezr" to 15, "neh" to 16, "est" to 17, "job" to 18,
            "ps" to 19, "psa" to 19, "prov" to 20, "eccl" to 21, "song" to 22, "isa" to 23,
            "jer" to 24, "lam" to 25, "ezek" to 26, "dan" to 27, "hos" to 28, "joel" to 29,
            "amos" to 30, "obad" to 31, "jonah" to 32, "mic" to 33, "nah" to 34, "hab" to 35,
            "zeph" to 36, "hag" to 37, "zech" to 38, "mal" to 39, "matt" to 40, "mt" to 40,
            "mark" to 41, "mk" to 41, "luke" to 42, "lk" to 42, "john" to 43, "jn" to 43,
            "acts" to 44, "rom" to 45, "1cor" to 46, "2cor" to 47, "gal" to 48, "eph" to 49,
            "phil" to 50, "col" to 51, "1thess" to 52, "2thess" to 53, "1tim" to 54, "2tim" to 55,
            "titus" to 56, "phlm" to 57, "heb" to 58, "jas" to 59, "1pet" to 60, "2pet" to 61,
            "1john" to 62, "2john" to 63, "3john" to 64, "jude" to 65, "rev" to 66
        )
        putAll(extra)
    }

    fun parseReference(input: String): Triple<Int, Int, Int?>? {
        val s = input.trim().lowercase().replace(Regex("\\s+"), " ")
        val m = Regex("^([1-3]?\\s*[a-z][a-z ]*?)\\s*(\\d+)(?:\\s*[:.]\\s*(\\d+))?$").find(s) ?: return null
        val rawBook = m.groupValues[1].trim()
        val book = aliases[rawBook] ?: aliases[rawBook.replace(" ", "")]
        val chapter = m.groupValues[2].toIntOrNull() ?: return null
        val verse = m.groupValues[3].toIntOrNull()
        if (book == null) return null
        return Triple(book, chapter, verse)
    }

    fun refLabel(verse: Int? = null): String = refLabel(activeBook, chapter, verse)

    fun openUrl(context: android.content.Context, url: String) {
        try {
            context.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url)))
        } catch (_: Exception) {
        }
    }

    fun theologianUrl(name: String): String {
        val q = refLabel(selectedVerse).replace(" ", "+")
        return when (name) {
            "Grace to You" -> "https://www.gty.org/search?q=$q"
            "Desiring God" -> "https://www.desiringgod.org/search/results?q=$q"
            "Ligonier" -> "https://learn.ligonier.org/search?q=$q"
            "The Gospel Coalition" -> "https://www.thegospelcoalition.org/search/?q=$q"
            else -> "https://biblehub.com/search/?q=$q"
        }
    }

    override fun onCleared() {
        tts.shutdown()
        super.onCleared()
    }

    private data class Quad<A, B, C, D>(val a: A, val b: B, val c: C, val d: D) {
        val refs: A get() = a
        val commentary: B get() = b
        val interlinear: C get() = c
        val words: D get() = d
    }
}
