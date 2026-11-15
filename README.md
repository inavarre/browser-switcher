# BrowserSwitcher

A small macOS menu-bar app that opens links in your **work browser during work hours** and your **personal browser the rest of the time**, with rules and a quick prompt for the exceptions.

BrowserSwitcher registers itself as your Mac's default browser but never shows web pages itself. Every link you click in another app (Mail, Slack, Notes…) goes to BrowserSwitcher first, and it immediately forwards the link, unchanged, to the right real browser.

## Features

- **Schedule**: pick a work browser, a personal browser, work hours (overnight ranges work) and work days.
- **Browser profiles**: Chrome, Brave and Edge profiles show up as separate choices, so a link can open straight in your work profile.
- **Rules**: route by the app the link was clicked in (for example Slack), by link host with `*` / `?` wildcards (for example `*.atlassian.net`), or both. First match wins.
- **Prompt**: hold a key (Fn, Option, Shift, Control or Command) while clicking a link to choose a browser for that one link. Press 1–9 or Return to pick, Esc to cancel.
- **Never drops a link**: if the chosen browser isn't installed it falls back to your other browser, then Safari.
- Launch at login, light and dark mode, built-in help.

## How a link is routed

1. Holding the prompt key? Show the browser prompt.
2. A rule matches? Open in that rule's browser (or show the prompt).
3. Otherwise use the schedule: work browser during work hours, personal browser the rest of the time.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later to build from source

## Install

### Build from source

```bash
git clone https://github.com/inavarre/browser-switcher.git
cd browser-switcher
xcodebuild -project BrowserSwitcher.xcodeproj -scheme BrowserSwitcher -configuration Release -derivedDataPath build
cp -R build/Build/Products/Release/BrowserSwitcher.app /Applications/
open /Applications/BrowserSwitcher.app
```

Or open `BrowserSwitcher.xcodeproj` in Xcode and press Run. The project is ad-hoc signed, so no Apple developer account is needed. If you fork it, change the bundle identifier in the project settings so your build doesn't clash with someone else's.

### Pre-built app

If a `.zip` is attached to a [release](https://github.com/inavarre/browser-switcher/releases), unzip it and move `BrowserSwitcher.app` to **Applications** before opening it (run from Downloads, macOS moves it to a random location and the default-browser and login settings won't stick).

The app is not notarized by Apple, so macOS blocks the first launch. Either open it once, then go to **System Settings → Privacy & Security** and click **Open Anyway**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/BrowserSwitcher.app
```

After updating to a new build you may need to turn **Launch at login** back on and confirm the default browser again.

## Getting started

1. Open BrowserSwitcher. Its icon appears in the menu bar; opening the app again from Applications opens Settings.
2. On the **Schedule** tab, choose your work and personal browsers, work hours and work days.
3. Click **Make Default Browser…** and confirm in the macOS dialog.
4. Click a link in another app to check it opens where you expect.

The full guide is in the app under **Help**.

## Uninstall

Choose another default browser in **System Settings → Desktop & Dock → Default web browser**, quit BrowserSwitcher from its menu, then delete it from Applications.

## Privacy

BrowserSwitcher makes no network requests and collects nothing. To list Chromium profiles it reads each browser's local `Local State` file and profile pictures. Settings are stored in the app's local preferences.

## Why the app isn't sandboxed

The macOS App Sandbox blocks setting the default browser and launching arbitrary browsers, so the sandbox is off. This also means the app can't be distributed through the Mac App Store.

## License

[MIT](LICENSE)
