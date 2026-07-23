# Zoom Mute Status

A tiny native macOS menu bar app that shows, at a glance, whether your Zoom
microphone is muted — without switching to the Zoom window.

Zoom can put an icon in the menu bar, but it doesn't tell you whether you're
currently muted. If you rely on global mute/unmute shortcuts while working in
other apps, there's no quick way to see your state. This app adds a
color-coded microphone icon that always reflects it.

## Features

- Native Swift / AppKit — a single ~130 KB agent app, no runtime dependencies.
- Reads Zoom's mute state directly through the macOS **Accessibility API**
  (a short menu-bar walk), polled at 10 Hz, so the icon updates effectively
  instantly.
- Color-coded [SF Symbols](https://developer.apple.com/sf-symbols/) in the
  menu bar:
  - 🔴 red `microphone.slash.fill` — **muted**
  - 🟢 green `microphone.fill` — **live** (unmuted)
  - ⚪️ gray — not in a meeting
  - ⚠️ orange — Accessibility permission missing
- Menu with live status text, a **Launch at Login** toggle (`SMAppService`),
  a shortcut to the Accessibility settings pane, and Quit.
- Runs as a menu-bar agent (`LSUIElement`) — no Dock icon.

## Requirements

- macOS 13 Ventura or later (uses `SMAppService`).
- Xcode 15 or later to build.

## Build & install

```bash
xcodebuild -project ZoomMuteStatus.xcodeproj -scheme "Zoom Mute Status" -configuration Release build
```

The built app lands in the printed `Build/Products/Release/` path. Copy it to
`/Applications`:

```bash
cp -R "$(xcodebuild -project ZoomMuteStatus.xcodeproj -scheme "Zoom Mute Status" -configuration Release -showBuildSettings 2>/dev/null | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / FULL_PRODUCT_NAME /{n=$2} END{print d"/"n}')" /Applications/
```

Or just open `ZoomMuteStatus.xcodeproj` in Xcode and run.

## Accessibility permission

The app reads Zoom's menus through the Accessibility API, so it needs
Accessibility access. On first launch macOS prompts you; you can also enable it
manually:

**System Settings → Privacy & Security → Accessibility → enable "Zoom Mute Status".**

Menu titles are matched in English, so run Zoom with an English UI.

### A note on code signing and permission persistence

macOS ties the Accessibility grant to the app's **code signature**. An
ad-hoc-signed build (the project default, `CODE_SIGN_IDENTITY = "-"`) may not
keep the grant across launches or rebuilds on recent macOS. If you want the
permission to stick, sign with a stable certificate — a Developer ID or an
Apple Development identity:

```bash
codesign --force --deep --sign "Apple Development: you@example.com (TEAMID)" "/Applications/Zoom Mute Status.app"
```

Then grant Accessibility once; it will persist as long as you keep signing with
the same identity.

## Inspired by

Inspired by [abersager/zoom-mute-status](https://github.com/abersager/zoom-mute-status),
the original menu-bar take on this idea. This app is an independent native
rewrite and shares no code or assets with it.

## License

[MIT](LICENSE) © 2026 Marius Malyshev
