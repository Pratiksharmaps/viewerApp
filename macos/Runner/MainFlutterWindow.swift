import Cocoa
import FlutterMacOS
import Quartz

class MainFlutterWindow: NSWindow, QLPreviewPanelDataSource, QLPreviewPanelDelegate {

  var fileURLToPreview: URL?
  var fileEventsChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    NSLog("🔵 [MainFlutterWindow] awakeFromNib called")
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    RegisterGeneratedPlugins(registry: flutterViewController)

    fileEventsChannel = FlutterMethodChannel(
      name: "com.viewerapp/file_events",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    fileEventsChannel?.setMethodCallHandler { [weak self] (call, result) in
      NSLog("🔵 [MainFlutterWindow] Dart called: \(call.method)")
      if call.method == "ready" {
        NSLog("🔵 [MainFlutterWindow] Flutter is ready. pendingFile = \(AppDelegate.pendingFile ?? "nil")")
        if let pending = AppDelegate.pendingFile {
          AppDelegate.pendingFile = nil
          NSLog("🔵 [MainFlutterWindow] Sending pending file to Flutter: \(pending)")
          self?.fileEventsChannel?.invokeMethod("onFileOpened", arguments: ["path": pending])
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    let quickLookChannel = FlutterMethodChannel(
      name: "com.viewerapp/quicklook",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    quickLookChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "showQuickLook",
         let args = call.arguments as? [String: Any],
         let path = args["path"] as? String {
        NSLog("🔵 [MainFlutterWindow] showQuickLook for: \(path)")
        self?.fileURLToPreview = URL(fileURLWithPath: path)
        self?.showQuickLookPanel()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
    NSLog("🔵 [MainFlutterWindow] setup complete")
  }

  func sendFileToFlutter(path: String) {
    NSLog("🔵 [MainFlutterWindow] sendFileToFlutter: \(path)")
    if let channel = fileEventsChannel {
      channel.invokeMethod("onFileOpened", arguments: ["path": path])
    } else {
      NSLog("⚠️ [MainFlutterWindow] channel not ready, storing in pendingFile")
      AppDelegate.pendingFile = path
    }
  }

  func showQuickLookPanel() {
    NSApp.activate(ignoringOtherApps: true)
    self.makeKeyAndOrderFront(nil)
    if let panel = QLPreviewPanel.shared() {
      self.makeFirstResponder(self)
      panel.updateController()
      panel.makeKeyAndOrderFront(nil)
      panel.reloadData()
    }
  }

  func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
    return fileURLToPreview != nil ? 1 : 0
  }

  func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
    return fileURLToPreview as QLPreviewItem?
  }

  override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
    return true
  }

  override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
    panel.delegate = self
    panel.dataSource = self
  }

  override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
    panel.delegate = nil
    panel.dataSource = nil
  }
}
