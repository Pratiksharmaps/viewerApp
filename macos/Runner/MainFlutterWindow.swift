import Cocoa
import FlutterMacOS
import Quartz

class MainFlutterWindow: NSWindow, QLPreviewPanelDataSource, QLPreviewPanelDelegate {

  var fileURLToPreview: URL?
  var fileEventsChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    RegisterGeneratedPlugins(registry: flutterViewController)

    // --- File Events Channel ---
    // This channel lives here because we have guaranteed access to FlutterViewController
    fileEventsChannel = FlutterMethodChannel(
      name: "com.viewerapp/file_events",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    fileEventsChannel?.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "ready" {
        // Flutter UI is ready - check if AppDelegate queued a file for us
        if let pending = AppDelegate.pendingFile {
          AppDelegate.pendingFile = nil
          self?.fileEventsChannel?.invokeMethod("onFileOpened", arguments: ["path": pending])
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // --- QuickLook Channel ---
    let quickLookChannel = FlutterMethodChannel(
      name: "com.viewerapp/quicklook",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    quickLookChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "showQuickLook",
         let args = call.arguments as? [String: Any],
         let path = args["path"] as? String {
        self?.fileURLToPreview = URL(fileURLWithPath: path)
        self?.showQuickLookPanel()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  /// Called by AppDelegate when a file is opened while the app is already running
  func sendFileToFlutter(path: String) {
    if let channel = fileEventsChannel {
      channel.invokeMethod("onFileOpened", arguments: ["path": path])
    } else {
      // Channel not ready yet - store for when ready fires
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

  // MARK: - QLPreviewPanelDataSource

  func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
    return fileURLToPreview != nil ? 1 : 0
  }

  func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
    return fileURLToPreview as QLPreviewItem?
  }

  // MARK: - QLPreviewPanelDelegate

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
