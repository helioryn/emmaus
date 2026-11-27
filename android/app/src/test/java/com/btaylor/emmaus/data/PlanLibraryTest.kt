package com.btaylor.emmaus.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PlanLibraryTest {

    private fun books() = listOf(
        Book(1, "Genesis", "Gen", "OT", "Law", 50),
        Book(2, "Exodus", "Exod", "OT", "Law", 40),
        Book(19, "Psalms", "Ps", "OT", "Wisdom", 150),
        Book(43, "John", "John", "NT", "Gospel", 21)
    )

    private fun locations(count: Int) =
        (1..count).map { ReadingLocation(1, it) }

    @Test
    fun distributeSplitsEvenly() {
        val days = PlanLibrary.distribute(locations(10), 3)
        assertEquals(3, days.size)
        assertEquals(listOf(4, 3, 3), days.map { it.size })
        assertEquals(10, days.flatten().size)
    }

    @Test
    fun distributePadsShortPlans() {
        val days = PlanLibrary.distribute(locations(2), 5)
        assertEquals(listOf(1, 1, 0, 0, 0), days.map { it.size })
    }

    @Test
    fun distributeRejectsZeroDays() {
        assertTrue(PlanLibrary.distribute(locations(3), 0).isEmpty())
    }

    @Test
    fun distributePreservesOrder() {
        val items = locations(7)
        val flattened = PlanLibrary.distribute(items, 3).flatten()
        assertEquals(items.map { it.chapter }, flattened.map { it.chapter })
    }

    @Test
    fun chaptersOnlyCoversThePlanRange() {
        val definition = PlanDefinition("nt", "NT", "", 10, 40..66)
        val chapters = PlanLibrary.chapters(definition, books())
        assertEquals(21, chapters.size)
        assertTrue(chapters.all { it.book == 43 })
    }

    @Test
    fun planHasOneDayPerRequestedDay() {
        val definition = PlanLibrary.definitions.first { it.id == "bible-year" }
        val plan = PlanLibrary.plan(definition, books())
        assertEquals(365, plan.days.size)
        assertEquals(1, plan.days.first().day)
        assertEquals(365, plan.days.last().day)
    }

    @Test
    fun labelCollapsesConsecutiveChapters() {
        val readings = listOf(ReadingLocation(19, 23), ReadingLocation(19, 24))
        assertEquals("Psalms 23–24", PlanLibrary.label(readings, books()))
    }

    @Test
    fun labelHandlesEmptyDay() {
        assertEquals("—", PlanLibrary.label(emptyList(), books()))
    }
}
