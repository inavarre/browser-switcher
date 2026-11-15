import AppKit
import SwiftUI
import WebKit
import os

/// Shows the bundled Help.html in a small in-app window.
///
/// Shown in-app rather than handed to a browser: we *are* the default browser, and the
/// help page shouldn't depend on link routing being set up correctly.
@MainActor
final class HelpWindowController {
    static let shared = HelpWindowController()

    private var window: NSWindow?
    private var webView: WKWebView?
    private var closeObserver: NSObjectProtocol?

    /// `section` is an element id in Help.html, e.g. `"rules"`.
    func show(section: String? = nil) {
        guard let page = Bundle.main.url(forResource: "Help", withExtension: "html") else {
            Logger.app.error("Help.html is missing from the app bundle")
            return
        }
        let window = self.window ?? makeWindow()
        self.window = window

        var components = URLComponents(url: page, resolvingAgainstBaseURL: false)
        components?.fragment = section
        webView?.loadFileURL(components?.url ?? page, allowingReadAccessTo: page.deletingLastPathComponent())

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func makeWindow() -> NSWindow {
        let size = NSSize(width: 640, height: 720)
        let webView = WKWebView(frame: NSRect(origin: .zero, size: size))
        self.webView = webView

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "BrowserSwitcher Help"
        window.contentView = webView
        window.contentMinSize = NSSize(width: 480, height: 400)
        window.isReleasedWhenClosed = false
        window.center()

        // The page runs in its own WebKit process (~27 MB). Drop the web view when the window
        // closes so that process exits; reopening Help just rebuilds it.
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.releaseWindow() }
        }
        return window
    }

    private func releaseWindow() {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
        closeObserver = nil
        webView?.stopLoading()
        window?.contentView = nil
        webView = nil
        window = nil
    }
}

extension View {
    /// The standard round "?" button at the bottom of a settings tab, opening Help at `section`.
    func helpButton(section: String) -> some View {
        safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                HelpLink {
                    HelpWindowController.shared.show(section: section)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 14)
            // Opaque, so a long tab scrolls behind the button instead of under it.
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}
