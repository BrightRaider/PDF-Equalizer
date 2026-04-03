import SwiftUI

extension Notification.Name {
    static let openPDFFile = Notification.Name("openPDFFile")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, let window = sender.windows.first {
            window.makeKeyAndOrderFront(self)
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else { return }

        // Close any extra windows that SwiftUI may have spawned
        let windows = application.windows
        if windows.count > 1, let main = windows.first {
            for w in windows where w !== main {
                w.close()
            }
            main.makeKeyAndOrderFront(self)
        }

        NotificationCenter.default.post(name: .openPDFFile, object: url)
    }
}

@main
struct PDFEqualizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 520, height: 340)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
