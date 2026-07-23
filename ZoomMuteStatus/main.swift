import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu bar agent: no Dock icon, no main menu. Reinforces LSUIElement.
app.setActivationPolicy(.accessory)
app.run()
