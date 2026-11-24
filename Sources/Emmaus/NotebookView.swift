import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct NotebookView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var user: UserStore

    enum Tab: String, CaseIterable { case notes = "Notes", highlights = "Highlights", bookmarks = "Bookmarks" }

    @State private var tab: Tab = .notes
    @State private var selectedNote: Note?
    @State private var editorText = ""
    @State private var loadingNote = false

    var body: some View {
        let t = app.theme
        VStack(spacing: 0) {
            header
            switch tab {
            case .notes: notesView
            case .highlights: highlightsView
            case .bookmarks: bookmarksView
            }
        }
        .background(t.bg)
        .onAppear {
            if selectedNote == nil { selectedNote = user.allNotes.first }
            loadEditor()
        }
        .onChange(of: user.notes) { _, _ in
            if let s = selectedNote, let updated = user.notes[VerseKey(book: s.book, chapter: s.chapter, verse: s.verse)] {
                selectedNote = updated
                if !loadingNote { editorText = updated.body }
            }
        }
    }

    private var header: some View {
        let t = app.theme
        return VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Notebook")
                        .font(Typography.reading(size: 26, serif: true, weight: .semibold))
                        .foregroundColor(t.ink)
                    Text("\(user.notes.count) notes · \(user.highlights.count) highlights · \(user.bookmarks.count) bookmarks")
                        .font(.system(size: 11))
                        .foregroundColor(t.secondary)
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(Tab.allCases, id: \.self) { item in
                        Button {
                            tab = item
                        } label: {
                            Text(item.rawValue)
                                .font(.system(size: 10.5, weight: tab == item ? .semibold : .regular))
                                .foregroundColor(tab == item ? t.card : t.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(tab == item ? t.accent : .clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Capsule().fill(t.card))
                Button {
                    exportMarkdown()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SoftButtonStyle(theme: t))
            }
            .padding(.horizontal, 26)
            .padding(.top, 14)
            .padding(.bottom, 12)
            Divider().overlay(t.border.opacity(0.6))
        }
    }

    // MARK: notes

    @ViewBuilder
    private var notesView: some View {
        let t = app.theme
        if user.notes.isEmpty {
            EmptyState(icon: "note.text", title: "No notes yet",
                       message: "Select a verse, open the Study panel, and write what you see. Your notes stay on this Mac.",
                       theme: t)
        } else {
            HStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(user.allNotes) { note in
                            let active = selectedNote?.id == note.id
                            Button {
                                selectedNote = note
                                loadEditor()
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(ReferenceParser.label(book: note.book, chapter: note.chapter, verse: note.verse))
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundColor(t.accent)
                                    Text(note.body)
                                        .font(Typography.reading(size: 11.5, serif: true))
                                        .foregroundColor(t.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
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
                .frame(width: 310)
                Rectangle().fill(t.border.opacity(0.6)).frame(width: 1)

                if let note = selectedNote {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ReferenceParser.label(book: note.book, chapter: note.chapter, verse: note.verse))
                                    .font(Typography.reading(size: 21, serif: true, weight: .semibold))
                                    .foregroundColor(t.ink)
                                if let v = app.bible.verseText(translation: app.translationCode, book: note.book, chapter: note.chapter, verse: note.verse) {
                                    Text(v)
                                        .font(Typography.reading(size: 12, serif: true, italic: true))
                                        .foregroundColor(t.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Button("Open verse") {
                                app.open(book: note.book, chapter: note.chapter, verse: note.verse)
                            }
                            .buttonStyle(SoftButtonStyle(theme: t))
                            Button {
                                user.deleteNote(note)
                                selectedNote = user.allNotes.first
                                loadEditor()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(t.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Delete note")
                            .accessibilityLabel("Delete note")
                        }
                        TextEditor(text: $editorText)
                            .font(Typography.reading(size: 14, serif: true))
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.border.opacity(0.7), lineWidth: 0.6))
                            .onChange(of: editorText) { _, newValue in
                                guard !loadingNote else { return }
                                user.saveNote(book: note.book, chapter: note.chapter, verse: note.verse, body: newValue)
                            }
                        HStack {
                            Text("Edited \(note.updated.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 9.5))
                                .foregroundColor(t.secondary.opacity(0.7))
                            Spacer()
                            Text("Saved automatically")
                                .font(.system(size: 9.5))
                                .foregroundColor(t.secondary.opacity(0.7))
                        }
                    }
                    .padding(20)
                } else {
                    EmptyState(icon: "note.text", title: "Select a note", message: "Choose a note to edit.", theme: t)
                }
            }
        }
    }

    @ViewBuilder
    private var highlightsView: some View {
        let t = app.theme
        if user.highlights.isEmpty {
            EmptyState(icon: "highlighter", title: "No highlights",
                       message: "Select a verse, then use the Highlight menu to mark it in one of five colors.", theme: t)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(user.highlights.keys.sorted(by: { ($0.book, $0.chapter, $0.verse) < ($1.book, $1.chapter, $1.verse) }), id: \.self) { key in
                        let color = user.highlights[key] ?? 0
                        Button {
                            app.open(book: key.book, chapter: key.chapter, verse: key.verse)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Palette.color(color, dark: t.isDark))
                                    .frame(width: 4)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(ReferenceParser.label(book: key.book, chapter: key.chapter, verse: key.verse))
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundColor(t.accent)
                                    Text(app.bible.verseText(translation: app.translationCode, book: key.book, chapter: key.chapter, verse: key.verse) ?? "")
                                        .font(Typography.reading(size: 12.5, serif: true))
                                        .foregroundColor(t.ink.opacity(0.9))
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 9).fill(t.card))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var bookmarksView: some View {
        let t = app.theme
        if user.bookmarks.isEmpty {
            EmptyState(icon: "bookmark", title: "No bookmarks",
                       message: "Bookmark a verse with ⌘D while reading and it will appear here.", theme: t)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(user.allBookmarks, id: \.self) { key in
                        Button {
                            app.open(book: key.book, chapter: key.chapter, verse: key.verse)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(t.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ReferenceParser.label(book: key.book, chapter: key.chapter, verse: key.verse))
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundColor(t.accent)
                                    Text(app.bible.verseText(translation: app.translationCode, book: key.book, chapter: key.chapter, verse: key.verse) ?? "")
                                        .font(Typography.reading(size: 12.5, serif: true))
                                        .foregroundColor(t.ink.opacity(0.9))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8))
                                    .foregroundColor(t.secondary.opacity(0.4))
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 9).fill(t.card))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func loadEditor() {
        loadingNote = true
        editorText = selectedNote?.body ?? ""
        loadingNote = false
    }

    private func exportMarkdown() {
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
