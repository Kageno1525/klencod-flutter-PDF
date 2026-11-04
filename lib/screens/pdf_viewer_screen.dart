import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_service.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/common.dart';
import 'pdf_editor_screen.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int _currentPage = 1;
  int _totalPages = 0;
  bool _ready = false;
  bool _horizontal = false;
  PDFViewController? _pdfController;

  Future<void> _openEditor() async {
    final changed = await Navigator.push<bool>(
      context,
      pageRoute(PdfEditorScreen(
        filePath: widget.filePath,
        fileName: widget.fileName,
      )),
    );
    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _addWatermark() async {
    final ctrl = TextEditingController(text: 'مسودة');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.branding_watermark_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('علامة مائية'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'النص',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري التطبيق...')),
    );
    try {
      final newFile = await PdfToolsService.instance
          .addWatermark(widget.filePath, text);
      if (!mounted) return;
      final saveResult = await showSavePdfDialog(
        context,
        defaultName: widget.fileName.replaceAll('.pdf', '') + '_wm',
      );
      if (saveResult == null) {
        await newFile.delete();
        return;
      }
      final stat = await newFile.stat();
      await DatabaseService.instance.insertFile(
        name: saveResult.name,
        path: newFile.path,
        size: stat.size,
        groupId: saveResult.groupId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ كملف جديد')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _deleteCurrentPage() async {
    if (_totalPages == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('حذف الصفحة $_currentPage؟'),
        content: const Text('هيتم إنشاء ملف PDF جديد بدون هذه الصفحة.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري الحذف...')),
      );
      final newFile = await PdfToolsService.instance
          .deletePage(widget.filePath, _currentPage - 1);
      if (!mounted) return;
      final saveResult = await showSavePdfDialog(
        context,
        defaultName:
            widget.fileName.replaceAll('.pdf', '') + '_del$_currentPage',
      );
      if (saveResult == null) {
        await newFile.delete();
        return;
      }
      final stat = await newFile.stat();
      await DatabaseService.instance.insertFile(
        name: saveResult.name,
        path: newFile.path,
        size: stat.size,
        groupId: saveResult.groupId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ كملف جديد')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _extractPageAsImage() async {
    if (_totalPages == 0) return;
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري الاستخراج...')),
      );
      final file = await PdfToolsService.instance
          .savePageAsImage(widget.filePath, _currentPage - 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم الحفظ: ${file.path}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'مشاركة',
            onPressed: () =>
                Share.shareXFiles([XFile(file.path, name: 'page.png')]),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _extractRange() async {
    if (_totalPages == 0) return;
    final startCtrl = TextEditingController(text: '$_currentPage');
    final endCtrl = TextEditingController(text: '$_totalPages');
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('استخراج صفحات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'من (1-$_totalPages)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: endCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'إلى (1-$_totalPages)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final s = int.tryParse(startCtrl.text.trim());
              final e = int.tryParse(endCtrl.text.trim());
              if (s == null ||
                  e == null ||
                  s < 1 ||
                  e < s ||
                  e > _totalPages) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('أرقام غير صحيحة')),
                );
                return;
              }
              Navigator.pop(ctx, {'start': s, 'end': e});
            },
            child: const Text('استخراج'),
          ),
        ],
      ),
    );
    if (result == null) return;

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري الاستخراج...')),
      );
      final newFile = await PdfToolsService.instance.extractRange(
        widget.filePath,
        result['start']!,
        result['end']!,
        baseName: 'extract_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      final saveResult = await showSavePdfDialog(
        context,
        defaultName: widget.fileName.replaceAll('.pdf', '') +
            '_${result['start']}_${result['end']}',
      );
      if (saveResult == null) {
        await newFile.delete();
        return;
      }
      final stat = await newFile.stat();
      await DatabaseService.instance.insertFile(
        name: saveResult.name,
        path: newFile.path,
        size: stat.size,
        groupId: saveResult.groupId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ كملف جديد')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded,
                color: Color(0xFFDC2626)),
            tooltip: 'محرر النص',
            onPressed: _openEditor,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              switch (v) {
                case 'watermark':
                  _addWatermark();
                  break;
                case 'delete_page':
                  _deleteCurrentPage();
                  break;
                case 'extract_image':
                  _extractPageAsImage();
                  break;
                case 'extract_range':
                  _extractRange();
                  break;
                case 'orient':
                  setState(() => _horizontal = !_horizontal);
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'watermark',
                child: Row(children: [
                  Icon(Icons.branding_watermark_rounded,
                      size: 18, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('علامة مائية'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete_page',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('حذف الصفحة الحالية'),
                ]),
              ),
              PopupMenuItem(
                value: 'extract_image',
                child: Row(children: [
                  Icon(Icons.image_rounded,
                      size: 18, color: Colors.purple),
                  SizedBox(width: 10),
                  Text('استخراج الصفحة كصورة'),
                ]),
              ),
              PopupMenuItem(
                value: 'extract_range',
                child: Row(children: [
                  Icon(Icons.content_cut_rounded,
                      size: 18, color: Colors.teal),
                  SizedBox(width: 10),
                  Text('استخراج نطاق صفحات'),
                ]),
              ),
              PopupMenuItem(
                value: 'orient',
                child: Row(children: [
                  Icon(Icons.swap_horiz_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('تبديل اتجاه العرض'),
                ]),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                _totalPages > 0 ? '$_currentPage / $_totalPages' : '...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PDFView(
            key: ValueKey(_horizontal),
            filePath: widget.filePath,
            enableSwipe: true,
            swipeHorizontal: _horizontal,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            fitPolicy: FitPolicy.BOTH,
            onRender: (pages) {
              setState(() {
                _totalPages = pages ?? 0;
                _ready = true;
              });
            },
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطأ في تحميل الملف: $error')),
                );
              }
            },
            onPageChanged: (page, total) {
              setState(() {
                _currentPage = (page ?? 0) + 1;
                _totalPages = total ?? _totalPages;
              });
            },
            onViewCreated: (c) => _pdfController = c,
          ),
          if (!_ready) const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: Container(
        color: scheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: _pdfController != null && _totalPages > 0
                    ? () => _pdfController!.setPage(0)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _pdfController != null && _currentPage > 1
                    ? () => _pdfController!.setPage(_currentPage - 2)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _pdfController != null &&
                        _currentPage < _totalPages
                    ? () => _pdfController!.setPage(_currentPage)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: _pdfController != null && _totalPages > 0
                    ? () => _pdfController!.setPage(_totalPages - 1)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}