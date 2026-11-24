package com.btaylor.emmaus.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class ExportSanitizerTest {

    @Test
    fun apiKeyIsRemovedFromExports() {
        val settings = mapOf(
            "apiKey" to "not-a-real-key",
            "translation" to "KJV",
            "fontSize" to "19"
        )
        val exported = UserStore.exportableSettings(settings)
        assertFalse(exported.containsKey("apiKey"))
        assertEquals("KJV", exported["translation"])
        assertEquals("19", exported["fontSize"])
    }

    @Test
    fun otherSecretShapedKeysAreRemoved() {
        val settings = mapOf(
            "api_key" to "x",
            "API-KEY" to "x",
            "syncToken" to "x",
            "notePassword" to "x",
            "clientSecret" to "x",
            "theme" to "parchment"
        )
        val exported = UserStore.exportableSettings(settings)
        assertEquals(setOf("theme"), exported.keys)
    }
}
