package com.btaylor.emmaus.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SearchQueryTest {

    @Test
    fun bareWordGetsPrefixExpansion() {
        assertEquals("\"love\"*", SearchQuery.ftsExpression("love"))
    }

    @Test
    fun explicitAsteriskIsPrefix() {
        assertEquals("\"lov\"*", SearchQuery.ftsExpression("lov*"))
    }

    @Test
    fun andIsKept() {
        assertEquals("\"faith\" AND \"works\"*", SearchQuery.ftsExpression("faith AND works"))
    }

    @Test
    fun orIsKept() {
        assertEquals("\"love\" OR \"grace\"*", SearchQuery.ftsExpression("love OR grace"))
    }

    @Test
    fun phraseIsPreserved() {
        assertEquals("\"in the beginning\"", SearchQuery.ftsExpression("\"in the beginning\""))
    }

    @Test
    fun operatorsAloneAreDropped() {
        assertNull(SearchQuery.ftsExpression("AND"))
        assertNull(SearchQuery.ftsExpression("   "))
        assertEquals("\"love\"*", SearchQuery.ftsExpression("OR love"))
    }

    @Test
    fun trailingOperatorIsDropped() {
        assertEquals("\"faith\"", SearchQuery.ftsExpression("faith AND"))
    }

    @Test
    fun singleCharacterIsNotExpanded() {
        assertEquals("\"a\"", SearchQuery.ftsExpression("a"))
    }

    @Test
    fun punctuationIsNeverSyntax() {
        val expr = SearchQuery.ftsExpression("love\"; DROP TABLE verses; --")
        assertTrue(expr!!.contains("\"DROP\""))
        assertTrue(!expr.contains(";"))
    }

    @Test
    fun unbalancedQuoteStillSearches() {
        val expr = SearchQuery.ftsExpression("\"in the beginning")
        assertTrue(expr!!.contains("\"the\""))
    }

    @Test
    fun notIsKeptBetweenTerms() {
        assertEquals("\"faith\" NOT \"works\"*", SearchQuery.ftsExpression("faith NOT works"))
    }

    @Test
    fun queryIsCapped() {
        val expr = SearchQuery.ftsExpression("love ".repeat(200))
        assertTrue(expr!!.split(" AND ").size <= 45)
    }

    @Test
    fun literalTermsSkipPhrasesAndOperators() {
        assertEquals(listOf("love", "grace"), SearchQuery.literalTerms("love OR grace"))
        assertTrue(SearchQuery.literalTerms("\"in the beginning\"").isEmpty())
    }

    @Test
    fun unicodeLettersSurviveSanitizing() {
        assertEquals("Liebe", SearchQuery.sanitize("Liebe", allowSpaces = false))
        assertEquals("神", SearchQuery.sanitize("神", allowSpaces = false))
        assertNull(SearchQuery.sanitize("??", allowSpaces = false))
    }
}
