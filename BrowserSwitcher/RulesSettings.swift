import SwiftUI

/// The Rules tab: one grouped section per rule, checked top to bottom.
struct RulesSettings: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var detector = BrowserDetector.shared

    var body: some View {
        Form {
            Section {
                Text(store.rules.isEmpty
                     ? "No rules yet, so links follow your schedule."
                     : "Rules are checked top to bottom and the first match wins. Holding the prompt key overrides them.")
                    .foregroundStyle(.secondary)
            }

            ForEach($store.rules) { $rule in
                Section {
                    RuleHeader(
                        rule: $rule,
                        isFirst: store.rules.first?.id == rule.id,
                        isLast: store.rules.last?.id == rule.id,
                        onMove: { store.moveRule(id: rule.id, by: $0) },
                        onDelete: { store.deleteRule(id: rule.id) }
                    )
                    LabeledContent("Clicked in") {
                        SourceAppField(bundleID: $rule.sourceAppBundleID)
                    }
                    TextField("Link host", text: $rule.urlHostPattern, prompt: Text("Any — e.g. github.com, *.atlassian.net"))
                    Picker("Open in", selection: $rule.action) {
                        Text("Show prompt").tag(RuleAction.prompt)
                        Divider()
                        ForEach(detector.launchTargets) { target in
                            Label {
                                Text(target.menuLabel)
                            } icon: {
                                Image(nsImage: target.menuIcon(size: 16))
                            }
                            .tag(RuleAction.browser(bundleID: target.id))
                        }
                        if case .browser(let targetID) = rule.action,
                           !detector.launchTargets.contains(where: { $0.id == targetID }) {
                            Text(detector.unlistedLabel(forID: targetID)).tag(rule.action)
                        }
                    }
                } footer: {
                    if !rule.hasConditions {
                        Text("Add an app or a link host. A rule with neither never matches.")
                    }
                }
                .opacity(rule.enabled ? 1 : 0.55)
            }

            Section {
                Button {
                    store.rules.append(Rule())
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
        .helpButton(section: "rules")
        .onAppear { detector.refresh() }
    }
}

private struct RuleHeader: View {
    @Binding var rule: Rule
    let isFirst: Bool
    let isLast: Bool
    let onMove: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Toggle("Enabled", isOn: $rule.enabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
            TextField("Name", text: $rule.name, prompt: Text("Untitled rule"))
                .labelsHidden()
                .textFieldStyle(.plain)
                .font(.headline)
            Menu {
                Button("Move Up") { onMove(-1) }
                    .disabled(isFirst)
                Button("Move Down") { onMove(1) }
                    .disabled(isLast)
                Divider()
                Button("Delete Rule", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Rule options")
        }
    }
}

/// Bundle-id text field plus a menu of running apps to fill it from.
private struct SourceAppField: View {
    @Binding var bundleID: String

    var body: some View {
        HStack(spacing: 6) {
            if let app = Self.installedApp(bundleID) {
                Image(nsImage: app.icon)
                    .help(app.name)
            }
            TextField("App bundle ID", text: $bundleID, prompt: Text("Any app"))
                .labelsHidden()
            Menu {
                Button("Any app") { bundleID = "" }
                Divider()
                ForEach(Self.runningApps()) { app in
                    Button {
                        bundleID = app.id
                    } label: {
                        Label {
                            Text(app.name)
                        } icon: {
                            Image(nsImage: app.icon)
                        }
                    }
                }
            } label: {
                Image(systemName: "app.badge")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Pick from running apps")
            .accessibilityLabel("Pick from running apps")
        }
    }

    private struct AppChoice: Identifiable {
        let id: String
        let name: String
        let icon: NSImage
    }

    private static func smallIcon(_ image: NSImage) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: 16, height: 16)
        return copy
    }

    private static func installedApp(_ bundleID: String) -> AppChoice? {
        let trimmed = bundleID.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmed) else { return nil }
        return AppChoice(
            id: trimmed,
            name: url.deletingPathExtension().lastPathComponent,
            icon: smallIcon(NSWorkspace.shared.icon(forFile: url.path))
        )
    }

    private static func runningApps() -> [AppChoice] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> AppChoice? in
                guard let id = app.bundleIdentifier,
                      id != Bundle.main.bundleIdentifier,
                      seen.insert(id).inserted,
                      let icon = app.icon
                else { return nil }
                return AppChoice(id: id, name: app.localizedName ?? id, icon: smallIcon(icon))
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
