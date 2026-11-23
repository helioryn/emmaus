package com.btaylor.emmaus.audio

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.util.Locale

class TtsManager(context: Context) : TextToSpeech.OnInitListener {
    private val tts = TextToSpeech(context.applicationContext, this)
    private val main = Handler(Looper.getMainLooper())

    var ready by mutableStateOf(false)
        private set
    var speaking by mutableStateOf(false)
        private set
    var currentVerse by mutableStateOf<Int?>(null)
        private set

    private var queue: List<Pair<Int, String>> = emptyList()
    private var index = 0
    private var languageCode = "en"

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts.language = Locale.US
            ready = true
            tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) {
                    main.post {
                        if (queue.isNotEmpty() && index + 1 < queue.size) {
                            index += 1
                            speakCurrent()
                        } else {
                            stopState()
                        }
                    }
                }
                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    main.post { stopState() }
                }
            })
        }
    }

    private fun stopState() {
        speaking = false
        currentVerse = null
        queue = emptyList()
    }

    fun localeFor(code: String): Locale = when (code) {
        "he" -> Locale("he", "IL")
        "grc", "el" -> Locale("el", "GR")
        "ar" -> Locale("ar", "SA")
        "la" -> Locale.ITALIAN
        else -> Locale.US
    }

    private fun applyLanguage(code: String) {
        val locale = localeFor(code)
        val result = tts.setLanguage(locale)
        if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
            tts.setLanguage(Locale.US)
        }
    }

    fun speakWord(text: String, code: String, slow: Boolean = false) {
        if (!ready || text.isBlank()) return
        tts.stop()
        stopState()
        applyLanguage(code)
        val id = "word-${System.currentTimeMillis()}"
        speaking = true
        val params = android.os.Bundle()
        tts.setSpeechRate(if (slow) 0.65f else 0.9f)
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, params, id)
        main.postDelayed({
            if (speaking && queue.isEmpty()) speaking = false
        }, 1400)
    }

    fun speakChapter(verses: List<Pair<Int, String>>, code: String) {
        if (!ready || verses.isEmpty()) return
        tts.stop()
        stopState()
        languageCode = code
        applyLanguage(code)
        queue = verses
        index = 0
        speaking = true
        tts.setSpeechRate(0.95f)
        speakCurrent()
    }

    private fun speakCurrent() {
        if (index >= queue.size) {
            stopState()
            return
        }
        val (verse, text) = queue[index]
        currentVerse = verse
        val params = android.os.Bundle()
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, params, "verse-$verse-${System.currentTimeMillis()}")
    }

    fun stop() {
        tts.stop()
        stopState()
    }

    fun shutdown() {
        tts.stop()
        tts.shutdown()
    }

    fun languageStatus(code: String): String {
        if (!ready) return "TTS starting…"
        val locale = localeFor(code)
        return if (tts.isLanguageAvailable(locale) >= TextToSpeech.LANG_AVAILABLE) {
            "Available (${locale.toLanguageTag()})"
        } else {
            "Voice not installed (${locale.toLanguageTag()})"
        }
    }
}
