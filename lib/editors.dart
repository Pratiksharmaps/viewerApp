import 'dart:io';
import 'dart:convert';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:flutter/material.dart' hide Border;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';

// ─────────────────────────────────────────
// Excel Editor Screen
// ─────────────────────────────────────────
class ExcelEditorScreen extends StatefulWidget {
  final String filePath;
  const ExcelEditorScreen({super.key, required this.filePath});

  @override
  State<ExcelEditorScreen> createState() => _ExcelEditorScreenState();
}

class _ExcelEditorScreenState extends State<ExcelEditorScreen> {
  SpreadsheetDecoder? _excel;
  String _activeSheet = '';
  bool _loading = true;
  bool _hasChanges = false;
  String? _error;

  int? _editRow;
  int? _editCol;
  final TextEditingController _cellController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _cellController.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    try {
      final bytes = File(widget.filePath).readAsBytesSync();
      final excel = SpreadsheetDecoder.decodeBytes(bytes, update: true);
      setState(() {
        _excel = excel;
        _activeSheet = excel.tables.keys.first;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not read file: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveFile() async {
    try {
      final bytes = _excel!.encode();
      if (bytes.isNotEmpty) {
        File(widget.filePath).writeAsBytesSync(bytes);
        setState(() => _hasChanges = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ File saved successfully'),
              backgroundColor: const Color(0xFF34C759).withAlpha(230),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  void _commitEdit(int row, int col) {
    if (_excel == null) return;
    _excel!.updateCell(_activeSheet, col, row, _cellController.text);
    setState(() {
      _editRow = null;
      _editCol = null;
      _hasChanges = true;
    });
  }

  void _addRow() {
    if (_excel == null) return;
    final sheet = _excel!.tables[_activeSheet]!;
    _excel!.insertRow(_activeSheet, sheet.rows.length);
    setState(() => _hasChanges = true);
  }

  String _cellValue(dynamic cell) {
    if (cell == null) return '';
    return cell.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF34C759)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () {
                            try {
                              Process.run('open', [widget.filePath]);
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.open_in_new_rounded,
                              color: Colors.white70),
                          label: const Text('Open using inbuilt app',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white.withAlpha(13),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () async {
          if (_hasChanges) {
            final save = await _showSaveDialog();
            if (save == true) await _saveFile();
          }
          if (mounted) Navigator.of(context).pop();
        },
      ),
      title: Row(
        children: [
          const Icon(Icons.table_chart_rounded, color: Color(0xFF34C759), size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              p.basename(widget.filePath),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_hasChanges) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Unsaved',
                  style: TextStyle(color: Colors.orange, fontSize: 11)),
            ),
          ],
        ],
      ),
      actions: [
        if (_hasChanges)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _saveFile,
              icon: const Icon(Icons.save_rounded, color: Color(0xFF34C759), size: 18),
              label: const Text('Save', style: TextStyle(color: Color(0xFF34C759))),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded, color: Colors.white70, size: 18),
            label: const Text('Add Row',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_excel == null) return const SizedBox();
    return Column(
      children: [
        if (_excel!.tables.length > 1) _buildSheetTabs(),
        Expanded(child: _buildGrid()),
      ],
    );
  }

  Widget _buildSheetTabs() {
    return Container(
      height: 36,
      color: Colors.white.withAlpha(8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _excel!.tables.keys.map((name) {
          final active = name == _activeSheet;
          return GestureDetector(
            onTap: () => setState(() => _activeSheet = name),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: active
                    ? const Color(0xFF34C759).withAlpha(50)
                    : Colors.transparent,
                border: BoxBorder.lerp(
                  null,
                  null,
                  0,
                ) == null
                    ? null
                    : null,
              ),
              child: Text(
                name,
                style: TextStyle(
                  color: active
                      ? const Color(0xFF34C759)
                      : Colors.white.withAlpha(153),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrid() {
    final sheet = _excel!.tables[_activeSheet];
    if (sheet == null || sheet.rows.isEmpty) {
      return const Center(
        child: Text('No data in this sheet',
            style: TextStyle(color: Colors.white54)),
      );
    }

    final rows = sheet.rows;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(rows.length, (r) {
            final isHeader = r == 0;
            return Row(
              children: List.generate(rows[r].length, (c) {
                final cell = rows[r][c];
                final value = _cellValue(cell);
                final isEditing = _editRow == r && _editCol == c;

                return GestureDetector(
                  onTap: () {
                    if (_editRow != null && _editCol != null) {
                      _commitEdit(_editRow!, _editCol!);
                    }
                    _cellController.text = value;
                    setState(() {
                      _editRow = r;
                      _editCol = c;
                    });
                  },
                  child: Container(
                    width: 140,
                    height: isHeader ? 40 : 36,
                    decoration: BoxDecoration(
                      color: isEditing
                          ? const Color(0xFF34C759).withAlpha(25)
                          : isHeader
                              ? Colors.white.withAlpha(20)
                              : (r % 2 == 0
                                  ? Colors.white.withAlpha(5)
                                  : Colors.transparent),
                      border: BoxBorder.lerp(null, null, 0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundDecoration: BoxDecoration(
                      border: isEditing
                          ? BoxDecoration(
                              border: BoxBorder.lerp(null, null, 0),
                            ).border
                          : null,
                    ),
                    child: isEditing
                        ? Center(
                            child: TextField(
                              controller: _cellController,
                              autofocus: true,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration:
                                  const InputDecoration(border: InputBorder.none),
                              onSubmitted: (_) => _commitEdit(r, c),
                            ),
                          )
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              style: TextStyle(
                                color: isHeader
                                    ? Colors.white
                                    : Colors.white.withAlpha(217),
                                fontSize: 13,
                                fontWeight: isHeader
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ),
                );
              }),
            );
          }),
        ),
      ),
    );
  }

  Future<bool?> _showSaveDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Unsaved Changes',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Do you want to save your changes before leaving?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save',
                style: TextStyle(color: Color(0xFF34C759))),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Word Editor Screen
// ─────────────────────────────────────────
class WordEditorScreen extends StatefulWidget {
  final String filePath;
  const WordEditorScreen({super.key, required this.filePath});

  @override
  State<WordEditorScreen> createState() => _WordEditorScreenState();
}

class _WordEditorScreenState extends State<WordEditorScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _loading = true;
  bool _hasChanges = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    try {
      final bytes = File(widget.filePath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docXml = archive.findFile('word/document.xml');
      if (docXml == null) throw Exception('Not a valid .docx file');

      final xmlStr = utf8.decode(docXml.content as List<int>);
      final plain = xmlStr
          .replaceAll(RegExp(r'<w:br[^/]*/?>'), '\n')
          .replaceAll(RegExp(r'<w:p[ >][^<]*>|<w:p/>'), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();

      _textController.text = plain;
      _textController.addListener(() => setState(() => _hasChanges = true));
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Could not read .docx: $e';
        _loading = false;
      });
    }
  }

  Future<void> _performSave(String outPath) async {
    try {
      final bytes = File(widget.filePath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final newArchive = Archive();
      bool documentReplaced = false;

      final text = _textController.text;
      final lines = text.split('\n');
      final paragraphs = lines.map((line) {
        final safeLine = line.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
        return '<w:p><w:r><w:t xml:space="preserve">$safeLine</w:t></w:r></w:p>';
      }).join('');

      final newXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $paragraphs
  </w:body>
</w:document>''';

      final encodedXml = utf8.encode(newXml);

      for (final file in archive.files) {
        if (file.name == 'word/document.xml') {
          newArchive.addFile(ArchiveFile(file.name, encodedXml.length, encodedXml));
          documentReplaced = true;
        } else {
          newArchive.addFile(file);
        }
      }

      if (!documentReplaced) {
        newArchive.addFile(ArchiveFile('word/document.xml', encodedXml.length, encodedXml));
      }

      final outBytes = ZipEncoder().encode(newArchive)!;
      File(outPath).writeAsBytesSync(outBytes);

      setState(() => _hasChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Saved successfully: ${p.basename(outPath)}'),
            backgroundColor: const Color(0xFF34C759).withAlpha(230),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _saveFile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Overwrite Document?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Saving will overwrite the original file with a plain-text version. All rich formatting (tables, images, bold text) will be permanently lost.\n\nAre you sure?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save Anyway', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _performSave(widget.filePath);
    }
  }

  Future<void> _saveAsCopy() async {
    final dir = p.dirname(widget.filePath);
    final name = p.basenameWithoutExtension(widget.filePath);
    final outPath = '$dir/$name (copy).docx';
    await _performSave(outPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withAlpha(13),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.description_rounded,
                color: Color(0xFF007AFF), size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                p.basename(widget.filePath),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_hasChanges) ...[
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: _saveFile,
                icon: const Icon(Icons.save_rounded,
                    color: Color(0xFF007AFF), size: 16),
                label: const Text('Save',
                    style: TextStyle(color: Color(0xFF007AFF), fontSize: 13)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _saveAsCopy,
                icon: const Icon(Icons.copy_rounded,
                    color: Color(0xFF34C759), size: 16),
                label: const Text('Save As Copy',
                    style: TextStyle(color: Color(0xFF34C759), fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF007AFF)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: Colors.orange.withAlpha(30),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Plain text only — rich formatting (bold, tables, images) is not preserved. Use "Open in Native App" for full editing.',
                              style: TextStyle(
                                  color: Colors.orange, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.6,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Document content...',
                            hintStyle: TextStyle(color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────
// PDF Viewer Screen
// ─────────────────────────────────────────
class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  const PdfViewerScreen({super.key, required this.filePath});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfControllerPinch _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  void _loadPdf() {
    try {
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.filePath),
      );
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Could not open PDF: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : _error != null
              ? _buildError()
              : _buildPdfView(),
      bottomNavigationBar: (!_loading && _error == null) ? _buildPageBar() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white.withAlpha(13),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE53935), size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              p.basename(widget.filePath),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_totalPages > 0) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Previous Page',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: _currentPage > 1
              ? () => _pdfController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  )
              : null,
        ),
        IconButton(
          tooltip: 'Next Page',
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: _totalPages > 0 && _currentPage < _totalPages
              ? () => _pdfController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  )
              : null,
        ),
        IconButton(
          tooltip: 'Open in Preview',
          icon: const Icon(Icons.open_in_new_rounded),
          onPressed: () async {
            try {
              await Process.run('open', [widget.filePath]);
            } catch (_) {}
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildPdfView() {
    return PdfViewPinch(
      controller: _pdfController,
      onDocumentLoaded: (doc) {
        setState(() => _totalPages = doc.pagesCount);
      },
      onPageChanged: (page) {
        setState(() => _currentPage = page);
      },
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE53935)),
        ),
        pageLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE53935)),
        ),
        errorBuilder: (_, err) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildPageBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: Colors.white.withAlpha(20)),
        Container(
          height: 55,
          color: Colors.white.withAlpha(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, color: Colors.white54),
                onPressed: _currentPage > 1
                    ? () => _pdfController.animateToPage(
                          pageNumber: 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
                onPressed: _currentPage > 1
                    ? () => _pdfController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        )
                    : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Page $_currentPage of $_totalPages',
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                onPressed: _totalPages > 0 && _currentPage < _totalPages
                    ? () => _pdfController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        )
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, color: Colors.white54),
                onPressed: _totalPages > 0 && _currentPage < _totalPages
                    ? () => _pdfController.animateToPage(
                          pageNumber: _totalPages,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await Process.run('open', [widget.filePath]);
                } catch (_) {}
              },
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70),
              label: const Text('Open in Preview', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
            ),
          ],
        ),
      ),
    );
  }
}
