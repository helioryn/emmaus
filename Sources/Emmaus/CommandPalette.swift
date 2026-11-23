import SwiftUI
import AppKit

struct CommandPaletteView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var user: UserStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    struct Item: Identifiable {
        var id: String
        var icon: String
        var title: String
        var subtitle: String
        var action: () -> Void
    }

    var body: some View {
        let t = app.theme
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(t.accent)
                TextField("Reference, word, Strong's number, or command…", text: $query)
                    .textFieldStyle(.plain)
                    .font(Typography.reading(size: 18, serif: false))
                    .foregroundColor(t.ink)
                    .focused($focused)
                    .onSubmit { activate() }
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(t.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                Text("esc")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(t.secondary.opacity(0.6))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(t.card))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)

            Divider().overlay(t.border.opacity(0.7))

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if items.isEmpty {
                        VStack(spacing: 7) {
                            Text("No matches")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(t.ink)
                            Text("Try “John 3:16”, “love”, “G26”, or a book name.")
                                .font(.system(size: 11))
                                .foregroundColor(t.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                    } else {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            PaletteRow(item: item, selected: index == selection, theme: t)
                                .onTapGesture {
                                    selection = index
                                    item.action()
                                    dismiss()
                                }
                                .onHover { hovering in
                                    if hovering { selection = index }
                                }
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 390)

            Divider().overlay(t.border.opacity(0.7))
            HStack(spacing: 14) {
                hint("↑↓", "navigate")
                hint("↵", "open")
                Spacer()
                Text("Emmaus")
                    .font(Typography.reading(size: 10.5, serif: true, weight: .semibold))
                    .foregroundColor(t.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .frame(width: 660)
        .background(t.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(t.border.opacity(0.8), lineWidth: 0.7))
        .shadow(color: .black.opacity(0.25), radius: 40, y: 18)
        .onAppear {
            focused = true
            selection = 0
        }
        .onKeyPress(.downArrow) {
            if !items.isEmpty { selection = min(selection + 1, items.count - 1) }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if !items.isEmpty { selection = max(selection - 1, 0) }
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.return) {
            activate()
            return .handled
        }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9.5, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: 3).fill(app.theme.card))
                .foregroundColor(app.theme.secondary)
            Text(label)
                .font(.system(size: 9.5))
                .foregroundColor(app.theme.secondary.opacity(0.7))
        }
    }

    private func activate() {
        guard !items.isEmpty else { return }
        let index = min(selection, items.count - 1)
        items[index].action()
        dismiss()
    }

    private var items: [Item] {
        let t = app.theme
        _ = t
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var out: [Item] = []

        if q.isEmpty {
            for s in [AppSection.search, .wordStudy, .dictionary, .topics, .plans, .notebook, .home] {
                out.append(Item(id: "section-\(s.rawValue)", icon: s.icon, title: s.title,
                                subtitle: sectionSubtitle(s), action: { app.section = s }))
            }
            if let last = user.lastReading, let b = app.bible.book(last.book) {
                out.insert(Item(id: "continue", icon: "arrow.right.circle",
                                title: "Continue reading",
                                subtitle: "\(b.name) \(last.chapter)",
                                action: { app.open(last) }), at: 0)
            }
            for s in user.recentSearches(limit: 5) {
                out.append(Item(id: "recent-\(s)", icon: "clock.arrow.circlepath", title: s,
                                subtitle: "Recent search",
                                action: {
                                    app.searchQuery = s
                                    app.section = .search
                                    app.runSearch()
                                }))
            }
            return out
        }

        if let ref = ReferenceParser.parse(q) {
            let label = ReferenceParser.label(book: ref.book, chapter: ref.chapter, verse: ref.verse)
            out.append(Item(id: "ref", icon: "bookmark", title: "Go to \(label)", subtitle: "Reference",
                            action: { app.open(book: ref.book, chapter: ref.chapter, verse: ref.verse) }))
        }

        let upper = q.uppercased()
        if upper.range(of: #"^[HG]\s*0*\d{1,5}$"#, options: .regularExpression) != nil {
            let id = upper.replacingOccurrences(of: " ", with: "")
            if let e = app.bible.strongs(id: id) {
                out.append(Item(id: "strongs", icon: "character.book.closed",
                                title: "\(e.id) — \(e.lemma)",
                                subtitle: "\(e.translit) · \(e.gloss)",
                                action: {
                                    app.section = .wordStudy
                                    app.wordStudyQuery = e.id
                                    app.runWordStudy()
                                }))
            }
        }

        let matchingBooks = app.bible.books.filter {
            $0.name.lowercased().contains(q.lowercased()) || $0.short.lowercased().hasPrefix(q.lowercased())
        }
        for b in matchingBooks.prefix(5) {
            out.append(Item(id: "book-\(b.id)", icon: "book", title: b.name,
                            subtitle: "\(b.chapters) chapters · \(b.testament)",
                            action: { app.openBookOverview(book: b.id) }))
        }

        out.append(Item(id: "search", icon: "magnifyingglass", title: "Search for “\(q)”",
                        subtitle: "All offline translations",
                        action: {
                            app.searchQuery = q
                            app.section = .search
                            app.runSearch()
                        }))
        out.append(Item(id: "word", icon: "character.book.closed", title: "Study “\(q)”",
                        subtitle: "Strong's lexicon and concordance",
                        action: {
                            app.wordStudyQuery = q
                            app.section = .wordStudy
                            app.runWordStudy()
                        }))
        return out

    }

    private func sectionSubtitle(_ s: AppSection) -> String {
        switch s {
        case .search: return "Full-text search across offline translations"
        case .wordStudy: return "Strong's, morphology and concordance"
        case .dictionary: return "Easton, Smith and Hitchcock"
        case .topics: return "Nave's Topical Bible"
        case .plans: return "Bible in a year and more"
        case .notebook: return "Notes, highlights and bookmarks"
        case .home: return "Your reading desk"
        default: return ""
        }
    }
}

struct PaletteRow: View {
    var item: CommandPaletteView.Item
    var selected: Bool
    var theme: Theme

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(selected ? theme.accent : theme.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                    .foregroundColor(theme.ink)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(theme.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if selected {
                Image(systemName: "return")
                    .font(.system(size: 9))
                    .foregroundColor(theme.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 7).fill(selected ? theme.accent.opacity(0.11) : .clear))
        .contentShape(Rectangle())
    }
}
