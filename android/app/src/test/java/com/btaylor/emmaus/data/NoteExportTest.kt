package com.btaylor.emmaus.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class NoteExportTest {

    private val books = ComicBookNames

    private fun name(id: Int) = books[id] ?: "Book $id"

    @Test
    fun notesAreGroupedAndSorted() {
        val notes = listOf(
            BookNote(43, 3, 16, "For God so loved", 0),
            BookNote(43, 1, 1, "In the beginning", 0),
            BookNote(19, 23, 1, "The Lord is my shepherd", 0)
        )
        val md = NoteExport.markdown(notes, emptyList(), ::name, LocalDate.of(2026, 11, 27))
        assertTrue(md.startsWith("# Emmaus Study Notes"))
        assertTrue(md.contains("_Exported 2026-11-27_"))
        assertTrue(md.indexOf("## Psalms") < md.indexOf("## John"))
        assertTrue(md.indexOf("### John 1:1") < md.indexOf("### John 3:16"))
    }

    @Test
    fun bookmarksAreListed() {
        val md = NoteExport.markdown(emptyList(), listOf("43-3-16"), ::name, LocalDate.of(2026, 1, 1))
        assertTrue(md.contains("## Bookmarks"))
        assertTrue(md.contains("- John 3:16"))
    }

    @Test
    fun noteBodiesAreTrimmed() {
        val md = NoteExport.markdown(listOf(BookNote(1, 1, 1, "  kept  \n", 0)), emptyList(), ::name)
        assertTrue(md.contains("### Genesis 1:1"))
        assertTrue(md.contains("kept\n\n"))
    }

    @Test
    fun emptyNotebookStillProducesAHeading() {
        val md = NoteExport.markdown(emptyList(), emptyList(), ::name, LocalDate.of(2026, 1, 1))
        assertEquals("# Emmaus Study Notes\n\n_Exported 2026-01-01_\n\n", md)
    }
}
