import SwiftUI
import AppKit

struct DictionaryView: View {
    @EnvironmentObject var app: AppState
    @FocusState private var focused: Bool

    @State private var query = ""
    @State private var source = ""
    @State private var letter = ""
    @State private var entries: [DictionaryEntry] = []
    @State private var selected: DictionaryEntry?
    @State private var sources: [String] = []

    private let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)

    var body: some View {
        let t = app.theme
        VStack(spacing: 0) {
            SectionHeaderBar(title: "Dictionary", subtitle: "Easton, Smith, and Hitchcock — 11,000 entries, offline.",
                             theme: t)
            VStack(spacing: 12) {
                searchBar
                HStack(spacing: 8) {
                    sourceChip("All", "")
                    ForEach(sources, id: \.self) { s in
                        sourceChip(displaySource(s), s)
                    }
                    Spacer()
                    Text("\(entries.count) entries")
                        .font(.system(size: 10))
                        .foregroundColor(t.secondary)
                }
                letterBar
                HStack(spacing: 0) {
                    entryList
                        .frame(width: 320)
                    Rectangle().fill(t.border.opacity(0.6)).frame(width: 1)
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 14)
        }
        .background(t.bg)
        .onAppear {
            sources = app.bible.dictionarySources()
            load()
        }
    }

    private var searchBar: some View {
        let t = app.theme
        return HStack(spacing: 10) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 14))
                .foregroundColor(t.accent)
            TextField("Search people, places, words, and things…", text: $query)
                .textFieldStyle(.plain)
                .font(Typography.reading(size: 15, serif: false))
                .foregroundColor(t.ink)
                .focused($focused)
                .onSubmit { load() }
            if !query.isEmpty {
                Button {
                    query = ""
                    load()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(t.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            Button("Search") { load() }
                .buttonStyle(PrimaryButtonStyle(theme: t))
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.border.opacity(0.8), lineWidth: 0.6))
    }

    private func sourceChip(_ label: String, _ value: String) -> some View {
        let t = app.theme
        let active = source == value
        return Button {
            source = value
            load()
        } label: {
            Text(label)
                .font(.system(size: 10.5, weight: active ? .semibold : .regular))
                .foregroundColor(active ? t.card : t.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(active ? t.accent : t.card))
        }
        .buttonStyle(.plain)
    }

    private var letterBar: some View {
        let t = app.theme
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                letterButton("All", "")
                ForEach(letters, id: \.self) { l in
                    letterButton(l, l)
                }
            }
        }
    }

    private func letterButton(_ label: String, _ value: String) -> some View {
        let t = app.theme
        let active = letter == value
        return Button {
            letter = value
            query = ""
            load()
        } label: {
            Text(label)
                .font(.system(size: 10, weight: active ? .bold : .medium))
                .foregroundColor(active ? t.accent : t.secondary.opacity(0.75))
                .frame(minWidth: 20)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(active ? t.accent.opacity(0.11) : .clear))
        }
        .buttonStyle(.plain)
    }

    private var entryList: some View {
        let t = app.theme
        return ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(entries) { e in
                    let active = selected?.id == e.id
                    Button {
                        selected = e
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(e.headword)
                                    .font(Typography.reading(size: 13, serif: true, weight: active ? .semibold : .regular))
                                    .foregroundColor(active ? t.accent : t.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text(shortSource(e.source))
                                    .font(.system(size: 8.5, weight: .medium))
                                    .foregroundColor(t.secondary.opacity(0.6))
                            }
                            Text(e.body)
                                .font(.system(size: 10))
                                .foregroundColor(t.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(active ? t.accent.opacity(0.10) : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private var detail: some View {
        let t = app.theme
        if let e = selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 7) {
                        Pill(text: displaySource(e.source), theme: t)
                        Spacer()
                    }
                    Text(e.headword)
                        .font(Typography.reading(size: 32, serif: true, weight: .semibold))
                        .foregroundColor(t.ink)
                    Rectangle()
                        .fill(LinearGradient(colors: [t.accent.opacity(0.6), t.accent.opacity(0.03)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                    InlineRefText(text: e.body, theme: t, size: 14, color: t.ink.opacity(0.92)) { loc in
                        app.open(loc)
                    }
                    Spacer(minLength: 30)
                }
                .padding(24)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        } else {
            EmptyState(icon: "text.book.closed", title: "Choose an entry",
                       message: "Browse by letter or search for a person, place, or theme.", theme: t)
        }
    }

    private func load() {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            entries = app.bible.dictionarySearch(query, source: source.isEmpty ? nil : source, limit: 120)
        } else {
            entries = app.bible.dictionary(source: source.isEmpty ? nil : source,
                                           letter: letter.isEmpty ? nil : letter,
                                           limit: 500)
        }
        if let current = selected, entries.contains(where: { $0.id == current.id }) { return }
        selected = entries.first
    }

    private func displaySource(_ s: String) -> String {
        switch s {
        case "Easton": return "Easton"
        case "Smith": return "Smith"
        case "Hitchcock": return "Hitchcock"
        default: return s
        }
    }

    private func shortSource(_ s: String) -> String {
        switch s {
        case "Easton": return "EAS"
        case "Smith": return "SMI"
        case "Hitchcock": return "HIT"
        default: return String(s.prefix(3)).uppercased()
        }
    }
}

struct TopicsView: View {
    @EnvironmentObject var app: AppState

    @State private var sections: [String] = []
    @State private var section = ""
    @State private var subjects: [Topic] = []
    @State private var selected: Topic?
    @State private var query = ""
    @State private var results: [Topic] = []

    var body: some View {
        let t = app.theme
        VStack(spacing: 0) {
            SectionHeaderBar(title: "Topics", subtitle: "Nave's Topical Bible — follow a theme through Scripture.", theme: t)
            VStack(spacing: 12) {
                searchBar
                HStack(spacing: 0) {
                    sectionList.frame(width: 170)
                    Rectangle().fill(t.border.opacity(0.6)).frame(width: 1)
                    subjectList.frame(width: 286)
                    Rectangle().fill(t.border.opacity(0.6)).frame(width: 1)
                    topicDetail.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 14)
        }
        .background(t.bg)
        .onAppear {
            sections = app.bible.topicSections()
            if section.isEmpty { section = sections.first ?? "" }
            reloadSubjects()
        }
    }

    private var searchBar: some View {
        let t = app.theme
        return HStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 14))
                .foregroundColor(t.accent)
            TextField("Search topics…", text: $query)
                .textFieldStyle(.plain)
                .font(Typography.reading(size: 15, serif: false))
                .foregroundColor(t.ink)
                .onSubmit { runSearch() }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(t.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            Button("Search") { runSearch() }
                .buttonStyle(PrimaryButtonStyle(theme: t))
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.border.opacity(0.8), lineWidth: 0.6))
    }

    private var sectionList: some View {
        let t = app.theme
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(sections, id: \.self) { s in
                    let active = s == section && query.isEmpty
                    Button {
                        section = s
                        query = ""
                        results = []
                        reloadSubjects()
                    } label: {
                        Text(s)
                            .font(.system(size: 11.5, weight: active ? .semibold : .regular))
                            .foregroundColor(active ? t.accent : t.ink.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(active ? t.accent.opacity(0.10) : .clear))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
        }
    }

    private var subjectList: some View {
        let t = app.theme
        let list = query.isEmpty ? subjects : results
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(list) { s in
                    let active = selected?.id == s.id
                    Button {
                        selected = s
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.subject)
                                .font(.system(size: 12, weight: active ? .semibold : .regular))
                                .foregroundColor(active ? t.accent : t.ink)
                                .lineLimit(1)
                            if query.isEmpty {
                                Text(String(s.entry.prefix(70)))
                                    .font(.system(size: 9.5))
                                    .foregroundColor(t.secondary)
                                    .lineLimit(1)
                            } else {
                                Text(s.section)
                                    .font(.system(size: 9))
                                    .foregroundColor(t.secondary)
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(active ? t.accent.opacity(0.10) : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private var topicDetail: some View {
        let t = app.theme
        if let s = selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(s.section.uppercased())
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(t.secondary)
                    Text(s.subject)
                        .font(Typography.reading(size: 30, serif: true, weight: .semibold))
                        .foregroundColor(t.ink)
                    Rectangle()
                        .fill(LinearGradient(colors: [t.accent.opacity(0.6), t.accent.opacity(0.03)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                    InlineRefText(text: s.entry, theme: t, size: 13.5, color: t.ink.opacity(0.9)) { loc in
                        app.open(loc)
                    }
                    Spacer(minLength: 30)
                }
                .padding(24)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        } else {
            EmptyState(icon: "list.bullet.rectangle", title: "Choose a topic",
                       message: "Pick a section, then a subject to see every passage Nave's index gathers.", theme: t)
        }
    }

    private func reloadSubjects() {
        guard !section.isEmpty else { return }
        subjects = app.bible.topics(section: section, limit: 800)
        selected = subjects.first
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; return }
        results = app.bible.topicSearch(q, limit: 150)
        selected = results.first
    }
}
