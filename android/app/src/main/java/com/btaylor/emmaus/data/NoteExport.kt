package com.btaylor.emmaus.data

import java.time.LocalDate

/** Markdown copy of the notebook; kept pure so it can be tested without Android. */
object NoteExport {
    fun markdown(
        notes: List<BookNote>,
        bookmarkKeys: List<String>,
        bookName: (Int) -> String,
        today: LocalDate = LocalDate.now()
    ): String {
        val out = StringBuilder("# Emmaus Study Notes\n\n")
        out.append("_Exported ${today}_\n\n")

        val grouped = notes.groupBy { it.book }
        for (book in grouped.keys.sorted()) {
            out.append("## ${bookName(book)}\n\n")
            grouped[book]?.sortedWith(compareBy({ it.chapter }, { it.verse }))?.forEach { note ->
                out.append("### ${bookName(note.book)} ${note.chapter}:${note.verse}\n\n")
                out.append(note.body.trim()).append("\n\n")
            }
        }

        if (bookmarkKeys.isNotEmpty()) {
            out.append("## Bookmarks\n\n")
            for (key in bookmarkKeys) {
                val parts = key.split("-")
                if (parts.size != 3) continue
                val book = parts[0].toIntOrNull() ?: continue
                val chapter = parts[1].toIntOrNull() ?: continue
                val verse = parts[2].toIntOrNull() ?: continue
                out.append("- ${bookName(book)} $chapter:$verse\n")
            }
        }
        return out.toString()
    }
}
