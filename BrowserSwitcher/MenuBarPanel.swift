import SwiftUI

/// The compact panel shown from the menu-bar icon: status and quick actions.
struct MenuBarPanel: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var detector = BrowserDetector.shared
    @ObservedObject private var system = DefaultBrowserManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusCard

            if !system.isDefaultBrowser {
                defaultBrowserCallout
            }

            if isMissingBrowsers {
                Label("Choose your work and personal browsers in Settings.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .symbolRenderingMode(.multicolor)
            }

            VStack(spacing: 6) {
                switchRow("Work hours schedule", isOn: $store.scheduleEnabled)
                switchRow("Launch at login", isOn: Binding(
                    get: { system.launchesAtLogin },
                    set: { system.setLaunchesAtLogin($0) }
                ))
            }

            Divider()

            HStack {
                Button("Test Link") {
                    if let url = URL(string: "https://example.com") {
                        LinkHandler.handle([url])
                    }
                }
                .help("Opens example.com through your current rules and schedule")
                Spacer()
                Button("Help") {
                    HelpWindowController.shared.show()
                }
                Button("Settings…") {
                    SettingsWindowController.shared.show()
                }
                .keyboardShortcut(",")
            }

            Button("Quit BrowserSwitcher") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 300)
        .onAppear {
            detector.refresh()
            system.refresh()
        }
    }

    private var statusCard: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let isWork = DecisionEngine.isWorkTime(store: store, now: timeline.date)
            let active = detector.target(forID: DecisionEngine.scheduledTargetID(store: store, now: timeline.date))
            let period = isWork ? "Work hours · until \(TimeOfDay.string(minutes: store.workEndMinutes))" : "Personal time"
            HStack(spacing: 10) {
                if let active {
                    LaunchTargetIcon(target: active, size: 32)
                } else {
                    Image(systemName: "globe")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(active?.title ?? "No browser chosen")
                        .font(.body.weight(.semibold))
                    // "Google Chrome · Personal time" for a profile, so the browser is still named.
                    Text([active?.subtitle, period].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private var defaultBrowserCallout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not your default browser yet")
                .font(.callout.weight(.semibold))
            Text("Links aren't routed until BrowserSwitcher is the default. macOS asks you to confirm once.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Make Default Browser…") {
                system.makeDefaultBrowser()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var isMissingBrowsers: Bool {
        detector.target(forID: store.workBrowserBundleID) == nil
            || detector.target(forID: store.personalBrowserBundleID) == nil
    }

    private func switchRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}
