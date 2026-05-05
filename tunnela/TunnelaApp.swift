import SwiftUI
import AppKit

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillUpdate(_ notification: Notification) {
        removeUnwantedMenus()
    }

    private func removeUnwantedMenus() {
        guard let mainMenu = NSApp.mainMenu else { return }
        for title in ["View", "Format", "表示", "フォーマット"] {
            while let item = mainMenu.items.first(where: { $0.title == title }) {
                mainMenu.removeItem(item)
            }
        }
    }
}

// MARK: - App

@main
struct TunnelaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var sshManager = SSHManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(historyStore)
                .environmentObject(sshManager)
                .frame(minWidth: 820, minHeight: 540)
        }
        .defaultSize(width: 1000, height: 660)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .saveItem) {}
            CommandGroup(replacing: .importExport) {}
            CommandGroup(replacing: .undoRedo) {}
            // AppDelegate は responder chain に入らないため showHelp: が届かない。
            // CommandGroup で置き換えることで ⌘? を確実に捕捉する。
            CommandGroup(replacing: .help) {
                Button("tunnela ヘルプ") {
                    TunnelaApp.openHelp()
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }

    static func openHelp() {
        let lang = Locale.current.languageCode ?? "en"
        let folder = lang == "ja" ? "ja.lproj" : "en.lproj"
        guard let url = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "LocalizedHelp/\(folder)/Help"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
