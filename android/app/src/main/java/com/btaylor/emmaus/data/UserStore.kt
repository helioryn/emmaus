package com.btaylor.emmaus.data

import android.content.Context
import androidx.compose.runtime.mutableStateMapOf
import org.json.JSONObject
import java.io.File
import java.time.LocalDate

class UserStore(context: Context) {
    private val file = File(context.filesDir, "user.json")
    private val lock = Any()

    val notes = mutableStateMapOf<String, String>()
    val noteTimes = mutableStateMapOf<String, Long>()
    val highlights = mutableStateMapOf<String, Int>()
    val bookmarks = mutableStateMapOf<String, Boolean>()
    val settings = mutableStateMapOf<String, String>()
    val history = mutableStateMapOf<String, Long>()
    val activityDays = mutableStateMapOf<String, Long>()
    /** Completed plan days, keyed "planId:day". */
    val planDays = mutableStateMapOf<String, Long>()

    init {
        load()
        defaults()
    }

    private fun defaults() {
        putDefault("translation", "KJV")
        putDefault("fontSize", "19")
        putDefault("theme", "parchment")
        putDefault("book", "43")
        putDefault("chapter", "1")
        putDefault("showStrongs", "1")
        putDefault("redLetter", "1")
    }

    private fun putDefault(key: String, value: String) {
        if (settings[key].isNullOrBlank()) settings[key] = value
    }

    private fun load() {
        if (!file.exists()) return
        try {
            val root = JSONObject(file.readText())
            root.optJSONObject("notes")?.let { o ->
                o.keys().forEach { k -> notes[k] = o.optString(k) }
            }
            root.optJSONObject("noteTimes")?.let { o ->
                o.keys().forEach { k -> noteTimes[k] = o.optLong(k) }
            }
            root.optJSONObject("highlights")?.let { o ->
                o.keys().forEach { k -> highlights[k] = o.optInt(k) }
            }
            root.optJSONObject("bookmarks")?.let { o ->
                o.keys().forEach { k -> if (o.optBoolean(k)) bookmarks[k] = true }
            }
            root.optJSONObject("settings")?.let { o ->
                o.keys().forEach { k -> settings[k] = o.optString(k) }
            }
            root.optJSONObject("history")?.let { o ->
                o.keys().forEach { k -> history[k] = o.optLong(k) }
            }
            root.optJSONObject("activityDays")?.let { o ->
                o.keys().forEach { k -> activityDays[k] = o.optLong(k) }
            }
            root.optJSONObject("planDays")?.let { o ->
                o.keys().forEach { k -> planDays[k] = o.optLong(k) }
            }
        } catch (_: Exception) {
        }
    }

    fun save() {
        synchronized(lock) {
            try {
                val root = JSONObject()
                root.put("notes", JSONObject(notes.toMap() as Map<*, *>))
                root.put("noteTimes", JSONObject(noteTimes.toMap() as Map<*, *>))
                root.put("highlights", JSONObject(highlights.toMap() as Map<*, *>))
                root.put("bookmarks", JSONObject(bookmarks.toMap() as Map<*, *>))
                root.put("settings", JSONObject(settings.toMap() as Map<*, *>))
                root.put("history", JSONObject(history.toMap() as Map<*, *>))
                root.put("activityDays", JSONObject(activityDays.toMap() as Map<*, *>))
                root.put("planDays", JSONObject(planDays.toMap() as Map<*, *>))
                file.writeText(root.toString())
            } catch (_: Exception) {
            }
        }
    }

    fun setting(key: String, fallback: String = ""): String = settings[key] ?: fallback
    fun boolSetting(key: String, fallback: Boolean = false): Boolean =
        settings[key]?.let { it == "1" } ?: fallback
    fun intSetting(key: String, fallback: Int = 0): Int =
        settings[key]?.toIntOrNull() ?: fallback

    fun setSetting(key: String, value: String) {
        settings[key] = value
        save()
    }

    fun removeSetting(key: String) {
        if (settings.remove(key) != null) save()
    }

