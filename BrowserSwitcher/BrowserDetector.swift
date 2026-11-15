import AppKit

/// Finds the installed apps that can open web links (our own app excluded).
@MainActor
final class BrowserDetector: ObservableObject {
    static let shared = BrowserDetector()

    @Published private(set) var browsers: [BrowserInfo] = []
    /// Prompt entries: each browser, split into one entry per profile when it has several.
    @Published private(set) var launchTargets: [LaunchTarget] = []

    private let ownBundleID = Bundle.main.bundleIdentifier

    init() {
        refresh()
    }

    func refresh() {
        guard let probe = URL(string: "https://example.com") else { return }

        // One app can be registered several times (old versions, test-tool caches, the Trash);
        // keep real installs only, and the newest copy of each.
        var newest: [String: (url: URL, version: String)] = [:]
        for url in NSWorkspace.shared.urlsForApplications(toOpen: probe) where Self.isInstalledLocation(url) {
            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier,
                  bundleID != ownBundleID
            else { continue }
            let version = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
            if let kept = newest[bundleID], kept.version.compare(version, options: .numeric) != .orderedAscending {
                continue
            }
            newest[bundleID] = (url, version)
        }

        browsers = newest
            .map { BrowserInfo(bundleID: $0.key, name: $0.value.url.deletingPathExtension().lastPathComponent, url: $0.value.url) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        launchTargets = browsers.flatMap { browser -> [LaunchTarget] in
            let profiles = ChromiumProfiles.profiles(forBundleID: browser.bundleID)
            guard profiles.count > 1 else { return [LaunchTarget(browser: browser, profile: nil)] }
            return profiles.map { LaunchTarget(browser: browser, profile: $0) }
        }
    }

    /// Real installs live in /Applications, ~/Applications or (Safari) /System. This skips copies
    /// in the Trash, in caches (Puppeteer/Playwright test browsers) and in updater folders.
    nonisolated static func isInstalledLocation(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix("/Applications/")
            || path.hasPrefix(home + "/Applications/")
            || path.hasPrefix("/System/")
    }

    func info(forBundleID bundleID: String) -> BrowserInfo? {
        browsers.first { $0.bundleID == bundleID }
    }

    /// Never returns our own bundle, so a link can't be routed back to us in a loop.
    func appURL(forBundleID bundleID: String) -> URL? {
        guard !bundleID.isEmpty, bundleID != ownBundleID else { return nil }
        return info(forBundleID: bundleID)?.url ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    /// Resolves a saved choice (`LaunchTarget.id`). A plain bundle id stays a plain browser, which
    /// opens in that browser's last-used profile. A profile that no longer exists falls back to the
    /// plain browser rather than losing the link.
    func target(forID id: String) -> LaunchTarget? {
        guard !id.isEmpty else { return nil }
        if let known = launchTargets.first(where: { $0.id == id }) {
            return known
        }
        let parts = id.split(separator: "#", maxSplits: 1).map(String.init)
        guard let bundleID = parts.first, let url = appURL(forBundleID: bundleID) else { return nil }
        let browser = info(forBundleID: bundleID)
            ?? BrowserInfo(bundleID: bundleID, name: url.deletingPathExtension().lastPathComponent, url: url)
        if parts.count == 2,
           let profile = ChromiumProfiles.profiles(forBundleID: bundleID).first(where: { $0.directory == parts[1] }) {
            return LaunchTarget(browser: browser, profile: profile)
        }
        return LaunchTarget(browser: browser, profile: nil)
    }

    /// Picker label for a saved choice that isn't one of the listed entries.
    func unlistedLabel(forID id: String) -> String {
        guard let target = target(forID: id) else { return "\(id) (not installed)" }
        if target.profile == nil {
            return "\(target.browser.name) — last-used profile"
        }
        return target.menuLabel
    }
}
