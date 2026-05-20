# Mac Document Viewer

A lightweight, native macOS document viewer built with Flutter. It seamlessly integrates with Apple's QuickLook framework to instantly preview Microsoft Word (`.doc`, `.docx`) and Excel (`.xls`, `.xlsx`) files without needing heavy office suites installed.

## Features

* **Native macOS UI:** Built using `macos_ui` to perfectly match the Apple design language, including native sidebars, toolbars, and typography.
* **QuickLook Integration:** Bypasses heavy document parsing by handing the file directly to macOS's highly optimized `QLPreviewPanel` daemon for pixel-perfect rendering of complex spreadsheets and text documents.
* **Default App Handler:** Automatically registers itself as a viewer for `.doc`, `.docx`, `.xls`, and `.xlsx` files in the macOS Finder.
* **Sandbox Bypass:** Custom entitlements allow the out-of-process QuickLook server to securely read and render files opened from the Finder.
* **Manual File Picker:** Includes a built-in file picker for quick manual testing without leaving the app.

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
