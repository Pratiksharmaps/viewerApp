import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  
  var methodChannel: FlutterMethodChannel?
  var pendingFileToOpen: String?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      methodChannel = FlutterMethodChannel(name: "com.viewerapp/file_events", binaryMessenger: controller.engine.binaryMessenger)
      
      methodChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "ready" {
          if let pending = self?.pendingFileToOpen {
            self?.methodChannel?.invokeMethod("onFileOpened", arguments: ["path": pending])
            self?.pendingFileToOpen = nil
          }
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    // Note: Even if methodChannel isn't nil, Flutter might not be listening yet, 
    // so we store it in pendingFileToOpen if Flutter hasn't called ready yet.
    // However, for files opened while the app is already running, we can just invoke.
    // To be safe, if we get openFile, we'll store it and if the channel is up, try to invoke it immediately as well.
    pendingFileToOpen = filename
    methodChannel?.invokeMethod("onFileOpened", arguments: ["path": filename])
    return true
  }
}
