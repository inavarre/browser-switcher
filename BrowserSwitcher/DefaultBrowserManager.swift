import AppKit
import ServiceManagement
import os

/// Whether we're the system's default browser, and whether we launch at login.
@MainActor
final class DefaultBrowserManager: ObservableObject {
    static let shared = DefaultBrowserManager()

    @Published private(set) var isDefaultBrowser = false
    @Published private(set) var launchesAtLogin = false

    init() {
        refresh()
    }

    func refresh() {
        isDefaultBrowser = Self.isHandler(forScheme: "http") && Self.isHandler(forScheme: "https")
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// macOS shows its own "change your default web browser?" dialog; this returns after the user answers.
    /// Setting `http` normally switches `https` too, so we only ask a second time if it didn't.
    func makeDefaultBrowser() {
        Task {
            let appURL = Bundle.main.bundleURL
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "http")
                if Self.isHandler(forScheme: "http") && !Self.isHandler(forScheme: "https") {
                    try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "https")
                }
            } catch {
                Logger.app.error("Setting default browser failed: \(error.localizedDescription, privacy: .public)")
            }
            refresh()
        }
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.app.error("Updating login item failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    private static func isHandler(forScheme scheme: String) -> Bool {
        guard let probe = URL(string: "\(scheme)://example.com"),
              let handler = NSWorkspace.shared.urlForApplication(toOpen: probe)
        else { return false }
        return Bundle(url: handler)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }
}
