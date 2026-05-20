import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

  // Shared pending file - set by openFile before Flutter is ready
  static var pendingFile: String?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    NSApp.activate(ignoringOtherApps: true)

    // Store the path - MainFlutterWindow will pick it up once Flutter is ready
    AppDelegate.pendingFile = filename

    // If the window already has an active channel (app was already running), invoke directly
    if let window = mainFlutterWindow as? MainFlutterWindow {
      window.sendFileToFlutter(path: filename)
    }

    return true
  }
}
