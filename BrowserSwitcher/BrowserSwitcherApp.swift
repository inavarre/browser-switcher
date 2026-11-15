import SwiftUI

@main
struct BrowserSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("BrowserSwitcher", systemImage: "arrow.triangle.branch") {
            MenuBarPanel()
        }
        .menuBarExtraStyle(.window)
    }
}
