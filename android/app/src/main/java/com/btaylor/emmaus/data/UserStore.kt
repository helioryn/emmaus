package com.btaylor.emmaus.data

import android.content.Context
import androidx.compose.runtime.mutableStateMapOf
import org.json.JSONObject
import java.io.File

class UserStore(context: Context) {
    private val file = File(context.filesDir, "user.json")
    private val lock = Any()

    val notes = mutableStateMapOf<String, String>()
    val highlights = mutableStateMapOf<String, Int>()
    val bookmarks = mutableStateMapOf<String, Boolean>()
    val settings = mutableStateMapOf<String, String>()

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
            root.optJSONObject("highlights")?.let { o ->
                o.keys().forEach { k -> highlights[k] = o.optInt(k) }
            }
            root.optJSONObject("bookmarks")?.let { o ->
                o.keys().forEach { k -> if (o.optBoolean(k)) bookmarks[k] = true }
            }
            root.optJSONObject("settings")?.let { o ->
                o.keys().forEach { k -> settings[k] = o.optString(k) }
            }
        } catch (_: Exception) {
        }
    }

    fun save() {
        synchronized(lock) {
            try {
                val root = JSONObject()
                root.put("notes", JSONObject(notes.toMap() as Map<*, *>))
                root.put("highlights", JSONObject(highlights.toMap() as Map<*, *>))
                root.put("bookmarks", JSONObject(bookmarks.toMap() as Map<*, *>))
                root.put("settings", JSONObject(settings.toMap() as Map<*, *>))
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

    fun setSetting(key: String, value: Int) = setSetting(key, value.toString())
    fun setSetting(key: String, value: Boolean) = setSetting(key, if (value) "1" else "0")

    fun note(book: Int, chapter: Int, verse: Int): String? =
        notes[verseKey(book, chapter, verse)]

    fun saveNote(book: Int, chapter: Int, verse: Int, body: String) {
        val key = verseKey(book, chapter, verse)
        val trimmed = body.trim()
        if (trimmed.isEmpty()) notes.remove(key) else notes[key] = trimmed
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

    fun exportJson(): String {
        val root = JSONObject()
        root.put("notes", JSONObject(notes.toMap() as Map<*, *>))
        root.put("highlights", JSONObject(highlights.toMap() as Map<*, *>))
        root.put("bookmarks", JSONObject(bookmarks.toMap() as Map<*, *>))
        root.put("settings", JSONObject(settings.toMap() as Map<*, *>))
        return root.toString(2)
    }

    fun importJson(text: String) {
        try {
            val root = JSONObject(text)
            root.optJSONObject("notes")?.let { o ->
                o.keys().forEach { k -> notes[k] = o.optString(k) }
            }
            root.optJSONObject("highlights")?.let { o ->
                o.keys().forEach { k -> highlights[k] = o.optInt(k) }
            }
            root.optJSONObject("bookmarks")?.let { o ->
                o.keys().forEach { k -> if (o.optBoolean(k)) bookmarks[k] = true }
            }
            save()
        } catch (_: Exception) {
        }
    }
}
