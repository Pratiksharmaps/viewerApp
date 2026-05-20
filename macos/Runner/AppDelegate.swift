import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

  static var pendingFile: String?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // ✅ MODERN API - this is what Finder "Open With" actually uses on macOS 10.13+
  override func application(_ application: NSApplication, open urls: [URL]) {
    NSLog("🟢 [AppDelegate] application(_:open:) called with \(urls.count) URL(s)")
    guard let url = urls.first else { return }
    NSLog("🟢 [AppDelegate] URL = \(url.path)")
    NSApp.activate(ignoringOtherApps: true)
    AppDelegate.pendingFile = url.path
    if let window = mainFlutterWindow as? MainFlutterWindow {
      NSLog("🟢 [AppDelegate] Window exists, sending file directly")
      window.sendFileToFlutter(path: url.path)
    } else {
      NSLog("⚠️ [AppDelegate] Window not ready yet, stored in pendingFile")
    }
  }

  // Legacy API fallback
  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    NSLog("🟡 [AppDelegate] application(_:openFile:) called with \(filename)")
    NSApp.activate(ignoringOtherApps: true)
    AppDelegate.pendingFile = filename
    if let window = mainFlutterWindow as? MainFlutterWindow {
      window.sendFileToFlutter(path: filename)
    }
    return true
  }
}
