import AppKit
import os

enum Router {
    /// Opens the links in the given browser, untouched (query and fragment included).
    static func open(_ urls: [URL], with browserURL: URL) {
        guard !urls.isEmpty else { return }
        guard Bundle(url: browserURL)?.bundleIdentifier != Bundle.main.bundleIdentifier else {
            Logger.app.error("Refusing to route a link back to BrowserSwitcher")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: browserURL, configuration: configuration) { _, error in
            if let error {
                Logger.app.error("Opening link failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Opens the links in a prompt entry. A profile needs a fresh launch with `--profile-directory`
    /// (like `open -na "Google Chrome" --args …`); if the browser is already running, that launch
    /// hands the links to the running browser and exits.
    static func open(_ urls: [URL], in target: LaunchTarget) {
        guard let profile = target.profile else {
            open(urls, with: target.browser.url)
            return
        }
        guard !urls.isEmpty else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["--profile-directory=\(profile.directory)"] + urls.map(\.absoluteString)
        NSWorkspace.shared.openApplication(at: target.browser.url, configuration: configuration) { _, error in
            if let error {
                Logger.app.error("Opening link in profile failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

/// Entry point for every incoming link.
@MainActor
enum LinkHandler {
    static func handle(_ urls: [URL]) {
        let links = urls.filter { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }
        guard !links.isEmpty else { return }

        let store = SettingsStore.shared
        let detector = BrowserDetector.shared
        let context = OpenContext.current(urls: links)

        switch DecisionEngine.decide(context, store: store, browsers: detector) {
        case .open(let target):
            Router.open(links, in: target)
        case .prompt:
            let targets = detector.launchTargets.filter { !store.hiddenPromptTargetIDs.contains($0.id) }
            let openWithSchedule = {
                Router.open(links, in: DecisionEngine.scheduledTarget(store: store, browsers: detector, now: Date()))
            }
            guard !targets.isEmpty else {
                openWithSchedule()
                return
            }
            PromptController.shared.present(
                urls: links,
                targets: targets,
                onPick: { choice in
                    store.lastPromptBrowserBundleID = choice.id
                    Router.open(links, in: choice)
                },
                onReplaced: openWithSchedule
            )
        }
    }
}
