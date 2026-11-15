import AppKit
import os

extension Logger {
    static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BrowserSwitcher", category: "app")
}

/// What a rule does when it matches a link.
enum RuleAction: Codable, Hashable {
    /// Holds a `LaunchTarget.id` (a browser, or `bundleID#Profile` for one profile). The label stays
    /// `bundleID` so rules saved before profiles existed still decode.
    case browser(bundleID: String)
    case prompt
}

/// A user-defined routing rule. Set conditions are ANDed; an empty condition means "any".
/// A rule with no conditions at all never matches, so a freshly added rule can't hijack every link.
struct Rule: Identifiable, Codable, Hashable {
    var id = UUID()
    var enabled = true
    var name = ""
    /// Bundle id of the app the link was clicked in (e.g. `com.tinyspeck.slackmacgap`). Empty = any app.
    var sourceAppBundleID = ""
    /// Host glob such as `github.com` or `*.atlassian.net`. Empty = any host.
    var urlHostPattern = ""
    var action: RuleAction = .prompt

    var hasConditions: Bool {
        !sourceAppBundleID.trimmingCharacters(in: .whitespaces).isEmpty
            || !urlHostPattern.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func matches(sourceApp: String?, host: String?) -> Bool {
        guard hasConditions else { return false }
        let wantedSource = sourceAppBundleID.trimmingCharacters(in: .whitespaces)
        if !wantedSource.isEmpty {
            guard let sourceApp, sourceApp.caseInsensitiveCompare(wantedSource) == .orderedSame else { return false }
        }
        let wantedHost = urlHostPattern.trimmingCharacters(in: .whitespaces)
        if !wantedHost.isEmpty {
            guard let host, Glob.matches(wantedHost, host) else { return false }
        }
        return true
    }
}

enum Glob {
    /// Case-insensitive match supporting `*` and `?`. A plain host like `github.com`
    /// also matches its subdomains (`gist.github.com`).
    static func matches(_ pattern: String, _ text: String) -> Bool {
        let pattern = pattern.lowercased()
        let text = text.lowercased()
        if !pattern.contains("*") && !pattern.contains("?") {
            return text == pattern || text.hasSuffix("." + pattern)
        }
        var regex = "^"
        for character in pattern {
            switch character {
            case "*": regex += ".*"
            case "?": regex += "."
            default: regex += NSRegularExpression.escapedPattern(for: String(character))
            }
        }
        regex += "$"
        return text.range(of: regex, options: .regularExpression) != nil
    }
}

/// The key that, held while clicking a link, forces the browser picker.
enum OverrideModifier: String, Codable, CaseIterable, Identifiable {
    case function, option, shift, control, command

    var id: String { rawValue }

    var label: String {
        switch self {
        case .function: return "Fn (Globe)"
        case .option: return "Option ⌥"
        case .shift: return "Shift ⇧"
        case .control: return "Control ⌃"
        case .command: return "Command ⌘"
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .function: return .function
        case .option: return .option
        case .shift: return .shift
        case .control: return .control
        case .command: return .command
        }
    }
}

struct BrowserInfo: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let url: URL

    var id: String { bundleID }

    func icon(size: CGFloat) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: size, height: size)
        return image
    }
}

/// A Chromium browser profile (Chrome, Brave, Edge), read from the browser's `Local State` file.
struct BrowserProfile: Hashable {
    /// Folder name such as `Profile 1`, passed to the browser as `--profile-directory`.
    let directory: String
    /// The name shown in the browser's profile menu, such as `Work`.
    let name: String
    let picture: NSImage?
}

/// One entry in the browser prompt: a browser, or one profile of a browser.
struct LaunchTarget: Identifiable, Hashable {
    let browser: BrowserInfo
    let profile: BrowserProfile?

    /// `bundleID` for a browser, `bundleID#ProfileDirectory` for a profile. Settings store these.
    var id: String { profile.map { "\(browser.bundleID)#\($0.directory)" } ?? browser.bundleID }
    var title: String { profile?.name ?? browser.name }
    var subtitle: String? { profile == nil ? nil : browser.name }
    /// "Google Chrome — Work" in pickers; just the name for a plain browser.
    var menuLabel: String { subtitle.map { "\($0) — \(title)" } ?? title }

    /// Menus can't badge an icon, so a profile shows its picture (when it has one) instead.
    func menuIcon(size: CGFloat) -> NSImage {
        guard let picture = profile?.picture?.copy() as? NSImage else { return browser.icon(size: size) }
        picture.size = NSSize(width: size, height: size)
        return picture
    }
}

enum Weekdays {
    /// `Calendar` weekday numbers (1 = Sunday … 7 = Saturday), listed Monday first.
    static let displayOrder = [2, 3, 4, 5, 6, 7, 1]
    static let workweek: Set<Int> = [2, 3, 4, 5, 6]

    static func shortName(_ weekday: Int) -> String {
        Calendar.current.shortWeekdaySymbols[weekday - 1]
    }
}

/// Times of day are stored as minutes after midnight.
enum TimeOfDay {
    static func date(minutes: Int, on day: Date = Date()) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    static func minutes(from date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func string(minutes: Int) -> String {
        date(minutes: minutes).formatted(date: .omitted, time: .shortened)
    }
}