    fun setSetting(key: String, value: Int) = setSetting(key, value.toString())
    fun setSetting(key: String, value: Boolean) = setSetting(key, if (value) "1" else "0")

    fun note(book: Int, chapter: Int, verse: Int): String? =
        notes[verseKey(book, chapter, verse)]

    fun saveNote(book: Int, chapter: Int, verse: Int, body: String) {
        val key = verseKey(book, chapter, verse)
        val trimmed = body.trim()
        if (trimmed.isEmpty()) {
            notes.remove(key)
            noteTimes.remove(key)
        } else {
            notes[key] = trimmed
            noteTimes[key] = System.currentTimeMillis()
        }
        save()
    }

    fun highlight(book: Int, chapter: Int, verse: Int): Int? =
        highlights[verseKey(book, chapter, verse)]

    fun setHighlight(book: Int, chapter: Int, verse: Int, color: Int?) {
        val key = verseKey(book, chapter, verse)
        if (color == null) highlights.remove(key) else highlights[key] = color
        save()
    }

    fun isBookmarked(book: Int, chapter: Int, verse: Int): Boolean =
        bookmarks[verseKey(book, chapter, verse)] == true

    fun toggleBookmark(book: Int, chapter: Int, verse: Int) {
        val key = verseKey(book, chapter, verse)
        if (bookmarks[key] == true) bookmarks.remove(key) else bookmarks[key] = true
        save()
    }

    // Reading history & activity

    fun recordRead(book: Int, chapter: Int) {
        val now = System.currentTimeMillis()
        history[chapterKey(book, chapter)] = now
        activityDays[LocalDate.now().toString()] = now
        save()
    }

    val streak: Int
        get() {
            var day = LocalDate.now()
            if (activityDays[day.toString()] == null) {
                day = day.minusDays(1)
                if (activityDays[day.toString()] == null) return 0
            }
            var count = 0
            while (activityDays[day.toString()] != null) {
                count++
                day = day.minusDays(1)
            }
            return count
        }

    val chaptersRead: Int get() = history.size

    val lastReading: ReadingLocation?
        get() {
            val entry = history.maxByOrNull { it.value } ?: return null
            return parseChapterKey(entry.key)
        }

    fun lastChapter(book: Int): Int? {
        var best: Long? = null
        var chapter: Int? = null
        for ((key, timestamp) in history) {
            val parsed = parseChapterKey(key) ?: continue
            if (parsed.book != book) continue
            if (best == null || timestamp > best) {
                best = timestamp
                chapter = parsed.chapter
            }
        }
        return chapter
    }

    fun readChapters(book: Int): Set<Int> {
        val out = mutableSetOf<Int>()
        for (key in history.keys) {
            val parsed = parseChapterKey(key) ?: continue
            if (parsed.book == book) out += parsed.chapter
        }
        return out
    }

    fun chapterHasMarks(book: Int, chapter: Int): Boolean {
        val prefix = "$book-$chapter-"
        return notes.keys.any { it.startsWith(prefix) } ||
            highlights.keys.any { it.startsWith(prefix) } ||
            bookmarks.keys.any { it.startsWith(prefix) }
    }

    fun notesInBook(book: Int): List<BookNote> = notesInBookAll().filter { it.book == book }

    fun recentNotes(limit: Int = 6): List<BookNote> = notesInBookAll().take(limit)

    private fun notesInBookAll(): List<BookNote> {
        val out = mutableListOf<BookNote>()
        for ((key, body) in notes) {
            val parts = key.split("-")
            if (parts.size != 3) continue
            val b = parts[0].toIntOrNull() ?: continue
            val c = parts[1].toIntOrNull() ?: continue
            val v = parts[2].toIntOrNull() ?: continue
            out += BookNote(b, c, v, body, noteTimes[key] ?: 0L)
        }
        return out.sortedByDescending { it.updated }
    }

    fun recentReadings(limit: Int = 6): List<ReadingLocation> {
        val out = mutableListOf<ReadingLocation>()
        for (entry in history.entries.sortedByDescending { it.value }) {
            val parsed = parseChapterKey(entry.key) ?: continue
            out += parsed
            if (out.size >= limit) break
        }
        return out
    }

