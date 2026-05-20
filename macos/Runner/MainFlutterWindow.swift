import Cocoa
import FlutterMacOS
import Quartz

class MainFlutterWindow: NSWindow, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
  
  var fileURLToPreview: URL?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    
    let methodChannel = FlutterMethodChannel(name: "com.viewerapp/quicklook", binaryMessenger: flutterViewController.engine.binaryMessenger)
    methodChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "showQuickLook", let args = call.arguments as? [String: Any], let path = args["path"] as? String {
        self?.fileURLToPreview = URL(fileURLWithPath: path)
        self?.showQuickLookPanel()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    super.awakeFromNib()
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
