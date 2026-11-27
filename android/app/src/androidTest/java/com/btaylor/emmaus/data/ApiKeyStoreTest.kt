package com.btaylor.emmaus.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Runs on a device: exercises the real Android Keystore. */
@RunWith(AndroidJUnit4::class)
class ApiKeyStoreTest {

    private val context: Context = ApplicationProvider.getApplicationContext()
    private val store = ApiKeyStore(context)

    @Test
    fun roundTripsAndClears() {
        store.clear()
        assertEquals("", store.read())

        store.write("test-key-123")
        assertEquals("test-key-123", store.read())

        store.clear()
        assertEquals("", store.read())
    }

    @Test
    fun nothingReadableIsWrittenToDisk() {
        store.clear()
        store.write("test-key-123")
        val file = File(context.filesDir, "api-key.bin")
        assertFalse(file.readText().contains("test-key-123"))
    }

    @Test
    fun blankValueClearsTheKey() {
        store.write("test-key-123")
        store.write("")
        assertEquals("", store.read())
    }
}
