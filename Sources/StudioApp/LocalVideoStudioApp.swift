import AppKit
import SwiftUI

@main
struct LocalVideoStudioApp: App {
  init() {
    NSApplication.shared.setActivationPolicy(.regular)
    if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
      let icon = NSImage(contentsOf: iconURL)
    {
      NSApplication.shared.applicationIconImage = icon
    }
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  var body: some Scene {
    WindowGroup {
      StudioWorkspace()
        .frame(minWidth: 390, minHeight: 620)
    }
    .defaultSize(width: 1440, height: 900)
    .windowStyle(.hiddenTitleBar)
  }
}
