import Foundation

/// All user settings, persisted to `UserDefaults` as they change.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private enum Keys {
        static let workBrowser = "workBrowserBundleID"
        static let personalBrowser = "personalBrowserBundleID"
        static let scheduleEnabled = "scheduleEnabled"
        static let workStart = "workStartMinutes"
        static let workEnd = "workEndMinutes"
        static let workWeekdays = "workWeekdays"
        static let promptOnModifier = "promptOnModifier"
        static let overrideModifier = "overrideModifier"
        static let rules = "rules"
        static let lastPromptBrowser = "lastPromptBrowserBundleID"
        static let hiddenPromptTargets = "hiddenPromptTargetIDs"
    }

    /// Apps that can open links but aren't browsers, so they start out hidden from the prompt.
    static let defaultHiddenPromptTargets: Set<String> = ["com.googlecode.iterm2", "com.apple.Terminal"]

    private let defaults: UserDefaults

    @Published var workBrowserBundleID: String {
        didSet { defaults.set(workBrowserBundleID, forKey: Keys.workBrowser) }
    }
    @Published var personalBrowserBundleID: String {
        didSet { defaults.set(personalBrowserBundleID, forKey: Keys.personalBrowser) }
    }
    /// When off, it's never "work time", so the schedule always picks the personal browser.
    @Published var scheduleEnabled: Bool {
        didSet { defaults.set(scheduleEnabled, forKey: Keys.scheduleEnabled) }
    }
    @Published var workStartMinutes: Int {
        didSet { defaults.set(workStartMinutes, forKey: Keys.workStart) }
    }
    @Published var workEndMinutes: Int {
        didSet { defaults.set(workEndMinutes, forKey: Keys.workEnd) }
    }
    @Published var workWeekdays: Set<Int> {
        didSet { defaults.set(workWeekdays.sorted(), forKey: Keys.workWeekdays) }
    }
    @Published var promptOnModifier: Bool {
        didSet { defaults.set(promptOnModifier, forKey: Keys.promptOnModifier) }
    }
    @Published var overrideModifier: OverrideModifier {
        didSet { defaults.set(overrideModifier.rawValue, forKey: Keys.overrideModifier) }
    }
    @Published var rules: [Rule] {
        didSet {
            if let data = try? JSONEncoder().encode(rules) {
                defaults.set(data, forKey: Keys.rules)
            }
        }
    }
    /// The `LaunchTarget.id` last picked in the prompt, highlighted so Return reopens it.
    @Published var lastPromptBrowserBundleID: String {
        didSet { defaults.set(lastPromptBrowserBundleID, forKey: Keys.lastPromptBrowser) }
    }
    /// `LaunchTarget.id`s turned off in the prompt.
    @Published var hiddenPromptTargetIDs: Set<String> {
        didSet { defaults.set(hiddenPromptTargetIDs.sorted(), forKey: Keys.hiddenPromptTargets) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        workBrowserBundleID = defaults.string(forKey: Keys.workBrowser) ?? ""
        personalBrowserBundleID = defaults.string(forKey: Keys.personalBrowser) ?? ""
        scheduleEnabled = defaults.object(forKey: Keys.scheduleEnabled) as? Bool ?? true
        workStartMinutes = defaults.object(forKey: Keys.workStart) as? Int ?? 9 * 60
        workEndMinutes = defaults.object(forKey: Keys.workEnd) as? Int ?? 17 * 60
        workWeekdays = (defaults.array(forKey: Keys.workWeekdays) as? [Int]).map(Set.init) ?? Weekdays.workweek
        promptOnModifier = defaults.object(forKey: Keys.promptOnModifier) as? Bool ?? true
        overrideModifier = defaults.string(forKey: Keys.overrideModifier).flatMap(OverrideModifier.init(rawValue:)) ?? .function
        rules = defaults.data(forKey: Keys.rules).flatMap { try? JSONDecoder().decode([Rule].self, from: $0) } ?? []
        lastPromptBrowserBundleID = defaults.string(forKey: Keys.lastPromptBrowser) ?? ""
        hiddenPromptTargetIDs = (defaults.array(forKey: Keys.hiddenPromptTargets) as? [String]).map(Set.init)
            ?? Self.defaultHiddenPromptTargets
    }

    func setPromptTarget(_ id: LaunchTarget.ID, shown: Bool) {
        if shown {
            hiddenPromptTargetIDs.remove(id)
        } else {
            hiddenPromptTargetIDs.insert(id)
        }
    }

    func moveRule(id: Rule.ID, by offset: Int) {
        guard let from = rules.firstIndex(where: { $0.id == id }), rules.indices.contains(from + offset) else { return }
        rules.swapAt(from, from + offset)
    }

    func deleteRule(id: Rule.ID) {
        rules.removeAll { $0.id == id }
    }
}
