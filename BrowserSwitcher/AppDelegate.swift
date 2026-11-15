import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        BrowserDetector.shared.refresh()
        DefaultBrowserManager.shared.refresh()

        // We have no Dock icon or window, so a plain launch would look like nothing happened.
        // Show Settings while setup is incomplete — but not when macOS launched us just to
        // route a link (that isn't a "default" launch), and not on every login once set up.
        let isDefaultLaunch = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
        if isDefaultLaunch && needsSetup {
            SettingsWindowController.shared.show()
        }
    }

    /// Opening the app again from Finder, Spotlight or Launchpad while it's running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return false
    }

    /// Once we're the default browser, macOS delivers every clicked http/https link here
    /// (launching us first if needed). AppKit's built-in GURL Apple Event handler calls this,
    /// so we deliberately don't install our own `kAEGetURL` handler, which would replace it.
    func application(_ application: NSApplication, open urls: [URL]) {
        LinkHandler.handle(urls)
    }

    @MainActor
    private var needsSetup: Bool {
        let store = SettingsStore.shared
        let detector = BrowserDetector.shared
        return !DefaultBrowserManager.shared.isDefaultBrowser
            || detector.target(forID: store.workBrowserBundleID) == nil
            || detector.target(forID: store.personalBrowserBundleID) == nil
    }
}
