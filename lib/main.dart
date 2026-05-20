import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const ViewerApp());
}

class ViewerApp extends StatelessWidget {
  const ViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'Doc & Excel Viewer',
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const fileEventsChannel = MethodChannel('com.viewerapp/file_events');
  static const quickLookChannel = MethodChannel('com.viewerapp/quicklook');

  String? _openedFilePath;

  @override
  void initState() {
    super.initState();
    fileEventsChannel.setMethodCallHandler(_handleFileEvent);
    // Signal to the native side that we are ready to receive queued file events
    fileEventsChannel.invokeMethod('ready');
  }

  Future<void> _handleFileEvent(MethodCall call) async {
    if (call.method == 'onFileOpened') {
      final path = call.arguments['path'] as String?;
      if (path != null) {
        setState(() {
          _openedFilePath = path;
        });
        _showQuickLook(path);
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['doc', 'docx', 'xls', 'xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        setState(() {
          _openedFilePath = path;
        });
        _showQuickLook(path);
      }
    } catch (e) {
      debugPrint("Failed to pick file: $e");
    }
  }

  Future<void> _showQuickLook(String path) async {
    try {
      await quickLookChannel.invokeMethod('showQuickLook', {'path': path});
    } on PlatformException catch (e) {
      debugPrint("Failed to show QuickLook: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MacosWindow(
      sidebar: Sidebar(
        minWidth: 200,
        builder: (context, scrollController) => SidebarItems(
          currentIndex: 0,
          onChanged: (index) {},
          items: const [
            SidebarItem(
              leading: MacosIcon(CupertinoIcons.doc_text),
              label: Text('Viewer'),
            ),
          ],
        ),
      ),
      child: MacosScaffold(
        toolBar: ToolBar(
          title: const Text('Document Viewer'),
          titleWidth: 150.0,
          actions: [
            ToolBarIconButton(
              label: 'Preview',
              icon: const MacosIcon(CupertinoIcons.eye),
              showLabel: false,
              tooltipMessage: 'Show QuickLook Preview',
              onPressed: () {
                if (_openedFilePath != null) {
                  _showQuickLook(_openedFilePath!);
                }
              },
            ),
          ],
        ),
        children: [
          ContentArea(
            builder: (context, scrollController) {
              return Stack(
                children: [
                  if (_openedFilePath == null)
                    _buildEmptyState(context)
                  else
                    _buildFileState(context, _openedFilePath!),
                  
                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: PushButton(
                      controlSize: ControlSize.large,
                      onPressed: _pickFile,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('Pick File'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MacosIcon(
            CupertinoIcons.doc_on_doc,
            size: 64,
            color: MacosColors.systemGrayColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No Document Opened',
            style: MacosTheme.of(context).typography.title1,
          ),
          const SizedBox(height: 8),
          Text(
            'Right-click a .docx or .xlsx file and open with this app,\nor click "Pick File" to choose one.',
            style: MacosTheme.of(context).typography.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFileState(BuildContext context, String path) {
    final fileName = p.basename(path);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MacosIcon(
            CupertinoIcons.doc_text_fill,
            size: 80,
            color: MacosColors.systemBlueColor,
          ),
          const SizedBox(height: 24),
          Text(
            fileName,
            style: MacosTheme.of(context).typography.title1,
          ),
          const SizedBox(height: 12),
          Text(
            path,
            style: MacosTheme.of(context).typography.body.copyWith(
                  color: MacosColors.systemGrayColor,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          PushButton(
            controlSize: ControlSize.large,
            onPressed: () => _showQuickLook(path),
            child: const Text('Open QuickLook Preview'),
          ),
        ],
      ),
    );
  }
}


