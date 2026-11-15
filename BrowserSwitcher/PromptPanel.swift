import AppKit
import SwiftUI

/// Floating browser prompt, shown for the override modifier and "Show prompt" rules.
@MainActor
final class PromptController {
    static let shared = PromptController()

    private var panel: NSPanel?
    /// Opens the showing prompt's link without a choice, if a newer link replaces the prompt.
    private var onReplaced: (() -> Void)?

    /// `onReplaced` runs if another link arrives before this prompt is answered, so the
    /// first link isn't lost.
    func present(
        urls: [URL],
        targets: [LaunchTarget],
        onPick: @escaping (LaunchTarget) -> Void,
        onReplaced: @escaping () -> Void
    ) {
        if panel != nil { self.onReplaced?() }
        dismiss()

        let picker = BrowserPickerView(
            title: urls.first?.host ?? urls.first?.absoluteString ?? "link",
            targets: targets,
            highlightedID: SettingsStore.shared.lastPromptBrowserBundleID,
            // Deferred so the panel isn't torn down while its own button action is still running.
            onPick: { [weak self] choice in
                Task { @MainActor in
                    self?.dismiss()
                    onPick(choice)
                }
            },
            onCancel: { [weak self] in
                Task { @MainActor in
                    self?.dismiss()
                    NSApp.hide(nil) // hand focus back to the app the link came from
                }
            }
        )
        let hostingView = NSHostingView(rootView: picker)
        let size = hostingView.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = hostingView
        panel.setFrameOrigin(Self.origin(for: size))

        self.panel = panel
        self.onReplaced = onReplaced
        // We're a background app; activate so the prompt takes keyboard focus for 1–9 / Return / Esc.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        onReplaced = nil
    }

    /// Just below the cursor, kept fully on the cursor's screen.
    private static func origin(for size: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 12)
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            origin.x = min(max(origin.x, frame.minX + 8), frame.maxX - size.width - 8)
            origin.y = min(max(origin.y, frame.minY + 8), frame.maxY - size.height - 8)
        }
        return origin
    }
}

struct BrowserPickerView: View {
    let title: String
    let targets: [LaunchTarget]
    let highlightedID: String
    let onPick: (LaunchTarget) -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    private static let perRow = 9

    private var highlighted: LaunchTarget? {
        targets.first { $0.id == highlightedID } ?? targets.first
    }

    /// Entries with their position, split into rows of nine.
    private var rows: [[(index: Int, target: LaunchTarget)]] {
        let indexed = targets.enumerated().map { (index: $0.offset, target: $0.element) }
        return stride(from: 0, to: indexed.count, by: Self.perRow).map {
            Array(indexed[$0..<min($0 + Self.perRow, indexed.count)])
        }
    }

    private var shortcutCount: Int { min(targets.count, 9) }

    var body: some View {
        VStack(spacing: 14) {
            Text("Open \(title) in…")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 420)

            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(rows[row], id: \.target.id) { item in
                            TargetTile(
                                target: item.target,
                                shortcut: item.index < 9 ? item.index + 1 : nil,
                                isHighlighted: item.target.id == highlighted?.id
                            ) {
                                onPick(item.target)
                            }
                        }
                    }
                }
            }

            Text("\(shortcutCount == 1 ? "1" : "1–\(shortcutCount)") to choose · Return for highlighted · Esc to cancel")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 24) // clears the hidden title bar
        .padding(.bottom, 16)
        .background(.regularMaterial)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
        .onKeyPress(.return) {
            if let highlighted {
                onPick(highlighted)
            }
            return .handled
        }
        .onKeyPress(characters: .decimalDigits, phases: .down) { press in
            guard let number = Int(press.characters), (1...shortcutCount).contains(number) else { return .ignored }
            onPick(targets[number - 1])
            return .handled
        }
    }
}

/// A browser's icon, badged with the profile's picture (or initial) for profile entries.
struct LaunchTargetIcon: View {
    let target: LaunchTarget
    let size: CGFloat

    var body: some View {
        Image(nsImage: target.browser.icon(size: size))
            .overlay(alignment: .bottomTrailing) {
                if let profile = target.profile {
                    badge(for: profile)
                        .frame(width: size * 0.46, height: size * 0.46)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.background, lineWidth: max(1, size / 24)))
                        .offset(x: size * 0.06, y: size * 0.06)
                }
            }
    }

    @ViewBuilder
    private func badge(for profile: BrowserProfile) -> some View {
        if let picture = profile.picture {
            Image(nsImage: picture)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(Color.accentColor)
                .overlay {
                    Text(profile.name.prefix(1).uppercased())
                        .font(.system(size: size * 0.26, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
    }
}

private struct TargetTile: View {
    let target: LaunchTarget
    let shortcut: Int?
    let isHighlighted: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                LaunchTargetIcon(target: target, size: 48)
                    .padding(.bottom, 2)
                Text(target.title)
                    .font(.callout)
                    .lineLimit(1)
                // Always reserve the line so profile and plain tiles line up.
                Text(target.subtitle ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(shortcut.map(String.init) ?? " ")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 96)
            .padding(.vertical, 10)
            .background(tileBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("Open in \(target.subtitle.map { "\($0), \(target.title) profile" } ?? target.title)")
        .accessibilityHint(shortcut.map { "Keyboard shortcut \($0)" } ?? "")
    }

    private var tileBackground: AnyShapeStyle {
        if isHighlighted {
            return AnyShapeStyle(Color.accentColor.opacity(0.22))
        }
        if isHovering {
            return AnyShapeStyle(HierarchicalShapeStyle.quaternary)
        }
        return AnyShapeStyle(Color.clear)
    }
}
