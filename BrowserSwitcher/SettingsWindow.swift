import AppKit
import SwiftUI

/// The Settings window, with native toolbar tabs.
///
/// Managed in AppKit rather than as a SwiftUI `Settings` scene because the app delegate
/// must open it (on launch and when the app is reopened from Finder), and SwiftUI only
/// lets views open a `Settings` scene.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private static let contentSize = NSSize(width: 560, height: 480)

    private var window: NSWindow?

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func makeWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab("Schedule", symbol: "clock", ScheduleSettings()))
        tabs.addTabViewItem(Self.tab("Prompt", symbol: "cursorarrow.click", PromptSettings()))
        tabs.addTabViewItem(Self.tab("Rules", symbol: "list.bullet.rectangle", RulesSettings()))
        tabs.addTabViewItem(Self.tab("General", symbol: "gearshape", GeneralSettings()))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.setContentSize(Self.contentSize)
        window.center()
        return window
    }

    /// The tab controller sizes the window from each tab's `preferredContentSize`, so pin it;
    /// otherwise the hosting controller reports its own size and the window clips the form.
    /// The tab's title also becomes the window title.
    private static func tab<Content: View>(_ title: String, symbol: String, _ content: Content) -> NSTabViewItem {
        let controller = NSHostingController(rootView: content.frame(width: contentSize.width, height: contentSize.height))
        controller.sizingOptions = []
        controller.preferredContentSize = contentSize
        controller.view.frame = NSRect(origin: .zero, size: contentSize)
        controller.title = title

        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}

private struct ScheduleSettings: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var detector = BrowserDetector.shared

    var body: some View {
        Form {
            Section {
                BrowserPicker("Work browser", selection: $store.workBrowserBundleID, detector: detector)
                BrowserPicker("Personal browser", selection: $store.personalBrowserBundleID, detector: detector)
            } header: {
                Text("Browsers")
            } footer: {
                Text("Browsers with several profiles list each one, so you can send work and personal links to different Chrome profiles.")
            }

            Section {
                Toggle("Use work browser during work hours", isOn: $store.scheduleEnabled)
                Group {
                    DatePicker("Starts", selection: time(\.workStartMinutes), displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: time(\.workEndMinutes), displayedComponents: .hourAndMinute)
                    LabeledContent("Days") {
                        WeekdayPicker(selection: $store.workWeekdays)
                    }
                }
                .disabled(!store.scheduleEnabled)
            } header: {
                Text("Work hours")
            } footer: {
                Text("Outside these hours, and on unselected days, links open in your personal browser.")
            }
        }
        .formStyle(.grouped)
        .helpButton(section: "schedule")
        .onAppear { detector.refresh() }
    }

    private func time(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Int>) -> Binding<Date> {
        Binding(
            get: { TimeOfDay.date(minutes: store[keyPath: keyPath]) },
            set: { store[keyPath: keyPath] = TimeOfDay.minutes(from: $0) }
        )
    }
}

private struct PromptSettings: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var detector = BrowserDetector.shared

    var body: some View {
        Form {
            Section {
                Toggle("Show the browser prompt while a key is held", isOn: $store.promptOnModifier)
                Picker("Key", selection: $store.overrideModifier) {
                    ForEach(OverrideModifier.allCases) { modifier in
                        Text(modifier.label).tag(modifier)
                    }
                }
                .disabled(!store.promptOnModifier)
            } header: {
                Text("Modifier key")
            } footer: {
                Text("Hold the key while clicking a link to pick a browser for just that link. This takes priority over rules and the schedule. If Fn doesn't register on your keyboard, choose another key.")
            }

            Section {
                ForEach(detector.launchTargets) { target in
                    Toggle(isOn: Binding(
                        get: { !store.hiddenPromptTargetIDs.contains(target.id) },
                        set: { store.setPromptTarget(target.id, shown: $0) }
                    )) {
                        HStack(spacing: 10) {
                            LaunchTargetIcon(target: target, size: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(target.title)
                                if let subtitle = target.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Browsers in the prompt")
            } footer: {
                Text("Turn off anything you never pick. Browsers with several profiles get one entry per profile. Copies in the Trash or in developer-tool caches aren't listed.")
            }

            Section("In the prompt") {
                LabeledContent("Choose a browser", value: "Click, or press 1–9")
                LabeledContent("Use the highlighted browser", value: "Return")
                LabeledContent("Cancel", value: "Esc")
            }
        }
        .formStyle(.grouped)
        .helpButton(section: "prompt")
        .onAppear { detector.refresh() }
    }
}

private struct GeneralSettings: View {
    @ObservedObject private var system = DefaultBrowserManager.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    Label(
                        system.isDefaultBrowser ? "BrowserSwitcher is the default browser" : "Not the default browser",
                        systemImage: system.isDefaultBrowser ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(system.isDefaultBrowser ? Color.green : Color.orange)
                }
                if !system.isDefaultBrowser {
                    Button("Make Default Browser…") {
                        system.makeDefaultBrowser()
                    }
                }
            } header: {
                Text("Default browser")
            } footer: {
                Text("BrowserSwitcher receives every link you click and forwards it to the right browser. macOS asks you to confirm this once.")
            }

            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { system.launchesAtLogin },
                    set: { system.setLaunchesAtLogin($0) }
                ))
            } header: {
                Text("Startup")
            } footer: {
                Text("Can't see the menu-bar icon? It may be hidden behind the notch or turned off in System Settings → Menu Bar. Opening BrowserSwitcher from Applications always brings up this window.")
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
            }
        }
        .formStyle(.grouped)
        .helpButton(section: "general")
        .onAppear { system.refresh() }
    }
}

/// A browser popup listing each browser, and each profile of a multi-profile browser.
/// Keeps an unlisted selection visible (e.g. plain "Google Chrome" saved before profiles existed).
struct BrowserPicker: View {
    private let title: String
    @Binding private var selection: String
    @ObservedObject private var detector: BrowserDetector

    init(_ title: String, selection: Binding<String>, detector: BrowserDetector) {
        self.title = title
        self._selection = selection
        self.detector = detector
    }

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Not set").tag("")
            ForEach(detector.launchTargets) { target in
                Label {
                    Text(target.menuLabel)
                } icon: {
                    Image(nsImage: target.menuIcon(size: 16))
                }
                .tag(target.id)
            }
            if !selection.isEmpty, !detector.launchTargets.contains(where: { $0.id == selection }) {
                Text(detector.unlistedLabel(forID: selection)).tag(selection)
            }
        }
    }
}

/// Mon–Sun toggle buttons; selected days use the accent color.
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Weekdays.displayOrder, id: \.self) { day in
                Toggle(Weekdays.shortName(day), isOn: Binding(
                    get: { selection.contains(day) },
                    set: { isOn in
                        if isOn {
                            selection.insert(day)
                        } else {
                            selection.remove(day)
                        }
                    }
                ))
                .toggleStyle(.button)
            }
        }
    }
}
