import SwiftUI
import AppKit

struct WordRun: Identifiable {
    var id: Int
    var text: String
    var strongs: [String] = []
    var morph: [String] = []
    var red = false
    var italic = false
    var heading = false
    var isVerseNumber = false
}

struct ReaderView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var user: UserStore
    @EnvironmentObject var speech: SpeechService

    @State private var showAppearance = false

    var body: some View {
        let t = app.theme
        ZStack {
            t.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Divider().overlay(t.border.opacity(0.7))
                content
            }
        }
    }

    // MARK: header

    private var header: some View {
        let t = app.theme
        return HStack(spacing: 12) {
            Button(action: app.previousChapter) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(t.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(t.card))
            }
            .buttonStyle(.plain)
            .help("Previous chapter (⌘←)")

            Button(action: app.nextChapter) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(t.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(t.card))
            }
            .buttonStyle(.plain)
            .help("Next chapter (⌘→)")

            Menu {
                Section("Offline Library") {
                    ForEach(app.localTranslations) { tr in
                        Button {
                            app.changeTranslation(tr.code)
                        } label: {
                            HStack {
                                Text("\(tr.short) — \(tr.name)")
                                if tr.code == app.translationCode { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                Section("Connected via API.Bible") {
                    ForEach(app.remoteTranslations) { tr in
                        Button {
                            app.changeTranslation(tr.code)
                        } label: {
                            HStack {
                                Text("\(tr.short) — \(tr.name)")
                                if tr.code == app.translationCode { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(app.activeTranslation.short)
                        .font(.system(size: 11.5, weight: .semibold))
                    if app.activeTranslation.isRemote {
                        Image(systemName: "cloud")
                            .font(.system(size: 9.5, weight: .semibold))
                    } else if app.activeTranslation.hasRed {
                        Circle().fill(t.red).frame(width: 5, height: 5)
                    }
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(t.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(t.card))
                .overlay(Capsule().strokeBorder(t.border.opacity(0.8), lineWidth: 0.6))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Spacer()

            IconButton(systemName: "textformat.size", theme: t, help: "Appearance") {
                showAppearance.toggle()
            }
            .popover(isPresented: $showAppearance, arrowEdge: .bottom) {
                AppearancePopover().environmentObject(app).environmentObject(user)
            }

            IconButton(systemName: speech.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2",
                       theme: t, help: speech.isSpeaking ? "Stop reading" : "Read chapter aloud",
                       active: speech.isSpeaking) {
                app.toggleSpeech()
            }

            IconButton(systemName: app.showInspector ? "sidebar.right" : "sidebar.right",
                       theme: t, help: "Toggle study panel (⌘I)", active: app.showInspector) {
                app.showInspector.toggle()
                app.saveSettings()
            }

            IconButton(systemName: app.focusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                       theme: t, help: "Focus mode") {
                withAnimation(.easeInOut(duration: 0.2)) { app.focusMode.toggle() }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(t.bg)
    }

    // MARK: content

    private var content: some View {
        let t = app.theme
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 1).id("top")
                    chapterHeading
                    if app.isLoading {
                        loadingView
                    } else if let data = app.chapterData {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(data.verses) { verse in
                                VerseBlock(
                                    verse: verse,
                                    book: app.bookId,
                                    chapter: app.chapter,
                                    isSelected: app.selectedVerse == verse.number,
                                    highlight: user.highlight(book: app.bookId, chapter: app.chapter, verse: verse.number),
                                    speechVerse: speech.currentVerse,
                                    theme: t,
                                    fontSize: app.readingFontSize,
                                    lineSpacing: app.readingLineSpacing,
                                    serif: app.serif,
                                    rtl: app.activeTranslation.isRTL,
                                    showStrongs: app.showStrongs,
                                    showRedLetter: app.showRedLetter,
                                    showNumbers: app.showVerseNumbers,
                                    onSelect: { app.selectVerse(verse.number) },
                                    onWord: { run in
                                        app.selectVerse(verse.number)
                                        if let s = run.strongs.first {
                                            app.lookupStrongs(s)
                                        }
                                    },
                                    onBookmark: {
                                        app.selectVerse(verse.number)
                                        app.toggleBookmark()
                                    },
                                    onNote: {
                                        app.selectVerse(verse.number)
                                        app.requestNoteFocus()
                                    },
                                    onHighlight: { color in
                                        app.selectVerse(verse.number)
                                        app.setHighlight(color)
                                    },
                                    onCopy: {
                                        app.selectVerse(verse.number)
                                        let pb = NSPasteboard.general
                                        pb.clearContents()
                                        pb.setString(app.copyVerse(), forType: .string)
                                        app.toastMessage("Verse copied")
                                    },
                                    onSpeak: {
                                        app.selectVerse(verse.number)
                                        app.speakVerse()
                                    },
                                    onStudy: {
                                        app.selectVerse(verse.number)
                                        app.inspectorTab = .study
                                        app.showInspector = true
                                    },
                                    onCompare: {
                                        app.selectVerse(verse.number)
                                        app.inspectorTab = .compare
                                        app.showInspector = true
                                    }
                                )
                            }
                        }
                        if app.isUsingStaleCache {
                            banner("Showing a cached copy. Reconnect to refresh this licensed translation.")
                        }
                        if let err = app.remoteError, app.chapterData != nil {
                            banner(err)
                        }
                        chapterFooter
                        if app.activeTranslation.isRemote {
                            Text(user.string("copyright-\(app.translationCode)", app.activeTranslation.attribution))
                                .font(.system(size: 9))
                                .foregroundColor(app.theme.secondary.opacity(0.7))
                                .padding(.top, 18)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else if app.activeTranslation.isRemote, let err = app.remoteError {
                        remoteUnavailable(err)
                    } else {
                        EmptyState(icon: "book.closed", title: "Chapter unavailable",
                                   message: "This chapter is not available in the selected translation.",
                                   theme: t)
                            .frame(height: 300)
                    }
                    Spacer(minLength: 50)
                }
                .frame(maxWidth: app.focusMode ? 860 : 760, alignment: .leading)
                .padding(.horizontal, app.focusMode ? 64 : 54)
                .padding(.top, 34)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: app.bookId) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("top", anchor: .top) }
            }
            .onChange(of: app.chapter) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("top", anchor: .top) }
            }
        }
    }

    private var chapterHeading: some View {
        let t = app.theme
        let book = app.activeBook
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text((book?.genre ?? "").uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(t.accent)
                Text("·").foregroundColor(t.secondary.opacity(0.5))
                Text(book?.testament == "OT" ? "OLD TESTAMENT" : "NEW TESTAMENT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(t.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Button {
                    app.openBookOverview(book: app.bookId)
                } label: {
                    HStack(spacing: 8) {
                        Text(book?.name ?? "")
                            .font(Typography.reading(size: 38, serif: true, weight: .semibold))
                            .foregroundColor(t.ink)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(t.secondary.opacity(0.55))
                    }
                }
                .buttonStyle(.plain)
                .help("Browse chapters in \(book?.name ?? "this book")")
                Text("\(app.chapter)")
                    .font(Typography.reading(size: 44, serif: true, weight: .light))
                    .foregroundColor(t.accent.opacity(0.85))
                Spacer()
            }
            HStack(spacing: 10) {
                if app.activeTranslation.isRemote {
                    Pill(text: "API.Bible · cached", theme: t)
                }
                if app.activeTranslation.hasStrongs && app.showStrongs {
                    HStack(spacing: 3) {
                        Image(systemName: "character.book.closed")
                        Text("Tap a word for Strong's")
                    }
                    .font(.system(size: 10.5))
                    .foregroundColor(t.secondary.opacity(0.9))
                }
                if app.activeTranslation.hasRed && app.showRedLetter && (app.chapterData?.verses.contains(where: { $0.hasRed }) ?? false) {
                    HStack(spacing: 4) {
                        Circle().fill(t.red).frame(width: 6, height: 6)
                        Text("Words of Jesus")
                    }
                    .font(.system(size: 10.5))
                    .foregroundColor(t.secondary.opacity(0.9))
                }
            }
            Rectangle()
                .fill(
                    LinearGradient(colors: [t.accent.opacity(0.65), t.accent.opacity(0.05)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(height: 1)
                .padding(.top, 6)
                .padding(.bottom, 20)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.small)
            Text("Fetching \(app.activeTranslation.short) from API.Bible…")
                .font(Typography.ui(12.5))
                .foregroundColor(app.theme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func banner(_ text: String) -> some View {
        let t = app.theme
        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(t.accent)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundColor(t.secondary)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(t.accent.opacity(0.09)))
        .padding(.vertical, 12)
    }

    private func remoteUnavailable(_ error: String) -> some View {
        let t = app.theme
        return VStack(spacing: 14) {
            Image(systemName: "cloud.slash")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(t.accent)
            Text("\(app.activeTranslation.short) needs a connection")
                .font(Typography.reading(size: 20, serif: true, weight: .semibold))
                .foregroundColor(t.ink)
            Text(error)
                .font(Typography.ui(12.5))
                .foregroundColor(t.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack(spacing: 10) {
                Button("Try Again") { app.loadChapter(keepSelection: true) }
                    .buttonStyle(PrimaryButtonStyle(theme: t))
                Button("Open Settings") { app.section = .settings }
                    .buttonStyle(SoftButtonStyle(theme: t))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private var chapterFooter: some View {
        let t = app.theme
        let book = app.activeBook
        let hasNext = app.chapter < (book?.chapters ?? 1) || app.bookId < 66
        let hasPrev = app.chapter > 1 || app.bookId > 1
        return HStack(spacing: 12) {
            if hasPrev {
                Button(action: app.previousChapter) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.left")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Previous").font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundColor(t.secondary)
                            Text(previousLabel).font(Typography.reading(size: 14, serif: true, weight: .medium)).foregroundColor(t.ink)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
                }
                .buttonStyle(.plain)
            }
            if hasNext {
                Button(action: app.nextChapter) {
                    HStack(spacing: 10) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Next").font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundColor(t.secondary)
                            Text(nextLabel).font(Typography.reading(size: 14, serif: true, weight: .medium)).foregroundColor(t.ink)
                        }
                        Image(systemName: "arrow.right")
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .background(RoundedRectangle(cornerRadius: 10).fill(t.card))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundColor(t.secondary)
        .padding(.top, 30)
    }

    private var previousLabel: String {
        if app.chapter > 1 { return "\(app.activeBook?.name ?? "") \(app.chapter - 1)" }
        let b = app.bible.book(app.bookId - 1)
        return "\(b?.name ?? "") \(b?.chapters ?? 1)"
    }

    private var nextLabel: String {
        let total = app.activeBook?.chapters ?? 1
        if app.chapter < total { return "\(app.activeBook?.name ?? "") \(app.chapter + 1)" }
        let b = app.bible.book(app.bookId + 1)
        return "\(b?.name ?? "Revelation") 1"
    }
}

// MARK: - Verse block

struct VerseBlock: View {
    let verse: Verse
    let book: Int
    let chapter: Int
    let isSelected: Bool
    let highlight: Int?
    let speechVerse: Int?
    let theme: Theme
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let serif: Bool
    let rtl: Bool
    let showStrongs: Bool
    let showRedLetter: Bool
    let showNumbers: Bool

    let onSelect: () -> Void
    let onWord: (WordRun) -> Void
    let onBookmark: () -> Void
    let onNote: () -> Void
    let onHighlight: (Int?) -> Void
    let onCopy: () -> Void
    let onSpeak: () -> Void
    let onStudy: () -> Void
    let onCompare: () -> Void

    @EnvironmentObject var user: UserStore

    var body: some View {
        Group {
            if rtl {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(verse.number)")
                        .font(Typography.ui(fontSize * 0.6, weight: .semibold))
                        .foregroundColor(theme.accent.opacity(0.8))
                        .baselineOffset(fontSize * 0.34)
                    Text(verse.text)
                        .font(Typography.reading(size: fontSize, serif: serif))
                        .foregroundColor(theme.ink)
                        .lineSpacing(lineSpacing * 0.55)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .environment(\.layoutDirection, .rightToLeft)
            } else {
                FlowLayout(spacing: 0, lineSpacing: lineSpacing * 0.55) {
                    ForEach(runs) { run in
                        WordChip(
                            run: run,
                            theme: theme,
                            fontSize: fontSize,
                            serif: serif,
                            showStrongs: showStrongs,
                            showRedLetter: showRedLetter,
                            onTap: {
                                if run.isVerseNumber || run.strongs.isEmpty { onSelect() }
                                else { onWord(run) }
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(background)
        )
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.accent)
                    .frame(width: 2.5)
                    .padding(.vertical, 7)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu { contextMenu }
    }

    private var background: Color {
        if speechVerse == verse.number { return theme.accent.opacity(0.16) }
        if isSelected { return theme.selection }
        if let h = highlight { return Palette.color(h, dark: theme.isDark).opacity(theme.isDark ? 0.65 : 0.85) }
        return .clear
    }

    private var runs: [WordRun] {
        var out: [WordRun] = []
        var idx = 0
        func append(text: String, strongs: [String], morph: [String], red: Bool, italic: Bool, heading: Bool, number: Bool = false) {
            guard !text.isEmpty else { return }
            let hasWord = text.rangeOfCharacter(from: .alphanumerics) != nil
            if !number, !hasWord, let last = out.last, !last.isVerseNumber {
                out[out.count - 1].text += text
                return
            }
            out.append(WordRun(id: idx, text: text, strongs: strongs, morph: morph, red: red, italic: italic, heading: heading, isVerseNumber: number))
            idx += 1
        }
        if showNumbers {
            append(text: "\(verse.number)\u{00A0}\u{00A0}", strongs: [], morph: [], red: false, italic: false, heading: false, number: true)
        }
        let tokens = verse.tokens ?? [Token(t: verse.text)]
        var priorHeading = false
        for token in tokens {
            for (word, hadSpace) in TextUtil.splitWords(token.t) {
                var text = word
                if hadSpace { text += "\u{00A0}" }
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !out.isEmpty { out[out.count - 1].text += text }
                    continue
                }
                if priorHeading && !token.isHeading && !text.hasPrefix(" ") && !text.hasPrefix("\u{00A0}") {
                    text = "\u{00A0}" + text
                }
                append(text: text,
                       strongs: token.strongs,
                       morph: token.morph,
                       red: token.isRed,
                       italic: token.isItalic || token.isHeading,
                       heading: token.isHeading)
            }
            priorHeading = token.isHeading
        }
        return out
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Copy \(ReferenceParser.label(book: book, chapter: chapter, verse: verse.number))", action: onCopy)
        Divider()
        Menu("Highlight") {
            ForEach(0..<5, id: \.self) { i in
                Button {
                    onHighlight(i)
                } label: {
                    Label(Palette.highlightNames[i], systemImage: "circle.fill")
                }
            }
            Divider()
            Button("Remove Highlight") { onHighlight(nil) }
        }
        Button(user.isBookmarked(book: book, chapter: chapter, verse: verse.number) ? "Remove Bookmark" : "Bookmark",
               action: onBookmark)
        Button("Add Note…", action: onNote)
        Divider()
        if !strongsIDs.isEmpty {
            Menu("Look up Strong's") {
                ForEach(strongsIDs, id: \.self) { id in
                    Button(id) { onWord(WordRun(id: 0, text: "", strongs: [id])) }
                }
            }
        }
        Button("Cross References & Commentary", action: onStudy)
        Button("Compare Translations", action: onCompare)
        Divider()
        Button("Read Aloud", action: onSpeak)
    }

    private var strongsIDs: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for t in verse.tokens ?? [] {
            for s in t.strongs where seen.insert(s).inserted { out.append(s) }
        }
        return out
    }
}

struct WordChip: View {
    let run: WordRun
    let theme: Theme
    let fontSize: CGFloat
    let serif: Bool
    let showStrongs: Bool
    let showRedLetter: Bool
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        Text(run.text)
            .font(Typography.reading(
                size: run.isVerseNumber ? fontSize * 0.60 : (run.heading ? fontSize * 0.98 : fontSize),
                serif: serif,
                weight: run.isVerseNumber ? .semibold : (run.heading ? .semibold : .regular),
                italic: run.italic
            ))
            .foregroundColor(color)
            .baselineOffset(run.isVerseNumber ? fontSize * 0.36 : 0)
            .underline(underline, color: theme.accent.opacity(0.38))
            .padding(.vertical, run.isVerseNumber ? 0 : 1.2)
            .padding(.horizontal, run.isVerseNumber ? 2 : 0.5)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(hovering && !run.strongs.isEmpty && showStrongs ? theme.accent.opacity(0.10) : .clear)
            )
            .onHover { hovering = $0 }
            .onTapGesture(perform: onTap)
            .help(run.strongs.isEmpty ? "" : run.strongs.joined(separator: " · "))
    }

    private var color: Color {
        if run.isVerseNumber { return theme.accent.opacity(0.8) }
        if run.red && showRedLetter { return theme.red }
        return theme.ink
    }

    private var underline: Bool {
        showStrongs && !run.strongs.isEmpty && !run.isVerseNumber
    }
}

// MARK: - Appearance

struct AppearancePopover: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var user: UserStore

    var body: some View {
        let t = app.theme
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Appearance", theme: t)
            HStack(spacing: 8) {
                ForEach(AppTheme.allCases) { th in
                    Button {
                        app.setTheme(th)
                    } label: {
                        Circle()
                            .fill(th.theme.bg)
                            .overlay(Circle().strokeBorder(th == app.themeName ? t.accent : t.border, lineWidth: th == app.themeName ? 2 : 1))
                            .frame(width: 26, height: 26)
                            .overlay(Circle().fill(th.theme.accent).frame(width: 8, height: 8))
                    }
                    .buttonStyle(.plain)
                    .help(th.name)
                }
            }

            Divider().overlay(t.border)

            HStack {
                Text("Text size").font(.system(size: 12)).foregroundColor(t.secondary)
                Slider(value: $app.fontSize, in: 15...28, step: 1)
                Text("\(Int(app.fontSize))").font(.system(size: 11, weight: .medium)).foregroundColor(t.ink).frame(width: 22)
            }
            HStack {
                Text("Line spacing").font(.system(size: 12)).foregroundColor(t.secondary)
                Slider(value: $app.lineSpacing, in: 3...16, step: 1)
                Text("\(Int(app.lineSpacing))").font(.system(size: 11, weight: .medium)).foregroundColor(t.ink).frame(width: 22)
            }
            Toggle("Serif type", isOn: $app.serif).toggleStyle(EmmausToggleStyle(theme: t))
            Toggle("Red letters", isOn: $app.showRedLetter).toggleStyle(EmmausToggleStyle(theme: t))
            Toggle("Strong's underlines", isOn: $app.showStrongs).toggleStyle(EmmausToggleStyle(theme: t))
            Toggle("Verse numbers", isOn: $app.showVerseNumbers).toggleStyle(EmmausToggleStyle(theme: t))

            if app.activeTranslation.isRemote {
                Divider().overlay(t.border)
                Text(app.activeTranslation.attribution)
                    .font(.system(size: 10))
                    .foregroundColor(t.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 12))
        .foregroundColor(t.ink)
        .padding(16)
        .frame(width: 290)
        .background(t.panel)
        .onChange(of: app.fontSize) { _, _ in app.saveSettings() }
        .onChange(of: app.lineSpacing) { _, _ in app.saveSettings() }
        .onChange(of: app.serif) { _, _ in app.saveSettings() }
        .onChange(of: app.showRedLetter) { _, _ in app.saveSettings() }
        .onChange(of: app.showStrongs) { _, _ in app.saveSettings() }
        .onChange(of: app.showVerseNumbers) { _, _ in app.saveSettings() }
    }
}
