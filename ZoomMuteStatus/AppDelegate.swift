import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var timer: Timer?

  private let statusInfoItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  private var grantItem: NSMenuItem!
  private var loginItem: NSMenuItem!

  private var lastState: MuteState = .notInMeeting

  // How often we re-read Zoom's mute state. The Accessibility read is cheap
  // (a short menu-bar walk over IPC), so even 10 Hz costs a negligible slice
  // of CPU and keeps the icon effectively instant.
  private let pollInterval: TimeInterval = 0.1

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    buildMenu()

    // Ask for Accessibility access on first launch (points the user to Settings).
    _ = ZoomStatus.hasAccessibilityPermission(prompt: true)

    update()
    timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
      self?.update()
    }
  }

  // MARK: - Menu

  private func buildMenu() {
    let menu = NSMenu()

    statusInfoItem.isEnabled = false
    menu.addItem(statusInfoItem)
    menu.addItem(.separator())

    grantItem = NSMenuItem(title: "Grant Accessibility Access…",
                           action: #selector(openAccessibilitySettings),
                           keyEquivalent: "")
    grantItem.target = self
    menu.addItem(grantItem)

    loginItem = NSMenuItem(title: "Launch at Login",
                           action: #selector(toggleLaunchAtLogin),
                           keyEquivalent: "")
    loginItem.target = self
    menu.addItem(loginItem)

    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Quit Zoom Mute Indicator",
                            action: #selector(NSApplication.terminate(_:)),
                            keyEquivalent: "q"))

    statusItem.menu = menu
  }

  // MARK: - Update

  private func update() {
    let state = ZoomStatus.currentState()
    lastState = state
    applyIcon(for: state)
    applyMenu(for: state)
  }

  private func applyIcon(for state: MuteState) {
    guard let button = statusItem.button else { return }

    let symbolName: String
    let background: NSColor
    let description: String

    switch state {
    case .muted:
      symbolName = "microphone.slash.fill"; background = .systemRed; description = "Muted"
    case .unmuted:
      symbolName = "microphone.fill"; background = .systemGreen; description = "Unmuted"
    case .notInMeeting:
      symbolName = "microphone.fill"
      background = NSColor(calibratedWhite: 0.45, alpha: 0.9); description = "Zoom not in a meeting"
    case .noPermission:
      symbolName = "exclamationmark.triangle.fill"; background = .systemOrange
      description = "Accessibility permission needed"
    }

    button.image = Self.pillIcon(symbolName: symbolName, background: background, description: description)
  }

  /// A filled rounded-rect "pill" with a bold white glyph, sized to the menu
  /// bar — far more legible than a thin monochrome symbol, like the system
  /// microphone indicator.
  private static func pillIcon(symbolName: String, background: NSColor,
                               description: String) -> NSImage {
    let thickness = NSStatusBar.system.thickness   // ~22pt
    let height = thickness + 2                        // fill the bar like the system pill
    let width = height * 1.54                         // wide, matching the system pill's width
    let radius = height * 0.5                          // fully rounded ends, like the system pill
    let glyphPoint = height * 0.62                     // a hair larger than the system mic

    let glyphConfig = NSImage.SymbolConfiguration(pointSize: glyphPoint, weight: .regular)
      .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    let glyph = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)?
      .withSymbolConfiguration(glyphConfig)
    glyph?.isTemplate = false

    // drawingHandler re-renders at the display's backing scale, so it stays
    // crisp on Retina.
    let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
      let pill = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
      background.setFill()
      pill.fill()
      if let glyph = glyph {
        let g = glyph.size
        glyph.draw(in: NSRect(x: rect.midX - g.width / 2, y: rect.midY - g.height / 2,
                              width: g.width, height: g.height))
      }
      return true
    }
    // Colored (non-template) so the red/green fill survives in the menu bar.
    image.isTemplate = false
    return image
  }

  private func applyMenu(for state: MuteState) {
    switch state {
    case .muted:        statusInfoItem.title = "Microphone: Muted"
    case .unmuted:      statusInfoItem.title = "Microphone: Unmuted"
    case .notInMeeting: statusInfoItem.title = "Zoom: not in a meeting"
    case .noPermission: statusInfoItem.title = "Accessibility access needed"
    }

    grantItem.isHidden = ZoomStatus.hasAccessibilityPermission(prompt: false)
    loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
  }

  // MARK: - Actions

  @objc private func openAccessibilitySettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
  }

  @objc private func toggleLaunchAtLogin() {
    do {
      if SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
      } else {
        try SMAppService.mainApp.register()
      }
    } catch {
      NSLog("Failed to toggle Launch at Login: \(error.localizedDescription)")
    }
    applyMenu(for: lastState)
  }
}
