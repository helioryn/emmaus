import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var user: UserStore

    @State private var showOT = true
    @State private var showNT = false

    var body: some View {
        let t = app.theme
        VStack(alignment: .leading, spacing: 0) {
            brand
            jumpButton
            nav
            Divider().overlay(t.border.opacity(0.6)).padding(.vertical, 10)
            books
            Spacer(minLength: 8)
            footer
        }
        .frame(width: 248)
        .background(t.panel)
    }

    private var brand: some View {
        let t = app.theme
        return HStack(spacing: 10) {
            BrandMark(theme: t, size: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text("Emmaus")
                    .font(Typography.reading(size: 20, serif: true, weight: .semibold))
                    .foregroundColor(t.ink)
                Text("Scripture, opened.")
                    .font(.system(size: 9.5, weight: .medium))
                    .tracking(1.0)
                    .foregroundColor(t.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var jumpButton: some View {
        let t = app.theme
        return Button {
            app.showCommandPalette = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                Text("Jump to reference…")
                    .font(.system(size: 12))
                Spacer()
                Text("⌘K")
                    .font(.system(size: 9.5, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(t.card))
            }
            .foregroundColor(t.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(t.card)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.border.opacity(0.7), lineWidth: 0.6))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private var nav: some View {
        let t = app.theme
        return VStack(spacing: 2) {
            ForEach([AppSection.home, .read, .search, .wordStudy, .dictionary, .topics, .plans, .notebook]) { item in
                Button {
                    app.section = item
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 12.5, weight: .medium))
                            .frame(width: 17)
                        Text(item.title)
                            .font(.system(size: 12.5, weight: app.section == item ? .semibold : .regular))
                        Spacer()
                        if item == .notebook, !user.notes.isEmpty {
                            Text("\(user.notes.count)")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(t.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(t.card))
                        }
                    }
                    .foregroundColor(app.section == item ? t.accent : t.ink.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(app.section == item ? t.accent.opacity(0.11) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
            }
        }
    }

    private var books: some View {
        let t = app.theme
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "Library", theme: t)
                Spacer()
                Text("\(app.bible.books.count) books")
                    .font(.system(size: 9.5))
                    .foregroundColor(t.secondary)
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    disclosure("Old Testament", count: 39, isOpen: $showOT)
                    if showOT {
                        bookRows(app.bible.books.filter { $0.isOT })
                    }
                    disclosure("New Testament", count: 27, isOpen: $showNT)
                    if showNT {
                        bookRows(app.bible.books.filter { !$0.isOT })
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func disclosure(_ title: String, count: Int, isOpen: Binding<Bool>) -> some View {
        let t = app.theme
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { isOpen.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOpen.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(t.secondary)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(t.secondary)
                Text("\(count)")
                    .font(.system(size: 9.5))
                    .foregroundColor(t.secondary.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func bookRows(_ books: [Book]) -> some View {
        let t = app.theme
        return VStack(spacing: 1) {
            ForEach(books) { b in
                let selected = app.section == .read && app.bookId == b.id
                Button {
                    app.openBookOverview(book: b.id)
                } label: {
                    HStack(spacing: 8) {
                        Text(b.name)
                            .font(.system(size: 12, weight: selected ? .semibold : .regular))
                            .foregroundColor(selected ? t.accent : t.ink.opacity(0.82))
                            .lineLimit(1)
                        Spacer()
                        Text("\(b.chapters)")
                            .font(.system(size: 9.5))
                            .foregroundColor(t.secondary.opacity(0.55))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(selected ? t.accent.opacity(0.10) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        let t = app.theme
        return HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12))
                .foregroundColor(user.streak > 0 ? t.accent : t.secondary.opacity(0.5))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(user.streak) day\(user.streak == 1 ? "" : "s")")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(t.ink)
                Text("reading streak")
                    .font(.system(size: 9))
                    .foregroundColor(t.secondary)
            }
            Spacer()
            Button {
                app.section = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12.5))
                    .foregroundColor(t.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(t.card))
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(t.bg2.opacity(0.5))
    }
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var user: UserStore

    var body: some View {
        let t = app.theme
        HStack(spacing: 0) {
            if !app.focusMode {
                SidebarView()
                    .transition(.move(edge: .leading).combined(with: .opacity))
                Rectangle().fill(t.border.opacity(0.6)).frame(width: 1)
            }
            VStack(spacing: 0) {
                Group {
                    switch app.section {
                    case .home: HomeView()
                    case .read:
                        if app.showBookOverview { BookOverviewView() } else { ReaderView() }
                    case .search: SearchView()
                    case .wordStudy: WordStudyView()
                    case .dictionary: DictionaryView()
                    case .topics: TopicsView()
                    case .plans: PlansView()
                    case .notebook: NotebookView()
                    case .settings: SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if app.showInspector && !app.focusMode && app.section == .read && !app.showBookOverview {
                Rectangle().fill(t.border.opacity(0.6)).frame(width: 1)
                StudyPanel()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(t.bg)
        .padding(.top, 26)
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowAccessor())
        .sheet(isPresented: $app.showCommandPalette) {
            CommandPaletteView()
                .environmentObject(app)
                .environmentObject(user)
        }
        .overlay(alignment: .bottom) {
            if let toast = app.toast {
                ToastView(message: toast, theme: t)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: app.showInspector)
        .animation(.easeInOut(duration: 0.18), value: app.focusMode)
        .preferredColorScheme(t.isDark ? .dark : .light)
        .onAppear { SnapshotHook.maybeCapture(app: app) }
    }
}

enum SnapshotHook {
    @MainActor
    static func maybeCapture(app: AppState) {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["SELAH_SNAPSHOT_PATH"] else { return }
        if let raw = env["SELAH_SNAPSHOT_THEME"], let theme = AppTheme(rawValue: raw) { app.themeName = theme }
        if let rawB = env["SELAH_SNAPSHOT_BOOK"], let b = Int(rawB),
           let rawC = env["SELAH_SNAPSHOT_CHAPTER"], let c = Int(rawC) {
            app.open(book: b, chapter: c)
        }
        if let raw = env["SELAH_SNAPSHOT_SECTION"], let section = AppSection(rawValue: raw) { app.section = section }
        if app.section == .read { app.showInspector = true }
        if let code = env["SELAH_SNAPSHOT_TRANSLATION"], !code.isEmpty {
            app.changeTranslation(code)
        }
        if let raw = env["SELAH_SNAPSHOT_VERSE"], let verse = Int(raw) { app.selectedVerse = verse }
        if let raw = env["SELAH_SNAPSHOT_TAB"], let tab = InspectorTab(rawValue: raw) { app.inspectorTab = tab }
        if let q = env["SELAH_SNAPSHOT_QUERY"], !q.isEmpty {
            if app.section == .search { app.searchQuery = q; app.runSearch() }
            else if app.section == .wordStudy { app.wordStudyQuery = q; app.runWordStudy() }
        }
        if env["SELAH_SNAPSHOT_OVERVIEW"] == "1" { app.openBookOverview(book: app.bookId) }
        if env["SELAH_SNAPSHOT_COMMAND"] == "1" { app.showCommandPalette = true }
        let delay = Double(env["SELAH_SNAPSHOT_DELAY"] ?? "") ?? 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard let window = NSApp.windows.first(where: { $0.contentView != nil }),
                  let view = window.contentView,
                  view.bounds.width > 10 else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    capture(path: path)
                }
                return
            }
            capture(path: path)
            NSApp.terminate(nil)
        }
    }

    @MainActor
    private static func capture(path: String) {
        let sheet = NSApp.windows.first(where: { $0.isSheet && $0.contentView != nil })
        guard let window = sheet ?? NSApp.windows.first(where: { $0.contentView != nil }),
              let view = window.contentView else { return }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let w = view.window else { return }
            w.title = "Emmaus"
            w.isMovableByWindowBackground = true
            w.titlebarAppearsTransparent = true
            w.styleMask.insert(.fullSizeContentView)
            w.backgroundColor = .clear
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Temporary placeholders (replaced by feature views)

struct PlaceholderView: View {
    var title: String
    var icon: String
    var message: String
    @EnvironmentObject var app: AppState

    var body: some View {
        let t = app.theme
        VStack {
            SectionHeaderBar(title: title, subtitle: message, theme: t)
            EmptyState(icon: icon, title: title, message: message, theme: t)
        }
        .background(t.bg)
    }
}

struct SectionHeaderBar: View {
    var title: String
    var subtitle: String
    var theme: Theme
    var trailing: AnyView? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Typography.reading(size: 26, serif: true, weight: .semibold))
                        .foregroundColor(theme.ink)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(theme.secondary)
                }
                Spacer()
                if let trailing { trailing }
            }
            .padding(.horizontal, 26)
            .padding(.top, 14)
            .padding(.bottom, 14)
            Divider().overlay(theme.border.opacity(0.6))
        }
        .background(theme.bg)
    }
}
