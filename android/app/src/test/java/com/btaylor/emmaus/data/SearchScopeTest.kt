package com.btaylor.emmaus.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SearchScopeTest {

    @Test
    fun allMatchesBothTestaments() {
        assertTrue(SearchScope.All.matches(1))
        assertTrue(SearchScope.All.matches(66))
    }

    @Test
    fun testamentsSplitAtThirtyNine() {
        val old = SearchScope(SearchScopeKind.OLD)
        assertTrue(old.matches(39))
        assertFalse(old.matches(40))

        val new = SearchScope(SearchScopeKind.NEW)
        assertFalse(new.matches(39))
        assertTrue(new.matches(40))
    }

    @Test
    fun bookMatchesOnlyThatBook() {
        val psalms = SearchScope(SearchScopeKind.BOOK, 19)
        assertTrue(psalms.matches(19))
        assertFalse(psalms.matches(20))
    }

    @Test
    fun labels() {
        assertEquals("All", SearchScope.All.label("John"))
        assertEquals("Old Testament", SearchScope(SearchScopeKind.OLD).label(null))
        assertEquals("New Testament", SearchScope(SearchScopeKind.NEW).label(null))
        assertEquals("John", SearchScope(SearchScopeKind.BOOK, 43).label("John"))
    }
}
