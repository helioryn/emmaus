import SwiftUI
import AppKit

struct SearchView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var user: UserStore
    @FocusState private var focused: Bool

    var body: some View {
        let t = app.theme
        VStack(spacing: 0) {
            SectionHeaderBar(title: "Search", subtitle: "Every word of the offline library, in a fraction of a second.",
                             theme: t)
            VStack(spacing: 14) {
                searchBar
                filters
                if app.hasSearched {
                    resultsHeader
                    results
                } else {
                    suggestions
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 20)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .background(t.bg)
        .onAppear {
            focused = true
            if !app.searchQuery.isEmpty && !app.hasSearched { app.runSearch() }
        }
    }

    private var searchBar: some View {
        let t = app.theme
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(t.accent)
            TextField("Search words, phrases, or references…", text: $app.searchQuery)
                .textFieldStyle(.plain)
                .font(Typography.reading(size: 18, serif: false))
                .foregroundColor(t.ink)
                .focused($focused)
                .onSubmit { app.runSearch() }
            if !app.searchQuery.isEmpty {
                Button {
                    app.searchQuery = ""
                    app.hasSearched = false
                    app.searchResults = []
                    app.cancelSearch()
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(t.secondary.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
            Button("Search") { app.runSearch() }
                .buttonStyle(PrimaryButtonStyle(theme: t))
                .disabled(app.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(t.card)
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(t.border.opacity(0.9), lineWidth: 0.7))
        )
    }

    private var filters: some View {
        let t = app.theme
        return HStack(spacing: 8) {
            scopeChip("All", .all)
            scopeChip("Old Testament", .oldTestament)
            scopeChip("New Testament", .newTestament)
            if let b = app.activeBook {
                scopeChip(b.name, .book(b.id))
            }
            Spacer()
            Menu {
                ForEach(app.localTranslations) { tr in
                    Button("\(tr.short) — \(tr.name)") { app.searchTranslation = tr.code }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(app.bible.translation(app.searchTranslation)?.short ?? "KJV")
                        .font(.system(size: 10.5, weight: .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(t.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(t.accent.opacity(0.09)))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func scopeChip(_ label: String, _ scope: SearchScope) -> some View {
        let t = app.theme
        let active = app.searchScope == scope
        return Button {
            app.searchScope = scope
            if app.hasSearched { app.runSearch() }
        } label: {
            Text(scope.label)
                .font(.system(size: 10.5, weight: active ? .semibold : .regular))
                .foregroundColor(active ? t.card : t.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(active ? t.accent : t.card))
                .overlay(Capsule().strokeBorder(active ? .clear : t.border.opacity(0.7), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }

    private var resultsHeader: some View {
        let t = app.theme
        return HStack {
            if app.isSearching {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Searching…")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(t.secondary)
                }
            } else {
                Text("\(app.searchResults.count) result\(app.searchResults.count == 1 ? "" : "s")")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(t.secondary)
                Text("for “\(app.searchQuery)”")
                    .font(.system(size: 11.5))
                    .foregroundColor(t.secondary.opacity(0.7))
            }
            Spacer()
            if !app.isSearching && !app.searchResults.isEmpty {
                Text("ranked by relevance")
                    .font(.system(size: 9.5))
                    .foregroundColor(t.secondary.opacity(0.55))
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var results: some View {
        let t = app.theme
        if app.isSearching {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(height: 280)
        } else if app.searchResults.isEmpty {
            EmptyState(icon: "magnifyingglass", title: "No verses found",
                       message: "Check the spelling, try fewer words, or search a different translation.",
                       theme: t)
                .frame(height: 280)
        } else {
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(app.searchResults) { hit in
                        SearchResultRow(hit: hit, theme: t, query: app.searchQuery) {
                            app.open(book: hit.book, chapter: hit.chapter, verse: hit.verse)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }

    private var suggestions: some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                suggestion("Love", icon: "heart")
                suggestion("Grace", icon: "sparkles")
                suggestion("Shepherd", icon: "leaf")
                suggestion("\"in the beginning\"", icon: "quote.opening")
                suggestion("G26", icon: "character.book.closed")
            }
            if !user.recentSearches().isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    SectionLabel(text: "Recent", theme: t)
                    FlowLayout(spacing: 7, lineSpacing: 7) {
                        ForEach(user.recentSearches(), id: \.self) { q in
                            Button {
                                app.searchQuery = q
                                app.runSearch()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 9))
                                    Text(q).font(.system(size: 10.5))
                                }
                                .foregroundColor(t.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(t.card))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                SectionLabel(text: "Tips", theme: t)
                tip("Use quotes for an exact phrase", "“the Lord is my shepherd”")
                tip("Put an asterisk after a stem", "lov* finds love, loved, loving")
                tip("Points and accents are optional", "אלהים finds אֱלֹהִים")
                tip("Combine words with AND / OR", "faith AND works")
                tip("Search a Strong's number", "G26 or H430")
            }
            Spacer(minLength: 20)
        }
        .padding(.top, 6)
    }

    private func suggestion(_ text: String, icon: String) -> some View {
        let t = app.theme
        return Button {
            app.searchQuery = text
            app.runSearch()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 9.5))
                Text(text).font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(t.ink.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(t.card))
            .overlay(Capsule().strokeBorder(t.border.opacity(0.7), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }

    private func tip(_ title: String, _ example: String) -> some View {
        let t = app.theme
        return HStack(spacing: 8) {
            Circle().fill(t.accent.opacity(0.4)).frame(width: 3, height: 3)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(t.secondary)
            Text(example)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(t.accent.opacity(0.9))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(t.accent.opacity(0.07)))
        }
    }
}

struct SearchResultRow: View {
    var hit: SearchHit
    var theme: Theme
    var query: String
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(ReferenceParser.label(book: hit.book, chapter: hit.chapter, verse: hit.verse))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.accent)
                        Text(hit.translation)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundColor(theme.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3).fill(theme.card))
                    }
                    Text(highlighted)
                        .font(Typography.reading(size: 13, serif: true))
                        .foregroundColor(theme.ink.opacity(0.9))
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8))
                    .foregroundColor(theme.secondary.opacity(0.3))
                    .padding(.top, 3)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(hovering ? theme.card : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var highlighted: AttributedString {
        var attr = AttributedString("")
        let parts = hit.snippet.components(separatedBy: "⟦")
        for (i, part) in parts.enumerated() {
            if i == 0 {
                attr += AttributedString(part)
                continue
            }
            let sub = part.components(separatedBy: "⟧")
            if let first = sub.first {
                var marked = AttributedString(first)
                marked.font = .system(size: 13, weight: .semibold, design: .serif)
                marked.foregroundColor = theme.accent
                attr += marked
            }
            if sub.count > 1 {
                attr += AttributedString(sub.dropFirst().joined(separator: "⟧"))
            }
        }
        return attr
    }
}
