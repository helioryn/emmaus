package com.btaylor.emmaus.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max

class BibleDb(private val context: Context) {
    @Volatile
    private var database: SQLiteDatabase? = null

    private val db: SQLiteDatabase
        get() {
            database?.let { return it }
            synchronized(this) {
                database?.let { return it }
                val opened = openDatabase()
                database = opened
                return opened
            }
        }

    /** Copies the bundled library out of the APK on first launch. Call from a background thread. */
    fun prepare(): Long = db.path?.let { File(it).length() } ?: 0L

    fun isPrepared(): Boolean = database != null

    private fun openDatabase(): SQLiteDatabase {
        val external = context.getExternalFilesDir(null)?.resolve("bible.db")
        if (external != null && external.exists()) {
            return SQLiteDatabase.openDatabase(external.path, null, SQLiteDatabase.OPEN_READONLY)
        }
        val internal = File(context.filesDir, "bible.db")
        if (!internal.exists()) {
            context.assets.open("bible.db").use { input ->
                internal.outputStream().use { output -> input.copyTo(output, 1 shl 16) }
            }
        }
        return SQLiteDatabase.openDatabase(internal.path, null, SQLiteDatabase.OPEN_READONLY)
    }

    val translations: List<Translation> by lazy {
        val out = mutableListOf<Translation>()
        db.rawQuery(
            "SELECT code,name,short,lang_code,direction,has_strongs,has_red,has_interlinear,source,bible_id " +
                "FROM translations ORDER BY CASE WHEN source='api' THEN 1 ELSE 0 END, sort",
            null
        ).use { c ->
            while (c.moveToNext()) {
                out += Translation(
                    code = c.getString(0),
                    name = c.getString(1),
                    short = c.getString(2),
                    langCode = c.getString(3),
                    direction = c.getString(4),
                    hasStrongs = c.getInt(5) == 1,
                    hasRed = c.getInt(6) == 1,
                    hasInterlinear = c.getInt(7) == 1,
                    source = c.getString(8) ?: "local",
                    bibleId = if (c.isNull(9)) null else c.getString(9)
                )
            }
        }
        out
    }

    val books: List<Book> by lazy {
        val out = mutableListOf<Book>()
        db.rawQuery("SELECT id,name,short,testament,genre,chapters FROM books ORDER BY sort", null).use { c ->
            while (c.moveToNext()) {
                out += Book(c.getInt(0), c.getString(1), c.getString(2), c.getString(3), c.getString(4) ?: "", c.getInt(5))
            }
        }
        out
    }

    fun book(id: Int): Book? = books.firstOrNull { it.id == id }
    fun translation(code: String): Translation? = translations.firstOrNull { it.code == code }

    fun chapter(translation: String, book: Int, chapter: Int): ChapterData? {
        val verses = mutableListOf<Verse>()
        db.rawQuery(
            "SELECT verse,text,tokens,has_red FROM verses WHERE translation=? AND book=? AND chapter=? ORDER BY verse",
            arrayOf(translation, book.toString(), chapter.toString())
        ).use { c ->
            while (c.moveToNext()) {
                verses += Verse(
                    number = c.getInt(0),
                    text = c.getString(1) ?: "",
                    tokens = parseTokens(if (c.isNull(2)) null else c.getString(2)),
                    hasRed = c.getInt(3) == 1
                )
            }
        }
        if (verses.isEmpty()) return null
        return ChapterData(translation, book, chapter, verses)
    }

    fun verseText(translation: String, book: Int, chapter: Int, verse: Int): String? {
        db.rawQuery(
            "SELECT text FROM verses WHERE translation=? AND book=? AND chapter=? AND verse=?",
            arrayOf(translation, book.toString(), chapter.toString(), verse.toString())
        ).use { c -> if (c.moveToFirst()) return c.getString(0) }
        return null
    }

