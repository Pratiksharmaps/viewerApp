import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    
  var methodChannel: FlutterMethodChannel?
  var pendingFileToOpen: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
      
    if let controller = window?.rootViewController as? FlutterViewController {
        methodChannel = FlutterMethodChannel(name: "com.viewerapp/file_events", binaryMessenger: controller.binaryMessenger)
        
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "ready" {
                if let pending = self?.pendingFileToOpen {
                    self?.methodChannel?.invokeMethod("onFileOpened", arguments: ["path": pending])
                    self?.pendingFileToOpen = nil
                }
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
      
    if let url = launchOptions?[.url] as? URL {
        handleIncomingURL(url)
    }
      
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
      handleIncomingURL(url)
      return true
  }
    
  private func handleIncomingURL(_ url: URL) {
      let isSecurityScoped = url.startAccessingSecurityScopedResource()
      defer {
          if isSecurityScoped {
              url.stopAccessingSecurityScopedResource()
          }
      }
      
      let tempDir = FileManager.default.temporaryDirectory
      let destURL = tempDir.appendingPathComponent(url.lastPathComponent)
      
      do {
          if FileManager.default.fileExists(atPath: destURL.path) {
              try FileManager.default.removeItem(at: destURL)
          }
          try FileManager.default.copyItem(at: url, to: destURL)
          
          let filePath = destURL.path
          if let channel = methodChannel {
              channel.invokeMethod("onFileOpened", arguments: ["path": filePath])
          } else {
              pendingFileToOpen = filePath
          }
      } catch {
          print("Failed to copy file: \(error)")
      }
  }
}
