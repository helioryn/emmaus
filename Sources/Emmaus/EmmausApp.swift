import SwiftUI
import AppKit

@main
struct EmmausApp: App {
    @StateObject private var app = AppState()

    init() {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = image
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(app.user)
                .environmentObject(app.speech)
                .frame(minWidth: 1000, minHeight: 660)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 880)
        .commands {
            AppCommands(app: app)
        }
    }
}

struct AppCommands: Commands {
    @ObservedObject var app: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandGroup(after: .appInfo) {
            Divider()
            Button("Go to Reference…") { app.showCommandPalette = true }
                .keyboardShortcut("k", modifiers: .command)
            Button("Search the Bible") { app.section = .search }
                .keyboardShortcut("f", modifiers: .command)
        }

        CommandMenu("Navigate") {
            Button("Next Chapter") { app.nextChapter() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(app.section != .read)
            Button("Previous Chapter") { app.previousChapter() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(app.section != .read)
            Divider()
            Button("Back") { app.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!app.canGoBack)
            Button("Forward") { app.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!app.canGoForward)
            Divider()
            Button("Home") { app.section = .home }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            Button("Read") { app.section = .read }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        CommandMenu("Reading") {
            Button(app.speech.isSpeaking ? "Stop Reading" : "Read Chapter Aloud") { app.toggleSpeech() }
                .keyboardShortcut("r", modifiers: [.command, .option])
            Button("Read Selected Verse") { app.speakVerse() }
                .disabled(app.selectedVerse == nil)
            Divider()
            Button("Bookmark Verse") { app.toggleBookmark() }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(app.selectedVerse == nil)
            Button("Add Note…") { app.requestNoteFocus() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(app.selectedVerse == nil)
            Divider()
            Button("Copy Verse") {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(app.copyVerse(), forType: .string)
                app.toastMessage("Verse copied")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(app.selectedVerse == nil)
        }

        CommandMenu("View") {
            Button(app.showInspector ? "Hide Study Panel" : "Show Study Panel") {
                app.showInspector.toggle()
                app.saveSettings()
            }
            .keyboardShortcut("i", modifiers: .command)
            Button(app.focusMode ? "Exit Focus Mode" : "Focus Mode") {
                withAnimation { app.focusMode.toggle() }
            }
            .keyboardShortcut(".", modifiers: .command)
            Divider()
            Button("Larger Text") {
                app.fontSize = min(28, app.fontSize + 1)
                app.saveSettings()
            }
            .keyboardShortcut("=", modifiers: .command)
            Button("Smaller Text") {
                app.fontSize = max(15, app.fontSize - 1)
                app.saveSettings()
            }
            .keyboardShortcut("-", modifiers: .command)
            Divider()
            Menu("Theme") {
                ForEach(AppTheme.allCases) { th in
                    Button(th.name) { app.setTheme(th) }
                }
            }
        }
    }
}
