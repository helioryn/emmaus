import Foundation
import AVFoundation

final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    @Published var currentVerse: Int?
    @Published var lastError: String?

    private let synth = AVSpeechSynthesizer()
    private var queue: [(Int, String)] = []
    private var queueLanguage = "en"
    private var isChapter = false
    private var currentIndex = 0
    private var isWord = false

    override init() {
        super.init()
        synth.delegate = self
    }

    static func normalizedLanguage(_ code: String) -> String {
        switch code {
        case "he": return "he-IL"
        case "grc", "el": return "el-GR"
        case "ar": return "ar-SA"
        case "la": return "it-IT"
        case "en": return "en-US"
        default: return code
        }
    }

    static func voice(for code: String) -> AVSpeechSynthesisVoice? {
        let lang = normalizedLanguage(code)
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(String(lang.prefix(2))) }
        guard !voices.isEmpty else { return AVSpeechSynthesisVoice(language: lang) }
        return voices.sorted { a, b in
            rank(a) > rank(b)
        }.first
    }

    private static func rank(_ v: AVSpeechSynthesisVoice) -> Int {
        var r = 0
        switch v.quality {
        case .premium: r += 30
        case .enhanced: r += 20
        default: r += 10
        }
        if v.language.contains("US") { r += 2 }
        if v.name.contains("Samantha") || v.name.contains("Ava") { r += 3 }
        return r
    }

    var voiceDescription: String {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let groups = ["he-IL": "Hebrew", "el-GR": "Greek", "ar": "Arabic", "it-IT": "Latin (Italian voice)"]
        var lines: [String] = []
        for (code, name) in groups {
            if let v = voices.first(where: { $0.language.hasPrefix(String(code.prefix(2))) && code != "it-IT" }) ?? voices.first(where: { $0.language == code }) {
                lines.append("\(name): \(v.name) (\(v.language))")
            } else {
                lines.append("\(name): not installed — download in System Settings → Accessibility → Spoken Content → System Voice → Manage Voices")
            }
        }
        return lines.joined(separator: "\n")
    }

    func speakWord(_ word: String, language: String, slow: Bool = false) {
        stop()
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        isWord = true
        isChapter = false
        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = Self.voice(for: language)
        utterance.rate = slow ? 0.27 : 0.38
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.05
        isSpeaking = true
        synth.speak(utterance)
    }

    func speakChapter(_ verses: [(Int, String)], language: String) {
        stop()
        guard !verses.isEmpty else { return }
        isWord = false
        isChapter = true
        queue = verses
        queueLanguage = language
        currentIndex = 0
        isSpeaking = true
        speakNextInQueue()
    }

    private func speakNextInQueue() {
        guard isChapter, currentIndex < queue.count else {
            finish()
            return
        }
        let (verse, text) = queue[currentIndex]
        currentVerse = verse
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(for: queueLanguage)
        utterance.rate = 0.46
        utterance.pitchMultiplier = 0.98
        utterance.postUtteranceDelay = 0.28
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        queue = []
        currentVerse = nil
        isSpeaking = false
    }

    private func finish() {
        isSpeaking = false
        isChapter = false
        isWord = false
        currentVerse = nil
        queue = []
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if isChapter {
            currentIndex += 1
            speakNextInQueue()
        } else if isWord {
            finish()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finish()
    }
}
