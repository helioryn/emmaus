import SwiftUI
import AppKit

struct StudyPanel: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var user: UserStore
    @EnvironmentObject var speech: SpeechService

    @State private var crossRefs: [CrossRef] = []
    @State private var commentary: [CommentaryEntry] = []
    @State private var interlinear: [InterlinearWord] = []
    @State private var verseWords: [StrongsEntry] = []
    @State private var noteText = ""
    @State private var noteLoaded = false
    @State private var selectedWork = ""
    @State private var remoteVerses: [String: String] = [:]
    @State private var remoteLoading: Set<String> = []
    @State private var showAllOccurrences = false
    @FocusState private var noteFocused: Bool

    private var refKey: String {
        "\(app.bookId)-\(app.chapter)-\(app.selectedVerse ?? 0)-\(app.selectedStrongs ?? "")-\(app.translationCode)"
    }

    var body: some View {
        let t = app.theme
        VStack(spacing: 0) {
            header
            if app.selectedVerse != nil {
                tabBar
                Divider().overlay(t.border.opacity(0.6))
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch app.inspectorTab {
                        case .study: studyTab
                        case .word: wordTab
                        case .interlinear: interlinearTab
                        case .compare: compareTab
                        case .commentary: commentaryTab
                        case .notes: notesTab
                        }
                    }
                    .padding(16)
                }
            } else {
                EmptyState(icon: "cursorarrow.click.2", title: "Select a verse",
                           message: "Click any verse number or word to open cross-references, commentary, the original language, and your notes.",
                           theme: t)
            }
        }
        .frame(width: 376)
        .background(t.panel)
        .task(id: refKey) { reload() }
        .onChange(of: app.inspectorTab) { _, tab in
            if tab == .notes { loadNote() }
        }
        .onChange(of: app.noteFocusRequest) { _, _ in
            app.inspectorTab = .notes
            loadNote()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { noteFocused = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        let t = app.theme
        let ref = ReferenceParser.label(book: app.bookId, chapter: app.chapter, verse: app.selectedVerse)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "Study", theme: t)
                Spacer()
                if app.selectedVerse != nil {
                    Button {
                        app.toggleBookmark()
                    } label: {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 12))
                            .foregroundColor(isBookmarked ? t.accent : t.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Bookmark")
                    Button {
                        app.requestNoteFocus()
                    } label: {
                        Image(systemName: user.note(book: app.bookId, chapter: app.chapter, verse: app.selectedVerse ?? 0) == nil ? "note.text" : "note.text.badge.plus")
                            .font(.system(size: 12))
                            .foregroundColor(t.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add note")
                }
                Button {
                    app.showInspector = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(t.secondary)
                }
                .buttonStyle(.plain)
            }
            Text(ref)
                .font(Typography.reading(size: 23, serif: true, weight: .semibold))
                .foregroundColor(t.ink)
            if let text = app.selectedVerseText {
                Text(text)
                    .font(Typography.reading(size: 13, serif: true))
                    .foregroundColor(t.secondary)
                    .lineSpacing(3)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var isBookmarked: Bool {
        guard let v = app.selectedVerse else { return false }
        return user.isBookmarked(book: app.bookId, chapter: app.chapter, verse: v)
    }

    // MARK: - Tabs

    private var tabBar: some View {
        let t = app.theme
        return HStack(spacing: 0) {
            ForEach(InspectorTab.allCases) { tab in
                Button {
                    app.inspectorTab = tab
                    if tab == .notes { loadNote() }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11.5, weight: .medium))
                        Text(tab.title)
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .foregroundColor(app.inspectorTab == tab ? t.accent : t.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .overlay(alignment: .bottom) {
                        if app.inspectorTab == tab {
                            Rectangle().fill(t.accent).frame(height: 1.5)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Study tab

    private var studyTab: some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 16) {
            if !crossRefs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionLabel(text: "Cross References", theme: t)
                        Spacer()
                        Text("\(crossRefs.count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(t.secondary)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(crossRefs.prefix(18))) { ref in
                            CrossRefRow(ref: ref, theme: t) {
                                app.open(book: ref.toBook, chapter: ref.toChapter, verse: ref.toVerseStart)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
                }
            }

            if !commentary.isEmpty {
                Button {
                    app.inspectorTab = .commentary
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 13))
                            .foregroundColor(t.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Commentary")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(t.ink)
                            Text(commentary.map { BibleStore.commentaryNames[$0.work] ?? $0.work }.uniqued().joined(separator: " · "))
                                .font(.system(size: 9.5))
                                .foregroundColor(t.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                            .foregroundColor(t.secondary)
                    }
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Theologians", theme: t)
                VStack(spacing: 0) {
                    ForEach(app.theologianLinks()) { link in
                        Button {
                            app.openInBrowser(link.url)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(link.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(t.ink)
                                    Text(link.subtitle)
                                        .font(.system(size: 10))
                                        .foregroundColor(t.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(t.secondary)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if link.id != "Bible Hub" {
                            Divider().overlay(t.border.opacity(0.5)).padding(.leading, 11)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
                Text("Opens the passage in your browser. MacArthur's study notes are copyrighted and are not bundled.")
                    .font(.system(size: 9.5))
                    .foregroundColor(t.secondary.opacity(0.8))
            }
        }
    }

    private var commentarySection: some View {
        let t = app.theme
        let works = Array(Set(commentary.map { $0.work })).sorted()
        let current = works.contains(selectedWork) ? selectedWork : preferredWork(works)
        let entries = commentary.filter { $0.work == current }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "Commentary", theme: t)
                Spacer()
                Menu {
                    ForEach(works, id: \.self) { w in
                        Button(BibleStore.commentaryNames[w] ?? w) {
                            selectedWork = w
                        }
                    }
                } label: {
                    Text(BibleStore.commentaryNames[current] ?? current)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(t.accent)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(entries) { e in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(ReferenceParser.label(book: e.book, chapter: e.chapter, verse: e.verseStart))
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(t.accent)
                        Text(e.body)
                            .font(Typography.reading(size: 12.5, serif: true))
                            .foregroundColor(t.ink.opacity(0.92))
                            .lineSpacing(3.5)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
        }
    }

    // MARK: - Word tab

    private var wordTab: some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 14) {
            if let id = app.selectedStrongs, let entry = app.bible.strongs(id: id) {
                wordEntry(entry)
                if !verseWords.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        SectionLabel(text: "Words in this verse", theme: t)
                        FlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(verseWords) { w in
                                Button {
                                    app.lookupStrongs(w.id)
                                } label: {
                                    HStack(spacing: 3) {
                                        Text(w.id)
                                            .font(.system(size: 10.5, weight: .semibold))
                                        if !w.gloss.isEmpty {
                                            Text(w.gloss.prefix(22))
                                                .font(.system(size: 10))
                                        }
                                    }
                                    .foregroundColor(w.id == id ? t.card : t.accent)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(w.id == id ? t.accent : t.accent.opacity(0.09)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else if verseWords.isEmpty {
                EmptyState(icon: "character.book.closed", title: "No Strong's data",
                           message: "This translation is not tagged. Switch to KJV to tap words and study the original language.", theme: t)
                    .frame(height: 220)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    SectionLabel(text: "Words in this verse", theme: t)
                    ForEach(verseWords) { w in
                        Button {
                            app.lookupStrongs(w.id)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(w.id)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(t.accent)
                                    .frame(width: 44, alignment: .leading)
                                Text(w.lemma)
                                    .font(w.isHebrew ? .system(size: 18) : .system(size: 15))
                                    .foregroundColor(t.ink)
                                Text(w.translit)
                                    .font(.system(size: 11, design: .serif))
                                    .foregroundColor(t.secondary)
                                Spacer()
                                Text(w.gloss)
                                    .font(.system(size: 10.5))
                                    .foregroundColor(t.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
            }
        }
    }

    private func wordEntry(_ e: StrongsEntry) -> some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(e.id)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(t.accent)
                        Text(e.languageName)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(t.secondary)
                    }
                    Text(e.lemma)
                        .font(.system(size: e.isHebrew ? 34 : 28))
                        .foregroundColor(t.ink)
                        .environment(\.layoutDirection, e.isHebrew ? .rightToLeft : .leftToRight)
                    HStack(spacing: 8) {
                        Text(e.translit)
                            .font(Typography.reading(size: 16, serif: true, italic: true))
                            .foregroundColor(t.secondary)
                        if !e.pronounce.isEmpty {
                            Text("· \(e.pronounce)")
                                .font(.system(size: 11))
                                .foregroundColor(t.secondary.opacity(0.8))
                        }
                    }
                }
                Spacer()
                VStack(spacing: 5) {
                    Button {
                        speech.speakWord(e.lemma, language: e.languageCode)
                    } label: {
                        Label("Say", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(t.card)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(t.accent))
                    }
                    .buttonStyle(.plain)
                    Button {
                        speech.speakWord(e.lemma, language: e.languageCode)
                    } label: {
                        Text("slow").font(.system(size: 9.5)).foregroundColor(t.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Slow playback")
                }
            }

            if !e.gloss.isEmpty {
                Text(e.gloss)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(t.ink)
            }
            if !e.definition.isEmpty {
                Text(e.definition)
                    .font(Typography.reading(size: 12.5, serif: true))
                    .foregroundColor(t.ink.opacity(0.9))
                    .lineSpacing(3.2)
                    .textSelection(.enabled)
            }
            if !e.derivation.isEmpty {
                Text(e.derivation)
                    .font(.system(size: 11))
                    .foregroundColor(t.secondary)
                    .textSelection(.enabled)
            }
            if !e.kjvUsage.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    SectionLabel(text: "KJV usage", theme: t)
                    Text(e.kjvUsage)
                        .font(.system(size: 11.5))
                        .foregroundColor(t.secondary)
                        .textSelection(.enabled)
                }
            }
            if !e.morph.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    SectionLabel(text: "Morphology", theme: t)
                    HStack(spacing: 6) {
                        Pill(text: e.morph, theme: t)
                        if let exp = app.bible.morphExpansion(e.morph) {
                            Text(exp)
                                .font(.system(size: 10.5))
                                .foregroundColor(t.secondary)
                        }
                    }
                }
            }

            let family = app.bible.strongsFamily(id: e.id).filter { $0.id != e.id }
            if !family.isEmpty {
                DisclosureGroup("Related senses (\(family.count))") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(family) { f in
                            Button {
                                app.lookupStrongs(f.id)
                            } label: {
                                HStack(alignment: .top, spacing: 6) {
                                    Text(f.id).font(.system(size: 9.5, weight: .semibold)).foregroundColor(t.accent)
                                    Text(f.gloss.isEmpty ? String(f.definition.prefix(120)) : f.gloss)
                                        .font(.system(size: 11))
                                        .foregroundColor(t.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 5)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(t.ink)
            }

            occurrencesSection(e)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(t.card))
    }

    private func occurrencesSection(_ e: StrongsEntry) -> some View {
        let t = app.theme
        let occ = app.bible.occurrences(strongs: e.id, limit: showAllOccurrences ? 500 : 40)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(text: "Concordance", theme: t)
                Spacer()
                Text("\(app.bible.occurrenceCount(strongs: e.id)) occurrences")
                    .font(.system(size: 9.5))
                    .foregroundColor(t.secondary)
            }
            VStack(spacing: 0) {
                ForEach(occ) { o in
                    Button {
                        app.open(book: o.book, chapter: o.chapter, verse: o.verse)
                    } label: {
                        HStack(spacing: 8) {
                            Text(ReferenceParser.label(book: o.book, chapter: o.chapter, verse: o.verse))
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(t.accent)
                                .frame(width: 104, alignment: .leading)
                            Text(o.form)
                                .font(Typography.reading(size: 11.5, serif: true, italic: true))
                                .foregroundColor(t.ink.opacity(0.85))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if !showAllOccurrences && app.bible.occurrenceCount(strongs: e.id) > 40 {
                Button("Show all occurrences") { showAllOccurrences = true }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(t.accent)
                    .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Interlinear

    private var interlinearTab: some View {
        let t = app.theme
        let isHebrew = interlinear.first?.isHebrew ?? false
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: isHebrew ? "Hebrew Interlinear" : "Greek Interlinear", theme: t)
                Spacer()
                if !interlinear.isEmpty {
                    Button {
                        let text = interlinear.map { $0.text }.joined(separator: " ")
                        speech.speakWord(text, language: isHebrew ? "he" : "grc")
                    } label: {
                        Image(systemName: "speaker.wave.2").font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(t.accent)
                }
            }
            if interlinear.isEmpty {
                EmptyState(icon: "textformat.abc.dottedunderline", title: "No interlinear text",
                           message: "Original-language word data is available for every Hebrew and Greek verse in the library.", theme: t)
                    .frame(height: 220)
            } else {
                VStack(spacing: 0) {
                    ForEach(interlinear) { w in
                        HStack(alignment: .top, spacing: 7) {
                            Button {
                                speech.speakWord(w.text, language: w.lang)
                            } label: {
                                Image(systemName: "speaker.wave.1")
                                    .font(.system(size: 9))
                                    .foregroundColor(t.secondary.opacity(0.7))
                                    .frame(width: 16, height: 20)
                            }
                            .buttonStyle(.plain)
                            Text(w.text)
                                .font(.system(size: isHebrew ? 19 : 16))
                                .foregroundColor(t.ink)
                                .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
                                .frame(minWidth: 78, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(w.translit)
                                    .font(Typography.reading(size: 11.5, serif: true, italic: true))
                                    .foregroundColor(t.accent.opacity(0.85))
                                Text(w.gloss)
                                    .font(.system(size: 10.5))
                                    .foregroundColor(t.secondary)
                            }
                            Spacer(minLength: 2)
                            VStack(alignment: .trailing, spacing: 2) {
                                if !w.strongs.isEmpty {
                                    Button(w.strongs) { app.lookupStrongs(w.strongs) }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(t.accent)
                                }
                                Text(Morph.short(w.morph))
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundColor(t.secondary.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 5)
                        if w.id != interlinear.last?.id {
                            Divider().overlay(t.border.opacity(0.45))
                        }
                    }
                }
                .padding(.horizontal, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
                Text("Tap a speaker to hear the word. Hebrew uses a modern Israeli voice; Greek uses a modern Greek voice.")
                    .font(.system(size: 9.5))
                    .foregroundColor(t.secondary.opacity(0.8))
            }
        }
    }

    // MARK: - Compare

    private var compareTab: some View {
        let t = app.theme
        let verse = app.selectedVerse ?? 1
        let locals = app.localTranslations.filter { !$0.hasInterlinear && !["HEB","GRC","TR","BYZ"].contains($0.code) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Compare Translations", theme: t)
                Spacer()
                if !app.remoteTranslations.isEmpty {
                    Button("Load connected") { loadRemoteVerses(verse: verse) }
                        .font(.system(size: 10, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundColor(t.accent)
                }
            }
            ForEach(locals) { tr in
                if let text = app.bible.verseText(translation: tr.code, book: app.bookId, chapter: app.chapter, verse: verse) {
                    compareRow(tr: tr, text: text)
                }
            }
            ForEach(app.remoteTranslations) { tr in
                if let text = remoteVerses[tr.code] {
                    compareRow(tr: tr, text: text)
                } else {
                    HStack(spacing: 8) {
                        Pill(text: tr.short, theme: t)
                        Text(remoteLoading.contains(tr.code) ? "Loading…" : "Connected translation")
                            .font(.system(size: 10.5))
                            .foregroundColor(t.secondary)
                        Spacer()
                        if !remoteLoading.contains(tr.code) {
                            Button("Fetch") { loadRemoteVerse(tr, verse: verse) }
                                .buttonStyle(.plain)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(t.accent)
                        } else {
                            ProgressView().controlSize(.mini)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 9).fill(t.card))
                }
            }
            if let remote = app.remoteTranslations.first(where: { remoteVerses[$0.code] != nil }) {
                Text(remote.attribution)
                    .font(.system(size: 9))
                    .foregroundColor(t.secondary.opacity(0.75))
            }
        }
    }

    private func compareRow(tr: Translation, text: String) -> some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Pill(text: tr.short, theme: t)
                Text(tr.name)
                    .font(.system(size: 9.5))
                    .foregroundColor(t.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    speech.speakWord(text, language: tr.langCode)
                } label: {
                    Image(systemName: "speaker.wave.1").font(.system(size: 9.5))
                }
                .buttonStyle(.plain)
                .foregroundColor(t.secondary)
            }
            Text(text)
                .font(Typography.reading(size: 12.5, serif: true))
                .foregroundColor(t.ink.opacity(0.92))
                .lineSpacing(2.5)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(t.card))
    }

    // MARK: - Commentary

    private var commentaryTab: some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 14) {
            if commentary.isEmpty {
                EmptyState(icon: "book.pages", title: "No commentary here",
                           message: "This verse is not covered by the installed commentary modules.", theme: t)
                    .frame(height: 220)
            } else {
                commentarySection
                Text("Matthew Henry, Jamieson–Fausset–Brown, Geneva, Scofield, and Tyndale Open Study Notes are public domain or openly licensed. MacArthur's study notes are copyrighted and are linked, not bundled.")
                    .font(.system(size: 9.5))
                    .foregroundColor(t.secondary.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Notes

    private var notesTab: some View {
        let t = app.theme
        let verse = app.selectedVerse ?? 1
        let existing = user.note(book: app.bookId, chapter: app.chapter, verse: verse)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Your Note", theme: t)
                Spacer()
                if existing != nil {
                    Button("Delete") {
                        if let n = existing {
                            user.deleteNote(n)
                            noteText = ""
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(t.red.opacity(0.8))
                }
            }
            TextEditor(text: $noteText)
                .font(Typography.reading(size: 13, serif: true))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 150)
                .background(RoundedRectangle(cornerRadius: 9).fill(t.card))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.border.opacity(0.7), lineWidth: 0.6))
                .focused($noteFocused)
                .onChange(of: noteText) { _, newValue in
                    guard noteLoaded else { return }
                    user.saveNote(book: app.bookId, chapter: app.chapter, verse: verse, body: newValue)
                }
            Text("Saved automatically on this Mac.")
                .font(.system(size: 9.5))
                .foregroundColor(t.secondary.opacity(0.8))

            SectionLabel(text: "Highlight", theme: t)
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
                    Button {
                        user.setHighlight(book: app.bookId, chapter: app.chapter, verse: verse, color: i)
                    } label: {
                        Circle()
                            .fill(Palette.color(i, dark: t.isDark))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().strokeBorder(user.highlight(book: app.bookId, chapter: app.chapter, verse: verse) == i ? t.accent : .clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    user.setHighlight(book: app.bookId, chapter: app.chapter, verse: verse, color: nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(t.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(t.card))
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(t.border)

            Toggle(isOn: Binding(
                get: { user.isBookmarked(book: app.bookId, chapter: app.chapter, verse: verse) },
                set: { _ in app.toggleBookmark() }
            )) {
                Label("Bookmark this verse", systemImage: "bookmark")
                    .font(.system(size: 11.5))
            }
            .toggleStyle(EmmausToggleStyle(theme: t))

            Button {
                app.section = .notebook
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Open Notebook")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(t.accent)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(t.accent.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Data loading

    private func reload() {
        guard let v = app.selectedVerse else {
            crossRefs = []; commentary = []; interlinear = []; verseWords = []
            return
        }
        crossRefs = app.bible.crossReferences(book: app.bookId, chapter: app.chapter, verse: v, limit: 30)
        commentary = app.bible.commentary(book: app.bookId, chapter: app.chapter, verse: v)
        if !commentary.isEmpty {
            let works = Array(Set(commentary.map { $0.work })).sorted()
            if !works.contains(selectedWork) { selectedWork = preferredWork(works) }
        }
        interlinear = app.bible.interlinear(book: app.bookId, chapter: app.chapter, verse: v)
        if let chapter = app.chapterData, let verse = chapter.verses.first(where: { $0.number == v }) {
            var ids: [String] = []
            var seen = Set<String>()
            for token in verse.tokens ?? [] {
                for s in token.strongs where seen.insert(s).inserted { ids.append(s) }
            }
            verseWords = ids.compactMap { app.bible.strongs(id: $0) }
        } else {
            verseWords = []
        }
        if let id = app.selectedStrongs, app.bible.strongs(id: id) != nil {
            // keep the selection
        } else if app.inspectorTab == .word {
            app.selectedStrongs = verseWords.first?.id
        }
        loadNote()
        remoteVerses = [:]
        for tr in app.remoteTranslations {
            if let cached = user.cachedCloudChapter(translation: tr.code, book: app.bookId, chapter: app.chapter),
               let text = cached.verses[v] {
                remoteVerses[tr.code] = text
            }
        }
    }

    private func preferredWork(_ works: [String]) -> String {
        for w in ["tyndale", "matthew-henry", "jamieson-fausset-brown", "geneva", "scofield"] {
            if works.contains(w) { return w }
        }
        return works.first ?? ""
    }

    private func loadNote() {
        guard let v = app.selectedVerse else { noteText = ""; noteLoaded = true; return }
        noteLoaded = false
        noteText = user.note(book: app.bookId, chapter: app.chapter, verse: v)?.body ?? ""
        noteLoaded = true
    }

    private func loadRemoteVerse(_ tr: Translation, verse: Int) {
        guard app.api.isConfigured else { return }
        remoteLoading.insert(tr.code)
        Task {
            do {
                let result = try await app.api.chapter(translation: tr, bookIndex: app.bookId, chapter: app.chapter)
                user.cacheCloudChapter(translation: tr.code, book: app.bookId, chapter: app.chapter, verses: result.verses)
                if !result.copyright.isEmpty { user.setSetting("copyright-\(tr.code)", result.copyright) }
                await MainActor.run {
                    remoteVerses[tr.code] = result.verses[verse]
                    remoteLoading.remove(tr.code)
                }
            } catch {
                await MainActor.run {
                    remoteLoading.remove(tr.code)
                    app.toastMessage(error.localizedDescription)
                }
            }
        }
    }

    private func loadRemoteVerses(verse: Int) {
        for tr in app.remoteTranslations {
            if user.cachedCloudChapter(translation: tr.code, book: app.bookId, chapter: app.chapter) != nil {
                if let cached = user.cachedCloudChapter(translation: tr.code, book: app.bookId, chapter: app.chapter) {
                    remoteVerses[tr.code] = cached.verses[verse]
                }
            } else {
                loadRemoteVerse(tr, verse: verse)
            }
        }
    }
}

struct CrossRefRow: View {
    var ref: CrossRef
    var theme: Theme
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(ReferenceParser.label(book: ref.toBook, chapter: ref.toChapter, verse: ref.toVerseStart))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(theme.accent)
                        if ref.votes > 0 {
                            Text("\(ref.votes)")
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundColor(theme.secondary.opacity(0.6))
                        }
                    }
                    if !ref.preview.isEmpty {
                        Text(ref.preview)
                            .font(Typography.reading(size: 10.5, serif: true))
                            .foregroundColor(theme.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8))
                    .foregroundColor(theme.secondary.opacity(0.35))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(hovering ? theme.accent.opacity(0.06) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
