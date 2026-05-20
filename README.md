# Mac Document Viewer

A lightweight, native macOS document viewer built with Flutter. It seamlessly integrates with Apple's QuickLook framework to instantly preview Microsoft Word (`.doc`, `.docx`) and Excel (`.xls`, `.xlsx`) files, and now features an interactive **in-app plain-text and spreadsheet editor** with a stunning Glassmorphic UI!

## Features

* **QuickLook Integration:** Bypasses heavy document parsing by handing the file directly to macOS's highly optimized `QLPreviewPanel` daemon for pixel-perfect previews.
* **In-App Editing:** 
  * Edit `.xlsx` files using a native data grid viewer powered by `spreadsheet_decoder`.
  * Edit `.docx` files as plain text. 
  * **Save Flows:** Choose to safely "Save As Copy" or overwrite the original `.docx`/`.xlsx` file directly from the app.
  * **Native Fallback:** Older binary formats (`.doc`, `.xls`) or files requiring full rich-text formatting gracefully fallback and open in your Mac's default heavy office suite with a single click.
* **Modern Glassmorphic UI:** A beautifully blurred, translucent user interface that matches modern iOS and macOS design aesthetics.
* **Recent Files History:** A convenient sidebar tracks your recently opened files for quick access. Click to select, or clear the history instantly.
* **Default App Handler:** Automatically registers itself as a viewer for office documents in the macOS Finder.

## Licensing

Mac Document Viewer includes a built-in trial mode. 
* The **first launch** of the app acts as a free trial with full functionality.
* Starting from the **second launch**, the app will require a License Key to unlock the interface. 

**How to get a License Key:**
When you hit the License Lock screen, click the **"Request Key via Email"** button. This will automatically open your default email client with a pre-filled request directed to the developer. Once you receive your key, enter it to permanently unlock the app!

## Getting Started

1. Clone the repository.
2. Run `flutter pub get` to fetch dependencies.
3. Run `flutter run -d macos` to test in debug mode.

## Building for Production

To create a standalone macOS `.app` bundle that you can drag into your `/Applications` folder:

```bash
flutter clean
flutter build macos
```

The compiled application will be located at:
`build/macos/Build/Products/Release/mac_document_viewer.app`
