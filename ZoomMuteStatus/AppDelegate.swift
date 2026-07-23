import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var timer: Timer?

  private let statusInfoItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  private var grantItem: NSMenuItem!
  private var loginItem: NSMenuItem!

  private var lastState: MuteState = .notInMeeting

  // Symbol point size in the menu bar. ~15pt reads like a native status icon.
  private let iconPointSize: CGFloat = 15

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
    menu.addItem(NSMenuItem(title: "Quit Zoom Mute Status",
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
    let color: NSColor
    let description: String

    switch state {
    case .muted:
      symbolName = "microphone.slash.fill"; color = .systemRed; description = "Muted"
    case .unmuted:
      symbolName = "microphone.fill"; color = .systemGreen; description = "Unmuted"
    case .notInMeeting:
      symbolName = "microphone.fill"; color = .secondaryLabelColor; description = "Zoom not in a meeting"
    case .noPermission:
      symbolName = "exclamationmark.triangle.fill"; color = .systemOrange; description = "Accessibility permission needed"
    }

    let config = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: .regular)
      .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)?
      .withSymbolConfiguration(config)
    // Colored (non-template) so the red/green tint survives in the menu bar.
    image?.isTemplate = false
    button.image = image
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
