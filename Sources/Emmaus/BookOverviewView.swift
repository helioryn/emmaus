import SwiftUI

struct BookOverviewView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var user: UserStore

    var body: some View {
        let t = app.theme
        if let book = app.activeBook {
            let read = user.readChapters(book: book.id)
            let last = user.lastChapter(book: book.id)
            let notes = user.notes(in: book.id)
            let progress = Double(read.count) / Double(max(book.chapters, 1))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(book: book, read: read, progress: progress, theme: t)
                    actions(book: book, last: last, theme: t)
                    chapterSection(book: book, read: read, last: last, theme: t)
                    recentNotes(book: book, notes: notes, theme: t)
                    Spacer(minLength: 30)
                }
                .frame(maxWidth: 780, alignment: .leading)
                .padding(.horizontal, 54)
                .padding(.top, 34)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
            .background(t.bg)
        } else {
            EmptyState(icon: "book.closed", title: "Book unavailable",
                       message: "Choose a book from the library.", theme: t)
        }
    }

    private func header(book: Book, read: Set<Int>, progress: Double, theme t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(book.testament == "OT" ? "OLD TESTAMENT" : "NEW TESTAMENT")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(t.accent)
                Text("·").foregroundColor(t.secondary.opacity(0.4))
                Text(book.genre.uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(t.secondary)
            }
            Text(book.name)
                .font(Typography.reading(size: 42, serif: true, weight: .semibold))
                .foregroundColor(t.ink)
            Text(BookIntros.text(for: book.id))
                .font(Typography.reading(size: 17, serif: true))
                .foregroundColor(t.secondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 620, alignment: .leading)

            HStack(spacing: 10) {
                Text("\(read.count) of \(book.chapters) chapters read")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(t.secondary)
                ProgressBar(value: progress, theme: t)
                    .frame(width: 220, height: 4)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 9.5))
                    .foregroundColor(t.secondary.opacity(0.7))
            }
            .padding(.top, 6)

            Rectangle()
                .fill(
                    LinearGradient(colors: [t.accent.opacity(0.55), t.accent.opacity(0.03)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(height: 1)
                .padding(.top, 8)
        }
    }

    private func actions(book: Book, last: Int?, theme t: Theme) -> some View {
        HStack(spacing: 10) {
            if let last {
                Button {
                    app.open(book: book.id, chapter: last)
                } label: {
                    Label("Continue \(book.name) \(last)",
                          systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(theme: t))
                .keyboardShortcut(.defaultAction)

                if last != 1 {
                    Button {
                        app.open(book: book.id, chapter: 1)
                    } label: {
                        Label("Start at chapter 1", systemImage: "book")
                    }
                    .buttonStyle(SoftButtonStyle(theme: t))
                }
            } else {
                Button {
                    app.open(book: book.id, chapter: 1)
                } label: {
                    Label("Start reading", systemImage: "book")
                }
                .buttonStyle(PrimaryButtonStyle(theme: t))
                .keyboardShortcut(.defaultAction)
            }

            Spacer()

            if let last {
                Text("Last read: \(book.name) \(last)")
                    .font(.system(size: 10))
                    .foregroundColor(t.secondary.opacity(0.8))
            }
        }
    }

    private func chapterSection(book: Book, read: Set<Int>, last: Int?, theme t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                SectionLabel(text: "Chapters", theme: t)
                Spacer()
                legend(theme: t)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 8)], spacing: 8) {
                ForEach(1...book.chapters, id: \.self) { n in
                    ChapterTile(
                        number: n,
                        isRead: read.contains(n),
                        isLast: last == n,
                        hasMarks: user.chapterHasMarks(book: book.id, chapter: n),
                        theme: t
                    ) {
                        app.open(book: book.id, chapter: n)
                    }
                }
            }
        }
    }

    private func legend(theme t: Theme) -> some View {
        HStack(spacing: 12) {
            legendItem(color: t.accent.opacity(0.16), text: "Read", theme: t)
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(t.accent, lineWidth: 1.4)
                    .frame(width: 8, height: 8)
                Text("Last read").font(.system(size: 8.5)).foregroundColor(t.secondary.opacity(0.75))
            }
            HStack(spacing: 4) {
                Circle().fill(t.accent).frame(width: 3.5, height: 3.5)
                Text("Notes").font(.system(size: 8.5)).foregroundColor(t.secondary.opacity(0.75))
            }
        }
    }

    private func legendItem(color: Color, text: String, theme t: Theme) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text).font(.system(size: 8.5)).foregroundColor(t.secondary.opacity(0.75))
        }
    }

    @ViewBuilder
    private func recentNotes(book: Book, notes: [Note], theme t: Theme) -> some View {
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Recent in \(book.name)", theme: t)
                    Spacer()
                    Button("Notebook") { app.section = .notebook }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(t.accent)
                }
                VStack(spacing: 0) {
                    ForEach(notes.prefix(4)) { note in
                        Button {
                            app.open(book: note.book, chapter: note.chapter, verse: note.verse)
                            app.inspectorTab = .notes
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text(ReferenceParser.label(book: note.book, chapter: note.chapter, verse: note.verse))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(t.accent)
                                    .frame(width: 100, alignment: .leading)
                                Text(note.body)
                                    .font(Typography.reading(size: 11.5, serif: true))
                                    .foregroundColor(t.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Text(note.updated.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 8.5))
                                    .foregroundColor(t.secondary.opacity(0.55))
                            }
                            .padding(.vertical, 7)
                            .padding(.horizontal, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if note.id != notes.prefix(4).last?.id {
                            Divider().overlay(t.border.opacity(0.5)).padding(.leading, 11)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
            }
        }
    }
}

struct ChapterTile: View {
    var number: Int
    var isRead: Bool
    var isLast: Bool
    var hasMarks: Bool
    var theme: Theme
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isLast ? theme.accent : theme.border.opacity(0.75),
                                          lineWidth: isLast ? 1.5 : 0.6)
                    )
                Text("\(number)")
                    .font(.system(size: 12, weight: isRead || isLast ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isRead ? theme.accent : theme.ink.opacity(0.88))
                if hasMarks {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 3.5, height: 3.5)
                        .offset(x: 13, y: -13)
                }
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Chapter \(number)")
        .accessibilityLabel("Chapter \(number)\(isRead ? ", read" : "")\(hasMarks ? ", has notes" : "")")
    }

    private var background: Color {
        if isLast { return theme.accent.opacity(0.16) }
        if isRead { return theme.accent.opacity(0.10) }
        if hovering { return theme.accent.opacity(0.06) }
        return theme.card
    }
}

struct ProgressBar: View {
    var value: Double
    var theme: Theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.border.opacity(0.5))
                Capsule()
                    .fill(theme.accent.opacity(0.8))
                    .frame(width: max(3, geo.size.width * min(max(value, 0), 1)))
            }
        }
    }
}
