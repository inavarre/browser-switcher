import Foundation

enum RouteDecision: Equatable {
    case open(LaunchTarget)
    case prompt
}

enum RulesEngine {
    /// Rules are checked top to bottom; the first enabled match wins.
    static func firstMatch(in rules: [Rule], sourceApp: String?, host: String?) -> Rule? {
        rules.first { $0.enabled && $0.matches(sourceApp: sourceApp, host: host) }
    }
}

/// Decides where a link goes. First match wins:
/// 1. override modifier held → picker
/// 2. first matching rule → its browser or profile, or the picker
/// 3. schedule → work or personal browser or profile
@MainActor
enum DecisionEngine {
    static let safariBundleID = "com.apple.Safari"

    static func decide(_ context: OpenContext, store: SettingsStore, browsers: BrowserDetector, now: Date = Date()) -> RouteDecision {
        if store.promptOnModifier, context.heldModifiers.contains(store.overrideModifier.flag) {
            return .prompt
        }

        if let rule = RulesEngine.firstMatch(in: store.rules, sourceApp: context.sourceAppBundleID, host: context.host) {
            switch rule.action {
            case .prompt:
                return .prompt
            case .browser(let targetID):
                if let target = browsers.target(forID: targetID) {
                    return .open(target)
                }
                // The rule's browser is no longer installed; fall through to the schedule.
            }
        }

        return .open(scheduledTarget(store: store, browsers: browsers, now: now))
    }

    static func isWorkTime(store: SettingsStore, now: Date) -> Bool {
        guard store.scheduleEnabled,
              store.workWeekdays.contains(Calendar.current.component(.weekday, from: now))
        else { return false }

        let minute = TimeOfDay.minutes(from: now)
        let start = store.workStartMinutes
        let end = store.workEndMinutes
        if start == end { return false }
        // A range like 22:00–06:00 wraps past midnight.
        return start < end ? (start..<end).contains(minute) : (minute >= start || minute < end)
    }

    /// The saved choice (`LaunchTarget.id`) the schedule picks right now.
    static func scheduledTargetID(store: SettingsStore, now: Date) -> String {
        isWorkTime(store: store, now: now) ? store.workBrowserBundleID : store.personalBrowserBundleID
    }

    /// Never fails, so a link is never dropped: scheduled choice → the other configured one → Safari.
    static func scheduledTarget(store: SettingsStore, browsers: BrowserDetector, now: Date) -> LaunchTarget {
        let isWork = isWorkTime(store: store, now: now)
        let candidates = isWork
            ? [store.workBrowserBundleID, store.personalBrowserBundleID, safariBundleID]
            : [store.personalBrowserBundleID, store.workBrowserBundleID, safariBundleID]
        for id in candidates {
            if let target = browsers.target(forID: id) {
                return target
            }
        }
        let safari = BrowserInfo(bundleID: safariBundleID, name: "Safari", url: URL(fileURLWithPath: "/Applications/Safari.app"))
        return LaunchTarget(browser: safari, profile: nil)
    }
}
