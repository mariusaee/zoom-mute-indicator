import AppKit
import ApplicationServices

/// Current Zoom microphone state, derived from Zoom's menu bar.
enum MuteState {
  case muted
  case unmuted
  case notInMeeting
  case noPermission
}

/// Reads Zoom's mute state via the Accessibility API.
///
/// Mirrors the AppleScript the original app used: it inspects Zoom's
/// "Meeting" menu and checks whether a "Mute audio" item exists. If it does,
/// the mic is live (the action offered is to mute); otherwise the mic is muted
/// (the menu instead offers "Unmute audio").
enum ZoomStatus {
  static let zoomBundleID = "us.zoom.xos"
  static let meetingMenuTitle = "Meeting"
  static let muteItemTitle = "Mute audio"

  /// Whether this process is trusted for Accessibility. Pass `prompt: true`
  /// to surface the system prompt directing the user to System Settings.
  static func hasAccessibilityPermission(prompt: Bool) -> Bool {
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
  }

  static func currentState() -> MuteState {
    guard hasAccessibilityPermission(prompt: false) else { return .noPermission }

    guard let zoom = NSWorkspace.shared.runningApplications.first(where: {
      $0.bundleIdentifier == zoomBundleID
    }) else {
      return .notInMeeting
    }

    let axApp = AXUIElementCreateApplication(zoom.processIdentifier)

    guard let menuBar = element(axApp, kAXMenuBarAttribute as String),
          let meetingItem = children(menuBar).first(where: { title($0) == meetingMenuTitle }),
          let meetingMenu = children(meetingItem).first
    else {
      return .notInMeeting
    }

    let hasMuteItem = children(meetingMenu).contains { title($0) == muteItemTitle }
    return hasMuteItem ? .unmuted : .muted
  }

  // MARK: - Accessibility helpers

  private static func element(_ el: AXUIElement, _ attribute: String) -> AXUIElement? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(el, attribute as CFString, &value) == .success,
          let value, CFGetTypeID(value) == AXUIElementGetTypeID()
    else { return nil }
    return (value as! AXUIElement)
  }

  private static func children(_ el: AXUIElement) -> [AXUIElement] {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &value) == .success,
          let array = value as? [AXUIElement]
    else { return [] }
    return array
  }

  private static func title(_ el: AXUIElement) -> String? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &value) == .success
    else { return nil }
    return value as? String
  }
}
