import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../services/database_service.dart';
import '../services/pdf_tools_service.dart';

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

  void _extractFromHere() async {
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
            const SizedBox(height: 12),
            Text('الصفحة الحالية: $_currentPage من $_totalPages',
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
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
      final tools = PdfToolsService.instance;
      final db = DatabaseService.instance;
      final file = await tools.extractRange(
          widget.filePath, result['start']!, result['end']!,
          baseName:
              'extract_${DateTime.now().millisecondsSinceEpoch}');
      final stat = await file.stat();
      await db.insertFile(
          name: file.path.split('/').last,
          path: file.path,
          size: stat.size);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'تم استخراج الصفحات ${result['start']}-${result['end']}'),
          action: SnackBarAction(
            label: 'مشاركة',
            onPressed: () =>
                tools.shareFile(file.path, 'extracted.pdf'),
          ),
        ),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'extract') _extractFromHere();
              if (v == 'orient')
                setState(() => _horizontal = !_horizontal);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'extract',
                child: Row(children: [
                  Icon(Icons.content_cut_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('استخراج صفحات'),
                ]),
              ),
              PopupMenuItem(
                value: 'orient',
                child: Row(children: [
                  Icon(Icons.swap_horiz_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('تبديل العرض'),
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