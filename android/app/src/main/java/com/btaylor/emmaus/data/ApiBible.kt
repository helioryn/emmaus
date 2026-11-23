package com.btaylor.emmaus.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

class ApiBibleException(message: String) : Exception(message)

/**
 * Minimal API.Bible client. Chapters are cached on disk for 30 days, which is
 * the maximum the publisher terms allow.
 */
class ApiBible(private val context: Context) {

    data class Result(
        val verses: List<Pair<Int, String>>,
        val copyright: String?,
        val cached: Boolean
    )

    private val cacheDir = File(context.filesDir, "api-cache").apply { mkdirs() }

    fun chapter(
        code: String,
        bibleId: String,
        name: String,
        book: Int,
        chapter: Int,
        key: String
    ): Result {
        if (bibleId.isBlank()) throw ApiBibleException("No API.Bible identifier for $code.")
        val cache = File(cacheDir, "$code-$book-$chapter.json")
        if (cache.exists() && System.currentTimeMillis() - cache.lastModified() < CACHE_MS) {
            readCache(cache)?.let { return it }
        }
        if (key.isBlank()) {
            throw ApiBibleException("Add your own API.Bible key in Settings to read $name.")
        }
        val bookId = BOOK_IDS.getOrNull(book - 1) ?: throw ApiBibleException("Unknown book.")
        val url = URL(
            "https://rest.api.bible/v1/bibles/$bibleId/chapters/$bookId.$chapter" +
                "?content-type=text&include-notes=false&include-titles=false" +
                "&include-chapter-numbers=false&include-verse-numbers=true&include-verse-spans=false"
        )
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            setRequestProperty("api-key", key)
            setRequestProperty("Accept", "application/json")
            connectTimeout = 20_000
            readTimeout = 30_000
        }
        val body: String
        try {
            val status = conn.responseCode
            val stream = if (status in 200..299) conn.inputStream else conn.errorStream
            body = stream?.bufferedReader()?.use { it.readText() } ?: ""
            when (status) {
                200 -> Unit
                401 -> throw ApiBibleException("That key was rejected. Check it at api.bible.")
                403 -> throw ApiBibleException("This key is not licensed for $name. Add $name in your api.bible dashboard.")
                404 -> throw ApiBibleException("$name is not available for this key.")
                429 -> throw ApiBibleException("Monthly call limit reached for this key.")
                else -> throw ApiBibleException("API.Bible returned error $status.")
            }
        } catch (e: ApiBibleException) {
            throw e
        } catch (e: Exception) {
            throw ApiBibleException("No connection to API.Bible. ${e.message ?: ""}".trim())
        } finally {
            conn.disconnect()
        }

        val data = JSONObject(body).getJSONObject("data")
        val verses = parseVerses(data.optString("content", ""))
        if (verses.isEmpty()) throw ApiBibleException("No verses came back for this chapter.")
        val copyright = data.optString("copyright", "").ifBlank { null }
        writeCache(cache, verses, copyright)
        return Result(verses, copyright, false)
    }

    /** Returns the number of English Bibles the key can see, or throws. */
    fun test(key: String): Int {
        if (key.isBlank()) throw ApiBibleException("Enter a key first.")
        val url = URL("https://rest.api.bible/v1/bibles?language=eng")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            setRequestProperty("api-key", key)
            connectTimeout = 15_000
            readTimeout = 20_000
        }
        val body: String
        try {
            val status = conn.responseCode
            val stream = if (status in 200..299) conn.inputStream else conn.errorStream
            body = stream?.bufferedReader()?.use { it.readText() } ?: ""
            if (status == 401) throw ApiBibleException("That key was rejected.")
            if (status != 200) throw ApiBibleException("API.Bible returned error $status.")
        } catch (e: ApiBibleException) {
            throw e
        } catch (e: Exception) {
            throw ApiBibleException("No connection. ${e.message ?: ""}".trim())
        } finally {
            conn.disconnect()
        }
        return JSONObject(body).getJSONArray("data").length()
    }

    fun clearCache() {
        cacheDir.listFiles()?.forEach { it.delete() }
    }

    private fun readCache(file: File): Result? = runCatching {
        val root = JSONObject(file.readText())
        val arr = root.getJSONArray("verses")
        val list = ArrayList<Pair<Int, String>>(arr.length())
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            list += o.getInt("n") to o.getString("t")
        }
        if (list.isEmpty()) null
        else Result(list, root.optString("copyright").ifBlank { null }, true)
    }.getOrNull()

    private fun writeCache(file: File, verses: List<Pair<Int, String>>, copyright: String?) {
        runCatching {
            val arr = JSONArray()
            verses.forEach { (n, t) ->
                arr.put(JSONObject().put("n", n).put("t", t))
            }
            file.writeText(JSONObject().put("copyright", copyright ?: "").put("verses", arr).toString())
        }
    }

    private fun parseVerses(content: String): List<Pair<Int, String>> {
        val out = ArrayList<Pair<Int, String>>()
        val matches = Regex("""\[(\d+)\]""").findAll(content).toList()
        if (matches.isEmpty()) {
            val text = clean(content)
            if (text.isNotEmpty()) out += 1 to text
            return out
        }
        matches.forEachIndexed { i, m ->
            val number = m.groupValues[1].toIntOrNull() ?: return@forEachIndexed
            val start = m.range.last + 1
            val end = if (i + 1 < matches.size) matches[i + 1].range.first else content.length
            if (end > start) {
                val text = clean(content.substring(start, end))
                if (text.isNotEmpty()) out += number to text
            }
        }
        return out
    }

    private fun clean(s: String): String = s
        .replace('\u00a0', ' ')
        .replace('\n', ' ')
        .replace(Regex("""\s+"""), " ")
        .trim()

    companion object {
        private const val CACHE_MS = 30L * 24 * 60 * 60 * 1000

        val BOOK_IDS = listOf(
            "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI",
            "1CH", "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER",
            "LAM", "EZK", "DAN", "HOS", "JOL", "AMO", "OBA", "JON", "MIC", "NAM", "HAB", "ZEP",
            "HAG", "ZEC", "MAL", "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL",
            "EPH", "PHP", "COL", "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE",
            "2PE", "1JN", "2JN", "3JN", "JUD", "REV"
        )
    }
}
