package com.btaylor.emmaus.data

data class Translation(
    val code: String,
    val name: String,
    val short: String,
    val langCode: String,
    val direction: String,
    val hasStrongs: Boolean,
    val hasRed: Boolean,
    val hasInterlinear: Boolean
) {
    val isRtl: Boolean get() = direction == "rtl"
}

data class Book(
    val id: Int,
    val name: String,
    val short: String,
    val testament: String,
    val chapters: Int
)

data class Token(
    val text: String,
    val strongs: List<String> = emptyList(),
    val morph: List<String> = emptyList(),
    val red: Boolean = false,
    val italic: Boolean = false,
    val heading: Boolean = false
)

data class Verse(
    val number: Int,
    val text: String,
    val tokens: List<Token>? = null,
    val hasRed: Boolean = false
)

data class ChapterData(
    val translation: String,
    val book: Int,
    val chapter: Int,
    val verses: List<Verse>
)

data class CrossRef(
    val toBook: Int,
    val toChapter: Int,
    val toVerseStart: Int,
    val toVerseEnd: Int,
    val votes: Int,
    val preview: String
)

data class CommentaryEntry(
    val work: String,
    val book: Int,
    val chapter: Int,
    val verseStart: Int,
    val verseEnd: Int,
    val body: String
)

data class InterlinearWord(
    val seq: Int,
    val lang: String,
    val text: String,
    val translit: String,
    val gloss: String,
    val strongs: String,
    val morph: String
) {
    val isHebrew: Boolean get() = lang == "he"
}

data class StrongsEntry(
    val id: String,
    val lang: String,
    val lemma: String,
    val translit: String,
    val pronounce: String,
    val derivation: String,
    val definition: String,
    val kjvUsage: String,
    val gloss: String,
    val morph: String,
    val parent: String,
    val extended: String
) {
    val isHebrew: Boolean get() = id.startsWith("H")
    val languageName: String get() = if (isHebrew) "Hebrew" else "Greek"
    val languageCode: String get() = if (isHebrew) "he" else "grc"
}

data class Occurrence(
    val book: Int,
    val chapter: Int,
    val verse: Int,
    val form: String,
    val morph: String
)

data class SearchHit(
    val book: Int,
    val chapter: Int,
    val verse: Int,
    val text: String,
    val snippet: String,
    val score: Double
)

data class DictionaryEntry(
    val id: Int,
    val source: String,
    val headword: String,
    val body: String
)

data class TopicEntry(
    val id: Int,
    val section: String,
    val subject: String,
    val entry: String
)

data class WordRun(
    val text: String,
    val strongs: List<String> = emptyList(),
    val red: Boolean = false,
    val italic: Boolean = false,
    val heading: Boolean = false,
    val verseNumber: Boolean = false
)

fun verseKey(book: Int, chapter: Int, verse: Int) = "$book-$chapter-$verse"

fun refLabel(book: Book?, chapter: Int, verse: Int? = null): String {
    val name = book?.name ?: "Book"
    return if (verse != null) "$name $chapter:$verse" else "$name $chapter"
}

val ComicBookNames = mapOf(
    1 to "Genesis", 2 to "Exodus", 3 to "Leviticus", 4 to "Numbers", 5 to "Deuteronomy",
    6 to "Joshua", 7 to "Judges", 8 to "Ruth", 9 to "1 Samuel", 10 to "2 Samuel",
    11 to "1 Kings", 12 to "2 Kings", 13 to "1 Chronicles", 14 to "2 Chronicles",
    15 to "Ezra", 16 to "Nehemiah", 17 to "Esther", 18 to "Job", 19 to "Psalms",
    20 to "Proverbs", 21 to "Ecclesiastes", 22 to "Song of Solomon", 23 to "Isaiah",
    24 to "Jeremiah", 25 to "Lamentations", 26 to "Ezekiel", 27 to "Daniel", 28 to "Hosea",
    29 to "Joel", 30 to "Amos", 31 to "Obadiah", 32 to "Jonah", 33 to "Micah",
    34 to "Nahum", 35 to "Habakkuk", 36 to "Zephaniah", 37 to "Haggai", 38 to "Zechariah",
    39 to "Malachi", 40 to "Matthew", 41 to "Mark", 42 to "Luke", 43 to "John", 44 to "Acts",
    45 to "Romans", 46 to "1 Corinthians", 47 to "2 Corinthians", 48 to "Galatians", 49 to "Ephesians",
    50 to "Philippians", 51 to "Colossians", 52 to "1 Thessalonians", 53 to "2 Thessalonians",
    54 to "1 Timothy", 55 to "2 Timothy", 56 to "Titus", 57 to "Philemon", 58 to "Hebrews",
    59 to "James", 60 to "1 Peter", 61 to "2 Peter", 62 to "1 John", 63 to "2 John",
    64 to "3 John", 65 to "Jude", 66 to "Revelation"
)
