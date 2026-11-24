import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var user: UserStore
    @EnvironmentObject var speech: SpeechService

    @State private var endpoint = "https://rest.api.bible"
    @State private var apiKey = ""
    @State private var bibles: [String: String] = [:]
    @State private var showKey = false
    @State private var testing = false
    @State private var testMessage: String?
    @State private var testOK = false
    @State private var cacheChapters = 0
    @State private var cacheVerses = 0

    var body: some View {
        let t = app.theme
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                appearanceCard
                readingCard
                apiCard
                pronunciationCard
                dataCard
                aboutCard
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 30)
            .padding(.top, 20)
            .padding(.bottom, 30)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background(t.bg)
        .onAppear {
            loadAPI()
            let stats = user.cloudCacheStats()
            cacheChapters = stats.chapters
            cacheVerses = stats.verses
        }
    }

    private var header: some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(Typography.reading(size: 32, serif: true, weight: .semibold))
                .foregroundColor(t.ink)
            Text("Make the reading desk yours.")
                .font(.system(size: 12))
                .foregroundColor(t.secondary)
        }
    }

    private func card<Content: View>(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: title, theme: t)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundColor(t.secondary)
                }
            }
            content()
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 13).fill(t.card))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(t.border.opacity(0.7), lineWidth: 0.7))
    }

    private var appearanceCard: some View {
        let t = app.theme
        return card("Appearance") {
            HStack(spacing: 10) {
                ForEach(AppTheme.allCases) { th in
                    Button {
                        app.setTheme(th)
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(th.theme.bg)
                                .overlay(Circle().strokeBorder(th == app.themeName ? t.accent : t.border, lineWidth: th == app.themeName ? 2 : 1))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().fill(th.theme.accent).frame(width: 9, height: 9))
                            Text(th.name)
                                .font(.system(size: 8.5))
                                .foregroundColor(t.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            HStack(spacing: 12) {
                Text("Text size").font(.system(size: 11.5)).foregroundColor(t.secondary).frame(width: 66, alignment: .leading)
                Slider(value: $app.fontSize, in: 15...28, step: 1)
                Text("\(Int(app.fontSize))").font(.system(size: 10.5, weight: .medium)).foregroundColor(t.ink).frame(width: 22)
            }
            HStack(spacing: 12) {
                Text("Leading").font(.system(size: 11.5)).foregroundColor(t.secondary).frame(width: 66, alignment: .leading)
                Slider(value: $app.lineSpacing, in: 3...16, step: 1)
                Text("\(Int(app.lineSpacing))").font(.system(size: 10.5, weight: .medium)).foregroundColor(t.ink).frame(width: 22)
            }
            HStack(spacing: 20) {
                Toggle("Serif type", isOn: $app.serif)
                Toggle("Red letters", isOn: $app.showRedLetter)
                Toggle("Strong's underlines", isOn: $app.showStrongs)
                Toggle("Verse numbers", isOn: $app.showVerseNumbers)
            }
            .font(.system(size: 11.5))
            .toggleStyle(EmmausToggleStyle(theme: t))
        }
        .onChange(of: app.fontSize) { _, _ in app.saveSettings() }
        .onChange(of: app.lineSpacing) { _, _ in app.saveSettings() }
        .onChange(of: app.serif) { _, _ in app.saveSettings() }
        .onChange(of: app.showRedLetter) { _, _ in app.saveSettings() }
        .onChange(of: app.showStrongs) { _, _ in app.saveSettings() }
        .onChange(of: app.showVerseNumbers) { _, _ in app.saveSettings() }
    }

    private var readingCard: some View {
        let t = app.theme
        return card("Reading", subtitle: "Choose the translation that opens by default.") {
            HStack {
                Text("Default translation")
                    .font(.system(size: 11.5))
                    .foregroundColor(t.secondary)
                Spacer()
                Menu {
                    Section("Offline") {
                        ForEach(app.localTranslations) { tr in
                            Button("\(tr.short) — \(tr.name)") { app.changeTranslation(tr.code) }
                        }
                    }
                    Section("Connected") {
                        ForEach(app.remoteTranslations) { tr in
                            Button("\(tr.short) — \(tr.name)") { app.changeTranslation(tr.code) }
                        }
                    }
                } label: {
                    Text("\(app.activeTranslation.short) · \(app.activeTranslation.name)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(t.accent)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            Toggle("Show the study panel when a verse is selected", isOn: $app.showInspector)
                .font(.system(size: 11.5))
                .toggleStyle(EmmausToggleStyle(theme: t))
                .onChange(of: app.showInspector) { _, _ in app.saveSettings() }
        }
    }

    private var apiCard: some View {
        let t = app.theme
        return card("Connected Bibles", subtitle: "NIV, NASB, and NKJV are served by API.Bible under your key. Chapters are cached within the API's limits and refreshed every 30 days.") {
            HStack(spacing: 7) {
                Circle()
                    .fill(app.api.isConfigured ? Color.green.opacity(0.8) : t.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text(app.api.isConfigured ? "API.Bible configured" : "API.Bible not configured")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(app.api.isConfigured ? t.ink : t.secondary)
                Spacer()
                if app.api.isConfigured {
                    ForEach(app.remoteTranslations) { tr in
                        Pill(text: tr.short, theme: t)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Endpoint").font(.system(size: 10, weight: .medium)).foregroundColor(t.secondary)
                TextField("https://rest.api.bible", text: $endpoint)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(t.ink)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 7).fill(t.bg2.opacity(0.7)))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("API key").font(.system(size: 10, weight: .medium)).foregroundColor(t.secondary)
                HStack(spacing: 6) {
                    if showKey {
                        TextField("Your API.Bible key", text: $apiKey)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5, design: .monospaced))
                    } else {
                        SecureField("Your API.Bible key", text: $apiKey)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5, design: .monospaced))
                    }
                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                            .font(.system(size: 10))
                            .foregroundColor(t.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showKey ? "Hide API key" : "Show API key")
                }
                .foregroundColor(t.ink)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 7).fill(t.bg2.opacity(0.7)))
            }

            HStack(spacing: 10) {
                Button(testing ? "Testing…" : "Save & Test") { saveAPI() }
                    .buttonStyle(PrimaryButtonStyle(theme: t))
                    .disabled(testing)
                if let message = testMessage {
                    HStack(spacing: 5) {
                        Image(systemName: testOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 9.5))
                        Text(message)
                            .font(.system(size: 10.5))
                            .lineLimit(2)
                    }
                    .foregroundColor(testOK ? t.accent : t.red)
                }
                Spacer()
            }

            Divider().overlay(t.border.opacity(0.6))
            HStack {
                Text("Licensed chapters cached: \(cacheChapters) chapters · \(cacheVerses) verses")
                    .font(.system(size: 10))
                    .foregroundColor(t.secondary)
                Spacer()
                Button("Clear cache") {
                    user.clearCloudCache()
                    let stats = user.cloudCacheStats()
                    cacheChapters = stats.chapters
                    cacheVerses = stats.verses
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(t.accent)
            }
            Text("The full text of NIV, NASB, and NKJV is never bundled. Cache size is capped well below the API's 500-verse limit and is purged after 30 days.")
                .font(.system(size: 9.5))
                .foregroundColor(t.secondary.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pronunciationCard: some View {
        let t = app.theme
        return card("Pronunciation", subtitle: "Tap a sample to hear the installed macOS voice.") {
            voiceRow("Hebrew", "he", "בְּרֵאשִׁית", "bereshit", theme: t)
            voiceRow("Greek", "grc", "ἀγάπη", "agapē", theme: t)
            voiceRow("Latin", "la", "In principio", "in prin-KEE-pee-oh", theme: t)
            voiceRow("Arabic", "ar", "فِي ٱلْبَدْءِ", "fī l-badʾ", theme: t)
            Text("Hebrew and Greek use modern Israeli and Greek voices. Latin uses an Italian voice for ecclesiastical pronunciation. For the best quality, download enhanced voices in System Settings → Accessibility → Spoken Content → Manage Voices.")
                .font(.system(size: 9.5))
                .foregroundColor(t.secondary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func voiceRow(_ name: String, _ code: String, _ sample: String, _ translit: String, theme t: Theme) -> some View {
        let voice = SpeechService.voice(for: code)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(t.ink)
                Text(voice.map { "\($0.name) · \($0.language)" } ?? "No voice installed")
                    .font(.system(size: 9.5))
                    .foregroundColor(t.secondary)
            }
            Spacer()
            Text(sample)
                .font(.system(size: 15))
                .foregroundColor(t.secondary)
                .environment(\.layoutDirection, (code == "he" || code == "ar") ? .rightToLeft : .leftToRight)
            Text(translit)
                .font(Typography.reading(size: 10.5, serif: true, italic: true))
                .foregroundColor(t.secondary.opacity(0.7))
                .frame(width: 110, alignment: .leading)
            Button {
                speech.speakWord(sample, language: code)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundColor(t.card)
                    .frame(width: 24, height: 22)
                    .background(Circle().fill(t.accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play pronunciation")
            Button {
                speech.speakWord(sample, language: code, slow: true)
            } label: {
                Text("slow")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(t.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
    }

    private var dataCard: some View {
        let t = app.theme
        let attrs = try? FileManager.default.attributesOfItem(atPath: app.bible.db.path)
        let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
        return card("Data", subtitle: "Everything personal lives in a local SQLite file. Nothing is uploaded.") {
            HStack(spacing: 18) {
                dataStat("\(user.notes.count)", "notes", t)
                dataStat("\(user.highlights.count)", "highlights", t)
                dataStat("\(user.bookmarks.count)", "bookmarks", t)
                dataStat("\(user.chaptersRead)", "chapters read", t)
                Spacer()
            }
            HStack(spacing: 10) {
                Button("Export notes as Markdown") { exportNotes() }
                    .buttonStyle(SoftButtonStyle(theme: t))
                Button("Open data folder") {
                    NSWorkspace.shared.open(AppPaths.supportDirectory)
                }
                .buttonStyle(SoftButtonStyle(theme: t))
                Spacer()
                Text("Library \(size / 1_000_000) MB")
                    .font(.system(size: 9.5))
                    .foregroundColor(t.secondary)
            }
        }
    }

    private func dataStat(_ value: String, _ label: String, _ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(Typography.reading(size: 18, serif: true, weight: .semibold))
                .foregroundColor(t.ink)
            Text(label)
                .font(.system(size: 8.5))
                .foregroundColor(t.secondary)
        }
    }

    private var aboutCard: some View {
        let t = app.theme
        return card("About Emmaus") {
            Text("Emmaus 1.0 · a personal study Bible for macOS")
                .font(Typography.reading(size: 15, serif: true, weight: .medium))
                .foregroundColor(t.ink)
            Text("""
            Scripture: King James Version with Strong's numbers and red letters (Open Scriptures), Berean Standard Bible, World English Bible, American Standard Version, Young's Literal Translation, Westminster Leningrad Codex, Greek New Testament (STEPBible TAGNT), Textus Receptus, Byzantine Textform, Clementine Vulgate, and Arabic Van Dyck.

            Study data: STEPBible (CC BY 4.0, Tyndale House Cambridge), Open Scriptures Strong's dictionaries (CC BY-SA), openbible.info cross references (CC BY), Matthew Henry, Jamieson–Fausset–Brown, Geneva notes (public domain), Tyndale Open Study Notes (CC BY-SA), Nave's Topical Bible, Easton, Smith, and Hitchcock dictionaries.

            Licensed translations (NIV, NASB, NKJV) are retrieved through API.Bible with your key. Their copyright notices are shown in the reader. They are not included in the app bundle.
            """)
                .font(.system(size: 10))
                .foregroundColor(t.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - actions

    private func loadAPI() {
        if let cfg = APIConfig.load() {
            endpoint = cfg.endpoint
            apiKey = cfg.key
            bibles = cfg.bibles
        } else {
            bibles = ["NIV": "78a9f6124f344018-01", "NASB": "a761ca71e0b3ddcf-01", "NKJV": "63097d2a0a2f7db3-01"]
        }
    }

    private func saveAPI() {
        if bibles.isEmpty {
            bibles = ["NIV": "78a9f6124f344018-01", "NASB": "a761ca71e0b3ddcf-01", "NKJV": "63097d2a0a2f7db3-01"]
        }
        let cfg = APIConfig(endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
                            key: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                            bibles: bibles)
        do {
            try cfg.save()
            app.api.reload()
            testAPI()
        } catch {
            testMessage = error.localizedDescription
            testOK = false
        }
    }

    private func testAPI() {
        testing = true
        testMessage = nil
        Task {
            let result = await app.api.testConnection()
            await MainActor.run {
                testing = false
                switch result {
                case .success(let count):
                    testOK = true
                    testMessage = "Connected · \(count) English Bibles available"
                case .failure(let error):
                    testOK = false
                    testMessage = error.localizedDescription
                }
            }
        }
    }

    private func exportNotes() {
        let markdown = user.exportMarkdown { app.bible.book($0)?.name ?? "Book \($0)" }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Emmaus Notes.md"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
            app.toastMessage("Notes exported")
        }
    }
}
