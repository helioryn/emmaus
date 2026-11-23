import SwiftUI
import AppKit

struct StrongsDetail: View {
    let entry: StrongsEntry
    var onSelect: (String) -> Void
    var onOpen: (Location) -> Void

    @EnvironmentObject var app: AppState
    @EnvironmentObject var speech: SpeechService

    @State private var showAllOccurrences = false

    var body: some View {
        let t = app.theme
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !entry.definition.isEmpty {
                    block("Definition", text: entry.definition)
                }
                if !entry.extended.isEmpty && entry.extended != entry.definition {
                    block("Extended lexicon", text: entry.extended)
                }
                if !entry.derivation.isEmpty {
                    block("Derivation", text: entry.derivation)
                }
                if !entry.kjvUsage.isEmpty {
                    block("KJV usage", text: entry.kjvUsage)
                }
                if !entry.morph.isEmpty {
                    HStack(spacing: 8) {
                        SectionLabel(text: "Morphology", theme: t)
                        Pill(text: entry.morph, theme: t)
                        if let exp = app.bible.morphExpansion(entry.morph) {
                            Text(exp).font(.system(size: 10.5)).foregroundColor(t.secondary)
                        }
                    }
                }
                let family = app.bible.strongsFamily(id: entry.id).filter { $0.id != entry.id }
                if !family.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        SectionLabel(text: "Related senses", theme: t)
                        ForEach(family) { f in
                            Button { onSelect(f.id) } label: {
                                HStack(alignment: .top, spacing: 7) {
                                    Text(f.id).font(.system(size: 9.5, weight: .bold)).foregroundColor(t.accent)
                                    Text(f.gloss.isEmpty ? String(f.definition.prefix(140)) : f.gloss)
                                        .font(.system(size: 11))
                                        .foregroundColor(t.secondary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.vertical, 3)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
                }
                occurrences
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(entry.id)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(t.accent)
                Text(entry.languageName.uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.0)
                    .foregroundColor(t.secondary)
                if entry.source == "STEPBible" {
                    Pill(text: "STEPBible", theme: t)
                }
            }
            Text(entry.lemma)
                .font(.system(size: entry.isHebrew ? 54 : 44))
                .foregroundColor(t.ink)
                .environment(\.layoutDirection, entry.isHebrew ? .rightToLeft : .leftToRight)
            HStack(spacing: 10) {
                Text(entry.translit)
                    .font(Typography.reading(size: 20, serif: true, italic: true))
                    .foregroundColor(t.secondary)
                if !entry.pronounce.isEmpty {
                    Text("· \(entry.pronounce)")
                        .font(.system(size: 12))
                        .foregroundColor(t.secondary.opacity(0.8))
                }
                Spacer()
                HStack(spacing: 6) {
                    Button {
                        speech.speakWord(entry.lemma, language: entry.languageCode)
                    } label: {
                        Label("Say", systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(theme: t))
                    Button {
                        speech.speakWord(entry.lemma, language: entry.languageCode, slow: true)
                    } label: {
                        Text("Slow")
                    }
                    .buttonStyle(SoftButtonStyle(theme: t))
                    Button {
                        speech.speakWord(entry.translit, language: "en")
                    } label: {
                        Image(systemName: "textformat.abc")
                    }
                    .buttonStyle(SoftButtonStyle(theme: t))
                    .help("Hear the transliteration with an English voice")
                }
            }
            if !entry.gloss.isEmpty {
                Text(entry.gloss)
                    .font(Typography.reading(size: 20, serif: true, weight: .medium))
                    .foregroundColor(t.ink)
            }
        }
    }

    private func block(_ title: String, text: String) -> some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 5) {
            SectionLabel(text: title, theme: t)
            Text(text)
                .font(Typography.reading(size: 13.5, serif: true))
                .foregroundColor(t.ink.opacity(0.92))
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }

    private var occurrences: some View {
        let t = app.theme
        let occ = app.bible.occurrences(strongs: entry.id, limit: showAllOccurrences ? 1000 : 60)
        let count = app.bible.occurrenceCount(strongs: entry.id)
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                SectionLabel(text: "Concordance", theme: t)
                Spacer()
                Text("\(count) occurrences in the KJV")
                    .font(.system(size: 10))
                    .foregroundColor(t.secondary)
            }
            if occ.isEmpty {
                Text("No tagged occurrences.")
                    .font(.system(size: 11))
                    .foregroundColor(t.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(occ) { o in
                        Button {
                            onOpen(Location(book: o.book, chapter: o.chapter, verse: o.verse))
                        } label: {
                            HStack(spacing: 8) {
                                Text(ReferenceParser.label(book: o.book, chapter: o.chapter, verse: o.verse))
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(t.accent)
                                    .frame(width: 120, alignment: .leading)
                                Text(o.form)
                                    .font(Typography.reading(size: 12, serif: true, italic: true))
                                    .foregroundColor(t.ink.opacity(0.85))
                                    .lineLimit(1)
                                Spacer()
                                Text(Morph.short(o.morph))
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundColor(t.secondary.opacity(0.55))
                            }
                            .padding(.vertical, 4.5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 9).fill(t.card))
                if !showAllOccurrences && count > 60 {
                    Button("Show all \(count) occurrences") { showAllOccurrences = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(t.accent)
                }
            }
        }
    }
}

struct WordStudyView: View {
    @EnvironmentObject var app: AppState
    @FocusState private var focused: Bool
    @State private var selected: StrongsEntry?