    val startedBooks: Int
        get() = history.keys.mapNotNull { parseChapterKey(it)?.book }.toSet().size

    private fun parseChapterKey(key: String): ReadingLocation? {
        val parts = key.split("-")
        if (parts.size != 2) return null
        val b = parts[0].toIntOrNull() ?: return null
        val c = parts[1].toIntOrNull() ?: return null
        return ReadingLocation(b, c)
    }

    fun noteKeys(): List<String> = notes.keys.sorted()
    fun bookmarkKeys(): List<String> = bookmarks.keys.sorted()
    fun highlightKeys(): List<String> = highlights.keys.sorted()

    fun parseKey(key: String): Triple<Int, Int, Int>? {
        val parts = key.split("-")
        if (parts.size != 3) return null
        val b = parts[0].toIntOrNull() ?: return null
        val c = parts[1].toIntOrNull() ?: return null
        val v = parts[2].toIntOrNull() ?: return null
        return Triple(b, c, v)
    }

    /** Human-readable export, matching the macOS Markdown output. */
    fun exportMarkdown(bookName: (Int) -> String): String =
        NoteExport.markdown(notesInBookAll(), bookmarkKeys(), bookName)

    fun exportJson(): String {
        val root = JSONObject()
        root.put("notes", JSONObject(notes.toMap() as Map<*, *>))
        root.put("noteTimes", JSONObject(noteTimes.toMap() as Map<*, *>))
        root.put("highlights", JSONObject(highlights.toMap() as Map<*, *>))
        root.put("bookmarks", JSONObject(bookmarks.toMap() as Map<*, *>))
        // Never export the API key (or anything else secret-shaped).
        root.put("settings", JSONObject(exportableSettings(settings) as Map<*, *>))
        root.put("history", JSONObject(history.toMap() as Map<*, *>))
        root.put("activityDays", JSONObject(activityDays.toMap() as Map<*, *>))
        root.put("planDays", JSONObject(planDays.toMap() as Map<*, *>))
        return root.toString(2)
    }

    fun importJson(text: String) {
        try {
            val root = JSONObject(text)
            root.optJSONObject("notes")?.let { o ->
                o.keys().forEach { k -> notes[k] = o.optString(k) }
            }
            root.optJSONObject("noteTimes")?.let { o ->
                o.keys().forEach { k -> noteTimes[k] = o.optLong(k) }
            }
            root.optJSONObject("highlights")?.let { o ->
                o.keys().forEach { k -> highlights[k] = o.optInt(k) }
            }
            root.optJSONObject("bookmarks")?.let { o ->
                o.keys().forEach { k -> if (o.optBoolean(k)) bookmarks[k] = true }
            }
            root.optJSONObject("history")?.let { o ->
                o.keys().forEach { k -> history[k] = o.optLong(k) }
            }
            root.optJSONObject("activityDays")?.let { o ->
                o.keys().forEach { k -> activityDays[k] = o.optLong(k) }
            }
            root.optJSONObject("planDays")?.let { o ->
                o.keys().forEach { k -> planDays[k] = o.optLong(k) }
            }
            save()
        } catch (_: Exception) {
        }
    }

    // Reading plans

    private fun planDayKey(plan: String, day: Int) = "$plan:$day"

    fun isPlanDayDone(plan: String, day: Int): Boolean = planDays[planDayKey(plan, day)] != null

    fun setPlanDay(plan: String, day: Int, done: Boolean) {
        val key = planDayKey(plan, day)
        if (done) planDays[key] = System.currentTimeMillis() else planDays.remove(key)
        save()
    }

    fun completedPlanDays(plan: String): Int =
        planDays.keys.count { it.startsWith("$plan:") }

    companion object {
        /** Settings that are safe to export: everything except credentials. */
        fun exportableSettings(settings: Map<String, String>): Map<String, String> =
            settings.filterKeys { key ->
                val normalized = key.lowercase().filter { it.isLetterOrDigit() }
                listOf("apikey", "secret", "token", "password").none { normalized.contains(it) }
            }
    }
}
