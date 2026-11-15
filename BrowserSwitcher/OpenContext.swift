import AppKit

/// Everything the decision pipeline knows about a link at the moment it arrives.
struct OpenContext {
    let urls: [URL]
    let sourceAppBundleID: String?
    let heldModifiers: NSEvent.ModifierFlags

    var host: String? { urls.first?.host }

    /// The source app is approximated by the frontmost app: we're a background (LSUIElement) app
    /// that doesn't activate to receive links, so the app the link was clicked in is usually still
    /// frontmost. Velja relies on the same heuristic; it can be wrong for links opened by
    /// background processes, in which case source-app rules simply don't match.
    @MainActor
    static func current(urls: [URL]) -> OpenContext {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        return OpenContext(
            urls: urls,
            sourceAppBundleID: frontmost == Bundle.main.bundleIdentifier ? nil : frontmost,
            heldModifiers: NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        )
    }
}
