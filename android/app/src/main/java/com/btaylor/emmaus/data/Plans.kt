package com.btaylor.emmaus.data

/** A named reading plan: every chapter in a range, spread over a fixed number of days. */
data class PlanDefinition(
    val id: String,
    val name: String,
    val subtitle: String,
    val days: Int,
    val bookRange: IntRange
)

data class PlanDay(
    val plan: String,
    val day: Int,
    val readings: List<ReadingLocation>,
    val label: String
)

data class ReadingPlan(
    val id: String,
    val name: String,
    val subtitle: String,
    val days: List<PlanDay>
)

/**
 * Plans are derived from the canon at runtime, matching `Sources/Emmaus/Plans.swift`.
 * Nothing is stored until a day is marked complete.
 */
object PlanLibrary {
    val definitions = listOf(
        PlanDefinition("bible-year", "The Bible in a Year", "Every chapter, Old and New Testaments", 365, 1..66),
        PlanDefinition("nt-90", "New Testament in 90 Days", "Matthew through Revelation", 90, 40..66),
        PlanDefinition("gospels-60", "The Gospels in 60 Days", "Walk with Jesus through all four accounts", 60, 40..43),
        PlanDefinition("psalms-proverbs-31", "Psalms & Proverbs in 31 Days", "A month of wisdom and prayer", 31, 19..20),
        PlanDefinition("paul-30", "Paul in 30 Days", "Romans through Philemon", 30, 45..57),
        PlanDefinition("wisdom-30", "Wisdom Literature in 30 Days", "Job, Psalms, Proverbs, Ecclesiastes, Song", 30, 18..22)
    )

    fun definition(id: String): PlanDefinition? = definitions.firstOrNull { it.id == id }

    fun chapters(definition: PlanDefinition, books: List<Book>): List<ReadingLocation> {
        val out = mutableListOf<ReadingLocation>()
        for (book in books) {
            if (book.id !in definition.bookRange) continue
            for (chapter in 1..maxOf(1, book.chapters)) {
                out += ReadingLocation(book.id, chapter)
            }
        }
        return out
    }

    fun plan(definition: PlanDefinition, books: List<Book>): ReadingPlan {
        val chunks = distribute(chapters(definition, books), definition.days)
        val days = chunks.mapIndexed { index, readings ->
            PlanDay(definition.id, index + 1, readings, label(readings, books))
        }
        return ReadingPlan(definition.id, definition.name, definition.subtitle, days)
    }

    fun distribute(items: List<ReadingLocation>, dayCount: Int): List<List<ReadingLocation>> {
        if (dayCount <= 0) return emptyList()
        val base = items.size / dayCount
        val extra = items.size % dayCount
        val result = mutableListOf<List<ReadingLocation>>()
        var index = 0
        for (day in 0 until dayCount) {
            val size = base + if (day < extra) 1 else 0
            val end = minOf(items.size, index + size)
            result += items.subList(index, end).toList()
            index = end
        }
        return result
    }

    fun label(readings: List<ReadingLocation>, books: List<Book>): String {
        if (readings.isEmpty()) return "—"
        val parts = mutableListOf<String>()
        var i = 0
        while (i < readings.size) {
            val start = readings[i]
            var j = i
            while (j + 1 < readings.size &&
                readings[j + 1].book == start.book &&
                readings[j + 1].chapter == readings[j].chapter + 1
            ) {
                j++
            }
            val book = books.firstOrNull { it.id == start.book }?.name ?: ""
            parts += if (j > i) "$book ${start.chapter}–${readings[j].chapter}" else "$book ${start.chapter}"
            i = j + 1
        }
        return parts.joinToString(" · ")
    }
}