    var body: some View {
        let t = app.theme
        VStack(spacing: 0) {
            SectionHeaderBar(title: "Word Study", subtitle: "Strong's lexicon, morphology, and every occurrence.", theme: t)
            VStack(spacing: 14) {
                searchBar
                content
            }
            .padding(.horizontal, 26)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .background(t.bg)
        .onAppear {
            focused = app.wordStudyQuery.isEmpty
            if app.wordStudyQuery.isEmpty, let id = app.selectedStrongs {
                app.wordStudyQuery = id
                app.runWordStudy()
            }
            syncSelection()
        }
        .onChange(of: app.wordStudyResults) { _, _ in syncSelection() }
    }

    private var searchBar: some View {
        let t = app.theme
        return HStack(spacing: 10) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 14))
                .foregroundColor(t.accent)
            TextField("Strong's number, Hebrew, Greek, or English gloss…", text: $app.wordStudyQuery)
                .textFieldStyle(.plain)
                .font(Typography.reading(size: 16, serif: false))
                .foregroundColor(t.ink)
                .focused($focused)
                .onSubmit { app.runWordStudy() }
            Button("Study") { app.runWordStudy() }
                .buttonStyle(PrimaryButtonStyle(theme: t))
                .disabled(app.wordStudyQuery.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 11).fill(t.card))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(t.border.opacity(0.8), lineWidth: 0.7))
    }

    @ViewBuilder
    private var content: some View {
        let t = app.theme
        if app.wordStudyQuery.isEmpty && app.wordStudyResults.isEmpty {
            VStack(spacing: 18) {
                EmptyState(icon: "character.book.closed", title: "Study any word",
                           message: "Enter a Strong's number (G26, H430), a Hebrew or Greek word, or an English gloss like “love” or “covenant”.",
                           theme: t)
                    .frame(height: 150)
                HStack(spacing: 8) {
                    quick("G26", "love")
                    quick("G2316", "God")
                    quick("H430", "God")
                    quick("H3068", "LORD")
                    quick("H7225", "beginning")
                    quick("G4102", "faith")
                }
                Spacer()
            }
        } else if app.wordStudyResults.isEmpty {
            EmptyState(icon: "magnifyingglass", title: "No lexicon match",
                       message: "Try a Strong's number such as G26, or a simpler English word.",
                       theme: t)
        } else {
            HStack(spacing: 0) {
                resultsList
                    .frame(width: 286)
                Rectangle().fill(t.border.opacity(0.6)).frame(width: 1)
                if let selected {
                    StrongsDetail(entry: selected, onSelect: { id in select(id) }, onOpen: { app.open($0) })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyState(icon: "text.book.closed", title: "Select an entry",
                               message: "Choose a lexicon entry to see its definition and occurrences.",
                               theme: t)
                }
            }
        }
    }

    private var resultsList: some View {
        let t = app.theme
        return ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(app.wordStudyResults) { e in
                    let active = selected?.id == e.id
                    Button {
                        select(e.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(e.id)
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(t.accent)
                                Text(e.translit)
                                    .font(Typography.reading(size: 12, serif: true, italic: true))
                                    .foregroundColor(t.secondary)
                                Spacer()
                            }
                            Text(e.gloss.isEmpty ? String(e.definition.prefix(70)) : e.gloss)
                                .font(.system(size: 10.5))
                                .foregroundColor(t.secondary)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 7).fill(active ? t.accent.opacity(0.12) : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }

    private func quick(_ id: String, _ gloss: String) -> some View {
        let t = app.theme
        return Button {
            app.wordStudyQuery = id
            app.runWordStudy()
        } label: {
            VStack(spacing: 2) {
                Text(id).font(.system(size: 10, weight: .bold)).foregroundColor(t.accent)
                Text(gloss).font(.system(size: 9.5)).foregroundColor(t.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7).fill(t.card))
        }
        .buttonStyle(.plain)
    }

    private func select(_ id: String) {
        if let e = app.bible.strongs(id: id) {
            selected = e
            app.selectedStrongs = id
        }
    }

    private func syncSelection() {
        if let current = selected, app.wordStudyResults.contains(where: { $0.id == current.id }) { return }
        selected = app.wordStudyResults.first
        if let s = selected { app.selectedStrongs = s.id }
    }
}
