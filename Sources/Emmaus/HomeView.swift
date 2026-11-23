import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var user: UserStore

    @State private var yearPlan: ReadingPlan?
    @State private var planDay: PlanDay?

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        if h < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var lastLocation: Location {
        user.lastReading ?? Location(book: 43, chapter: 3, verse: nil)
    }

    var body: some View {
        let t = app.theme
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                topBar
                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 18) {
                        continueCard
                        dailyCard
                        recentNotes
                    }
                    .frame(maxWidth: .infinity)
                    VStack(spacing: 18) {
                        planCard
                        statsCard
                        quickCard
                    }
                    .frame(width: 300)
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 30)
            .padding(.top, 22)
            .padding(.bottom, 30)
            .frame(maxWidth: 1080)
            .frame(maxWidth: .infinity)
        }
        .background(t.bg)
        .onAppear { buildPlan() }
    }

    private var topBar: some View {
        let t = app.theme
        let date = Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(Typography.reading(size: 32, serif: true, weight: .semibold))
                    .foregroundColor(t.ink)
                Text(date)
                    .font(.system(size: 12))
                    .foregroundColor(t.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                    .foregroundColor(t.accent)
                Text("\(user.streak) day streak")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(t.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().fill(t.card))
        }
    }

    private var continueCard: some View {
        let t = app.theme
        let book = app.bible.book(lastLocation.book)
        let verse = app.bible.displayVerseText(translation: app.translationCode, book: lastLocation.book, chapter: lastLocation.chapter, verse: 1) ?? ""
        return Button {
            app.open(lastLocation)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("CONTINUE READING")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.4)
                        .foregroundColor(t.accent)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(t.accent.opacity(0.8))
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(book?.name ?? "")
                        .font(Typography.reading(size: 30, serif: true, weight: .semibold))
                        .foregroundColor(t.ink)
                    Text("\(lastLocation.chapter)")
                        .font(Typography.reading(size: 32, serif: true, weight: .light))
                        .foregroundColor(t.accent.opacity(0.8))
                }
                Text(verse)
                    .font(Typography.reading(size: 13.5, serif: true))
                    .foregroundColor(t.secondary)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Pill(text: app.activeTranslation.short, theme: t)
                    Text("\(book?.chapters ?? 0) chapters in this book")
                        .font(.system(size: 10))
                        .foregroundColor(t.secondary.opacity(0.7))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(colors: [t.card, t.accent.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(t.border.opacity(0.7), lineWidth: 0.7))
            )
        }
        .buttonStyle(.plain)
    }

    private var dailyCard: some View {
        let t = app.theme
        let (loc, text) = app.dailyVerse
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Verse for Today", theme: t)
                Spacer()
                Text(ReferenceParser.label(book: loc.book, chapter: loc.chapter, verse: loc.verse))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(t.accent)
            }
            Text(text)
                .font(Typography.reading(size: 17, serif: true))
                .foregroundColor(t.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button {
                    app.open(loc)
                } label: {
                    Text("Open passage →")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(t.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 12).fill(t.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(t.border.opacity(0.7), lineWidth: 0.7))
    }

    @ViewBuilder
    private var recentNotes: some View {
        let t = app.theme
        if !user.allNotes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Recent Notes", theme: t)
                    Spacer()
                    Button("All notes") { app.section = .notebook }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(t.accent)
                }
                VStack(spacing: 0) {
                    ForEach(user.allNotes.prefix(4)) { note in
                        Button {
                            app.open(book: note.book, chapter: note.chapter, verse: note.verse)
                            app.inspectorTab = .notes
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text(ReferenceParser.label(book: note.book, chapter: note.chapter, verse: note.verse))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(t.accent)
                                    .frame(width: 96, alignment: .leading)
                                Text(note.body)
                                    .font(Typography.reading(size: 11.5, serif: true))
                                    .foregroundColor(t.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.vertical, 7)
                            .padding(.horizontal, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if note.id != user.allNotes.prefix(4).last?.id {
                            Divider().overlay(t.border.opacity(0.5)).padding(.leading, 11)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
            }
        }
    }

    private var planCard: some View {
        let t = app.theme
        let complete = planDay.map { user.isPlanDayComplete("bible-year", $0.day) } ?? false
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Today's Reading", theme: t)
                Spacer()
                if let d = planDay {
                    Text("Day \(d.day)")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(t.secondary)
                }
            }
            Text(planDay?.label ?? "—")
                .font(Typography.reading(size: 15, serif: true, weight: .medium))
                .foregroundColor(t.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let d = planDay {
                FlowLayout(spacing: 5, lineSpacing: 5) {
                    ForEach(Array(d.readings.prefix(6).enumerated()), id: \.offset) { _, loc in
                        Button {
                            app.open(loc)
                        } label: {
                            Text("\(app.bible.book(loc.book)?.short ?? "") \(loc.chapter)")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(t.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(t.accent.opacity(0.09)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    user.setPlanDayComplete("bible-year", d.day, complete: !complete)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                        Text(complete ? "Completed" : "Mark complete")
                    }
                }
                .buttonStyle(SoftButtonStyle(theme: t))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(t.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(t.border.opacity(0.7), lineWidth: 0.7))
    }

    private var statsCard: some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Your Study", theme: t)
            HStack(spacing: 8) {
                stat("\(user.chaptersRead)", "chapters", "book")
                stat("\(user.notes.count)", "notes", "note.text")
                stat("\(user.highlights.count)", "highlights", "highlighter")
            }
            HStack(spacing: 8) {
                stat("\(user.streak)", "day streak", "flame")
                stat("\(user.bookmarks.count)", "bookmarks", "bookmark")
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(t.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(t.border.opacity(0.7), lineWidth: 0.7))
    }

    private func stat(_ value: String, _ label: String, _ icon: String) -> some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9.5))
                .foregroundColor(t.accent.opacity(0.8))
            Text(value)
                .font(Typography.reading(size: 20, serif: true, weight: .semibold))
                .foregroundColor(t.ink)
            Text(label)
                .font(.system(size: 8.5))
                .foregroundColor(t.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(t.bg2.opacity(0.6)))
    }

    private var quickCard: some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Study Tools", theme: t)
            quick("Search the Bible", "magnifyingglass") { app.section = .search }
            quick("Word Study", "character.book.closed") { app.section = .wordStudy }
            quick("Dictionary", "text.book.closed") { app.section = .dictionary }
            quick("Topics", "list.bullet.rectangle") { app.section = .topics }
            quick("Reading Plans", "calendar") { app.section = .plans }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(t.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(t.border.opacity(0.7), lineWidth: 0.7))
    }

    private func quick(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        let t = app.theme
        return Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10.5))
                    .foregroundColor(t.accent)
                    .frame(width: 15)
                Text(title)
                    .font(.system(size: 11.5))
                    .foregroundColor(t.ink.opacity(0.9))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8))
                    .foregroundColor(t.secondary.opacity(0.4))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func buildPlan() {
        guard yearPlan == nil else { return }
        let def = PlanLibrary.definitions.first { $0.id == "bible-year" }!
        let plan = PlanLibrary.plan(for: def, books: app.bible.books)
        yearPlan = plan
        let doy = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let clamped = max(1, min(plan.days.count, doy))
        planDay = plan.days.first { $0.day == clamped }
    }
}
