import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ViewerApp());
}

class ViewerApp extends StatelessWidget {
  const ViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mac Document Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class FileHistoryService {
  static const _key = 'file_history';

  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> addFile(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(path); // avoid duplicates
    list.insert(0, path); // most recent first
    if (list.length > 20) list.removeLast();
    await prefs.setStringList(_key, list);
  }

  static Future<void> removeFile(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(path);
    await prefs.setStringList(_key, list);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  static const fileEventsChannel = MethodChannel('com.viewerapp/file_events');
  static const quickLookChannel = MethodChannel('com.viewerapp/quicklook');
  static const editorChannel = MethodChannel('com.viewerapp/editor');

  String? _openedFilePath;
  List<String> _history = [];
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    fileEventsChannel.setMethodCallHandler(_handleFileEvent);
    fileEventsChannel.invokeMethod('ready');
    _loadHistory();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await FileHistoryService.getHistory();
    setState(() => _history = history);
  }

  Future<void> _handleFileEvent(MethodCall call) async {
    if (call.method == 'onFileOpened') {
      final path = call.arguments['path'] as String?;
      if (path != null) {
        await _openFile(path);
      }
    }
  }

  Future<void> _openFile(String path) async {
    if (!File(path).existsSync()) {
      _showError('File not found: ${p.basename(path)}');
      return;
    }
    setState(() => _openedFilePath = path);
    await FileHistoryService.addFile(path);
    await _loadHistory();
    _animController.forward(from: 0);
    _showQuickLook(path);
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['doc', 'docx', 'xls', 'xlsx'],
      );
      if (result != null && result.files.single.path != null) {
        await _openFile(result.files.single.path!);
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  Future<void> _showQuickLook(String path) async {
    try {
      await quickLookChannel.invokeMethod('showQuickLook', {'path': path});
    } on PlatformException catch (e) {
      _showError('Preview failed: ${e.message}');
    }
  }

  Future<void> _editFile(String path) async {
    try {
      // Open in the default editor (TextEdit for .doc, Excel/Numbers for .xlsx)
      await Process.run('open', [path]);
    } catch (e) {
      _showError('Could not open for editing: $e');
    }
  }

  Future<void> _removeFromHistory(String path) async {
    await FileHistoryService.removeFile(path);
    await _loadHistory();
    if (_openedFilePath == path) {
      setState(() => _openedFilePath = null);
    }
  }

  Future<void> _clearHistory() async {
    await FileHistoryService.clearAll();
    setState(() {
      _history = [];
      _openedFilePath = null;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  IconData _iconForFile(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.xlsx' || ext == '.xls') return Icons.table_chart_rounded;
    return Icons.description_rounded;
  }

  Color _colorForFile(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.xlsx' || ext == '.xls') return const Color(0xFF34C759);
    return const Color(0xFF007AFF);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1117),
              Color(0xFF161B22),
              Color(0xFF0D1B2A),
            ],
          ),
        ),
        child: Row(
          children: [
            _buildSidebar(),
            _buildMainContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: 260,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border(
              right: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF34C759)],
                        ),
                      ),
                      child: const Icon(Icons.folder_copy_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Doc Viewer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildGlassButton(
                  onPressed: _pickFile,
                  icon: Icons.add_rounded,
                  label: 'Open File',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Files',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (_history.isNotEmpty)
                      GestureDetector(
                        onTap: _clearHistory,
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            color: Colors.red.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _history.isEmpty
                    ? Center(
                        child: Text(
                          'No files opened yet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.25),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _history.length,
                        itemBuilder: (ctx, i) =>
                            _buildHistoryItem(_history[i]),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String path) {
    final isSelected = _openedFilePath == path;
    final name = p.basename(path);
    final dir = p.dirname(path);
    final color = _colorForFile(path);
    final icon = _iconForFile(path);

    return GestureDetector(
      onTap: () => _openFile(path),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          border: isSelected
              ? Border.all(color: Colors.white.withOpacity(0.12), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: color.withOpacity(0.15),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    dir,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _removeFromHistory(path),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
                child: Icon(Icons.close_rounded,
                    color: Colors.white.withOpacity(0.5), size: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Expanded(
      child: _openedFilePath == null
          ? _buildEmptyState()
          : _buildFileState(_openedFilePath!),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildGlassCard(
            width: 320,
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF007AFF).withOpacity(0.3),
                        const Color(0xFF34C759).withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.folder_open_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No Document Selected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick a file or double-click an Excel / Word\ndocument in Finder to open it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                _buildGlassButton(
                  onPressed: _pickFile,
                  icon: Icons.folder_open_rounded,
                  label: 'Choose a File',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileState(String path) {
    final fileName = p.basename(path);
    final ext = p.extension(path).toLowerCase();
    final isSpreadsheet = ext == '.xlsx' || ext == '.xls';
    final fileColor = _colorForFile(path);
    final fileIcon = _iconForFile(path);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildGlassCard(
              width: 480,
              child: Column(
                children: [
                  // File icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          fileColor,
                          fileColor.withOpacity(0.6),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: fileColor.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(fileIcon, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    fileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: fileColor.withOpacity(0.15),
                    ),
                    child: Text(
                      isSpreadsheet
                          ? 'Microsoft Excel Spreadsheet'
                          : 'Microsoft Word Document',
                      style: TextStyle(
                        color: fileColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.dirname(path),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 28),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildGlassButton(
                          onPressed: () => _showQuickLook(path),
                          icon: Icons.preview_rounded,
                          label: 'Preview',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGlassButton(
                          onPressed: () => _editFile(path),
                          icon: Icons.edit_rounded,
                          label: 'Edit',
                          gradient: LinearGradient(
                            colors: [fileColor, fileColor.withOpacity(0.7)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, double? width}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withOpacity(0.06),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Gradient gradient,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient)
                  .colors
                  .first
                  .withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