    private fun parseTokens(raw: String?): List<Token>? {
        if (raw.isNullOrBlank()) return null
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                Token(
                    text = o.optString("t"),
                    strongs = stringList(o.optJSONArray("s")),
                    morph = stringList(o.optJSONArray("m")),
                    red = o.optInt("r") == 1,
                    italic = o.optInt("i") == 1,
                    heading = o.optInt("h") == 1
                )
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun stringList(arr: JSONArray?): List<String> {
        if (arr == null) return emptyList()
        return (0 until arr.length()).map { arr.getString(it) }
    }

    fun crossReferences(book: Int, chapter: Int, verse: Int, limit: Int = 40): List<CrossRef> {
        val out = mutableListOf<CrossRef>()
        db.rawQuery(
            """
            SELECT cr.to_book, cr.to_chapter, cr.to_verse_start, cr.to_verse_end, cr.votes, COALESCE(v.text,'')
            FROM cross_refs cr
            LEFT JOIN verses v ON v.translation='KJV' AND v.book=cr.to_book AND v.chapter=cr.to_chapter AND v.verse=cr.to_verse_start
            WHERE cr.from_book=? AND cr.from_chapter=? AND cr.from_verse=?
            ORDER BY cr.votes DESC LIMIT ?
            """.trimIndent(),
            arrayOf(book.toString(), chapter.toString(), verse.toString(), limit.toString())
        ).use { c ->
            while (c.moveToNext()) {
                out += CrossRef(
                    toBook = c.getInt(0),
                    toChapter = c.getInt(1),
                    toVerseStart = c.getInt(2),
                    toVerseEnd = c.getInt(3),
                    votes = c.getInt(4),
                    preview = c.getString(5) ?: ""
                )
            }
        }
        return out
    }

    fun commentary(book: Int, chapter: Int, verse: Int): List<CommentaryEntry> {
        val out = mutableListOf<CommentaryEntry>()
        db.rawQuery(
            """
            SELECT work,verse_start,verse_end,body FROM commentaries
            WHERE book=? AND chapter=? AND verse_start<=? AND verse_end>=?
            ORDER BY work, verse_start
            """.trimIndent(),
            arrayOf(book.toString(), chapter.toString(), verse.toString(), verse.toString())
        ).use { c ->
            while (c.moveToNext()) {
                out += CommentaryEntry(
                    work = c.getString(0),
                    book = book,
                    chapter = chapter,
                    verseStart = c.getInt(1),
                    verseEnd = c.getInt(2),
                    body = c.getString(3) ?: ""
                )
            }
        }
        return out
    }

    fun interlinear(book: Int, chapter: Int, verse: Int): List<InterlinearWord> {
        val out = mutableListOf<InterlinearWord>()
        db.rawQuery(
            "SELECT seq,lang,text,translit,gloss,strongs,morph FROM interlinear WHERE book=? AND chapter=? AND verse=? ORDER BY seq",
            arrayOf(book.toString(), chapter.toString(), verse.toString())
        ).use { c ->
            while (c.moveToNext()) {
                out += InterlinearWord(
                    seq = c.getInt(0),
                    lang = c.getString(1),
                    text = c.getString(2),
                    translit = c.getString(3),
                    gloss = c.getString(4),
                    strongs = c.getString(5) ?: "",
                    morph = c.getString(6) ?: ""
                )
            }
        }
        return out
    }

    fun strongs(raw: String): StrongsEntry? {
        val id = normalizeStrong(raw)
        queryStrongs(id)?.let { return it }
        val base = id.replace(Regex("[A-Z]$"), "")
        queryStrongs(base)?.let { return it }
        var found: StrongsEntry? = null
        db.rawQuery("SELECT * FROM strongs WHERE id LIKE ? ORDER BY LENGTH(id) LIMIT 1", arrayOf("$base%")).use { c ->
            if (c.moveToFirst()) found = strongsFromCursor(c)
        }
        return found
    }

    fun strongsFamily(raw: String): List<StrongsEntry> {
        val base = normalizeStrong(raw).replace(Regex("[A-Z]$"), "")
        val out = mutableListOf<StrongsEntry>()
        db.rawQuery("SELECT * FROM strongs WHERE id=? OR parent=? ORDER BY id", arrayOf(base, base)).use { c ->
            while (c.moveToNext()) out += strongsFromCursor(c)
        }
        return out
    }

    private fun queryStrongs(id: String): StrongsEntry? {
        db.rawQuery("SELECT * FROM strongs WHERE id=?", arrayOf(id)).use { c ->
            if (c.moveToFirst()) return strongsFromCursor(c)
        }
        return null
    }

    private fun strongsFromCursor(c: android.database.Cursor): StrongsEntry {
        fun col(name: String): String = c.getString(c.getColumnIndexOrThrow(name)) ?: ""
        return StrongsEntry(
            id = col("id"),
            lang = col("lang"),
            lemma = col("lemma"),
            translit = col("translit"),
            pronounce = col("pronounce"),
            derivation = col("derivation"),
            definition = col("definition"),
            kjvUsage = col("kjv_usage"),
            gloss = col("gloss"),
            morph = col("morph"),
            parent = col("parent"),
            extended = col("extended")
        )
    }

    fun searchStrongs(query: String, limit: Int = 60): List<StrongsEntry> {
        val q = "%$query%"
        val out = mutableListOf<StrongsEntry>()
        db.rawQuery(
            "SELECT * FROM strongs WHERE id LIKE ? OR lemma LIKE ? OR translit LIKE ? OR gloss LIKE ? OR definition LIKE ? ORDER BY id LIMIT ?",
            arrayOf(q, q, q, q, q, limit.toString())
        ).use { c -> while (c.moveToNext()) out += strongsFromCursor(c) }
        return out
    }

    fun occurrences(strongsId: String, limit: Int = 500): List<Occurrence> {
        val out = mutableListOf<Occurrence>()
        db.rawQuery(
            "SELECT book,chapter,verse,form,morph FROM occurrences WHERE strongs=? ORDER BY book,chapter,verse LIMIT ?",
            arrayOf(strongsId, limit.toString())
        ).use { c ->
            while (c.moveToNext()) {
                out += Occurrence(c.getInt(0), c.getInt(1), c.getInt(2), c.getString(3) ?: "", c.getString(4) ?: "")
            }
        }
        return out
    }

    fun occurrenceCount(strongsId: String): Int {
        db.rawQuery("SELECT COUNT(*) FROM occurrences WHERE strongs=?", arrayOf(strongsId)).use { c ->
            if (c.moveToFirst()) return c.getInt(0)
        }
        return 0
    }

    fun search(
        raw: String,
        translation: String,
        scope: SearchScope = SearchScope.All,
        limit: Int = 200
    ): List<SearchHit> {
        val expr = SearchQuery.ftsExpression(raw) ?: return emptyList()
        val scopeSql = when (scope.kind) {
            SearchScopeKind.ALL -> ""
            SearchScopeKind.OLD -> " AND book<=39"
            SearchScopeKind.NEW -> " AND book>=40"
            SearchScopeKind.BOOK -> " AND book=?"
        }
        val args = if (scope.kind == SearchScopeKind.BOOK) {
            arrayOf(expr, translation, (scope.book ?: 0).toString())
        } else {
            arrayOf(expr, translation)
        }
        val out = mutableListOf<SearchHit>()
        db.rawQuery(
            """
            SELECT book,chapter,verse,text,
                   snippet(search,'⟦','⟧','…',-1,14) AS snip,
                   matchinfo(search,'pcx') AS mi
            FROM search WHERE search MATCH ? AND translation=?$scopeSql
            LIMIT 350
            """.trimIndent(),
            args
        ).use { c ->
            val miIndex = c.getColumnIndexOrThrow("mi")
            while (c.moveToNext()) {
                val text = c.getString(3) ?: ""
                val mi = if (c.isNull(miIndex)) null else c.getBlob(miIndex)
                out += SearchHit(
                    book = c.getInt(0),
                    chapter = c.getInt(1),
                    verse = c.getInt(2),
                    text = text,
                    snippet = c.getString(4) ?: text,
                    score = score(mi, text.length)
                )
            }
        }
        if (out.isEmpty()) {
            // Translations imported from eBible.org are not in the FTS index.
            return literalSearch(raw, translation, scope, limit)
        }
        return out.sortedWith(compareByDescending<SearchHit> { it.score }.thenBy { it.book }.thenBy { it.chapter }.thenBy { it.verse })
            .take(limit)
    }

    /** Plain substring search for translations the FTS index does not cover. */
    private fun literalSearch(
        raw: String,
        translation: String,
        scope: SearchScope = SearchScope.All,
        limit: Int
    ): List<SearchHit> {
        var terms = SearchQuery.literalTerms(raw)
        if (terms.isEmpty()) SearchQuery.sanitize(raw, allowSpaces = true)?.let { terms = listOf(it) }
        if (terms.isEmpty()) return emptyList()

        val where = StringBuilder("translation=?")
        val args = mutableListOf<String>(translation)
        for (term in terms.take(8)) {
            where.append(" AND text LIKE ? ESCAPE '\\'")
            args += "%${escapeLike(term)}%"
        }
        when (scope.kind) {
            SearchScopeKind.ALL -> Unit
            SearchScopeKind.OLD -> where.append(" AND book<=39")
            SearchScopeKind.NEW -> where.append(" AND book>=40")
            SearchScopeKind.BOOK -> {
                where.append(" AND book=?")
                args += (scope.book ?: 0).toString()
            }
        }
        args += limit.toString()

        val out = mutableListOf<SearchHit>()
        db.rawQuery(
            "SELECT book,chapter,verse,text FROM verses WHERE $where ORDER BY book,chapter,verse LIMIT ?",
            args.toTypedArray()
        ).use { c ->
            while (c.moveToNext()) {
                val text = c.getString(3) ?: ""
                out += SearchHit(
                    book = c.getInt(0),
                    chapter = c.getInt(1),
                    verse = c.getInt(2),
                    text = text,
                    snippet = highlight(text, terms),
                    score = 1.0
                )
            }
        }
        if (out.isEmpty() && usesDiacritics(translation)) {
            return normalizedSearch(raw, translation, scope, limit)
        }
        return out
    }

    /** Languages whose bundled text is written with points or accents. */
    private val diacriticLanguages = setOf("he", "grc", "el", "ar")

    private fun usesDiacritics(code: String): Boolean =
        translation(code)?.langCode in diacriticLanguages

    private data class PlainVerse(
        val book: Int,
        val chapter: Int,
        val verse: Int,
        val text: String,
        val plain: String
    )

    private val plainCorpora = HashMap<String, List<PlainVerse>>()

    /** Folded verses for one translation, built once and kept in memory. */
    @Synchronized
    private fun plainCorpus(code: String): List<PlainVerse> {
        plainCorpora[code]?.let { return it }
        val out = ArrayList<PlainVerse>()
        db.rawQuery(
            "SELECT book,chapter,verse,text FROM verses WHERE translation=? ORDER BY book,chapter,verse",
            arrayOf(code)
        ).use { c ->
            while (c.moveToNext()) {
                val text = c.getString(3) ?: ""
                out += PlainVerse(
                    book = c.getInt(0),
                    chapter = c.getInt(1),
                    verse = c.getInt(2),
                    text = text,
                    plain = SearchQuery.plain(text)
                )
            }
        }
        plainCorpora[code] = out
        return out
    }

    /** Matches an unpointed query against pointed Hebrew, Greek or Arabic. */
    private fun normalizedSearch(
        raw: String,
        translation: String,
        scope: SearchScope,
        limit: Int
    ): List<SearchHit> {
        var needles = SearchQuery.literalTerms(raw)
            .map { SearchQuery.plain(it) }
            .filter { it.isNotEmpty() }
        if (needles.isEmpty()) {
            val phrase = SearchQuery.plain(raw)
            if (phrase.isNotEmpty()) needles = listOf(phrase)
        }
        if (needles.isEmpty()) return emptyList()

        val out = mutableListOf<SearchHit>()
        for (verse in plainCorpus(translation)) {
            if (scope.matches(verse.book) && needles.all { verse.plain.contains(it) }) {
                out += SearchHit(
                    book = verse.book,
                    chapter = verse.chapter,
                    verse = verse.verse,
                    text = verse.text,
                    snippet = verse.text,
                    score = 1.0
                )
                if (out.size >= limit) break
            }
        }
        return out
    }

    private fun escapeLike(term: String): String = term
        .replace("\\", "\\\\")
        .replace("%", "\\%")
        .replace("_", "\\_")

    private fun highlight(text: String, terms: List<String>): String {
        var out = text
        for (term in terms) {
            if (term.isEmpty()) continue
            out = Regex(Regex.escape(term), RegexOption.IGNORE_CASE).replace(out) { "⟦${it.value}⟧" }
        }
        return out
    }

    private fun score(blob: ByteArray?, textLength: Int): Double {
        if (blob == null || blob.size < 8) return 0.0
        val buf = ByteBuffer.wrap(blob).order(ByteOrder.nativeOrder()).asIntBuffer()
        if (buf.limit() < 2) return 0.0
        val phrases = buf.get(0)
        val columns = buf.get(1)
        var i = 2
        var score = 0.0
        for (p in 0 until phrases) {
            for (col in 0 until columns) {
                if (i + 2 >= buf.limit()) return score
                val hits = buf.get(i).toDouble()
                if (hits > 0) score += hits * 8.0 + hits / max(textLength, 1) * 100.0
                i += 3
            }
        }
        return score
    }

    fun dictionarySearch(query: String, source: String? = null, limit: Int = 80): List<DictionaryEntry> {
        val q = "%$query%"
        val args = mutableListOf(q, q)
        var sql = "SELECT id,source,headword,body FROM dictionary WHERE (headword LIKE ? OR body LIKE ?)"
        if (!source.isNullOrBlank()) {
            sql += " AND source=?"
            args += source
        }
        sql += " ORDER BY CASE WHEN headword LIKE ? THEN 0 ELSE 1 END, LENGTH(headword), headword LIMIT ?"
        args += "$query%"
        args += limit.toString()
        val out = mutableListOf<DictionaryEntry>()
        db.rawQuery(sql, args.toTypedArray()).use { c ->
            while (c.moveToNext()) out += DictionaryEntry(c.getInt(0), c.getString(1), c.getString(2), c.getString(3) ?: "")
        }
        return out
    }

    fun dictionarySources(): List<String> {
        val out = mutableListOf<String>()
        db.rawQuery("SELECT DISTINCT source FROM dictionary ORDER BY source", null).use { c ->
            while (c.moveToNext()) out += c.getString(0)
        }
        return out
    }

    fun topicSections(): List<String> {
        val out = mutableListOf<String>()
        db.rawQuery("SELECT DISTINCT section FROM topics ORDER BY section", null).use { c ->
            while (c.moveToNext()) out += c.getString(0)
        }
        return out
    }

    fun topics(section: String, limit: Int = 800): List<TopicEntry> {
        val out = mutableListOf<TopicEntry>()
        db.rawQuery("SELECT id,section,subject,entry FROM topics WHERE section=? ORDER BY subject LIMIT ?",
            arrayOf(section, limit.toString())).use { c ->
            while (c.moveToNext()) out += TopicEntry(c.getInt(0), c.getString(1), c.getString(2), c.getString(3) ?: "")
        }
        return out
    }

    fun topicSearch(query: String, limit: Int = 100): List<TopicEntry> {
        val q = "%$query%"
        val out = mutableListOf<TopicEntry>()
        db.rawQuery("SELECT id,section,subject,entry FROM topics WHERE subject LIKE ? OR entry LIKE ? ORDER BY subject LIMIT ?",
            arrayOf(q, q, limit.toString())).use { c ->
            while (c.moveToNext()) out += TopicEntry(c.getInt(0), c.getString(1), c.getString(2), c.getString(3) ?: "")
        }
        return out
    }

    fun normalizeStrong(raw: String): String {
        val s = raw.uppercase().replace("STRONG:", "").trim()
        val m = Regex("^([HG])0*(\\d+)([A-Z]?)$").find(s) ?: return s
        return "${m.groupValues[1]}${m.groupValues[2].toInt()}${m.groupValues[3]}"
    }

    fun bookName(id: Int): String = book(id)?.name ?: "Book $id"
}
