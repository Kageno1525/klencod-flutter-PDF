import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_service.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/common.dart';

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

  // ══════════ Watermark ══════════
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
      final newFile =
          await PdfToolsService.instance.addWatermark(widget.filePath, text);
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

  // ══════════ Search inside PDF ══════════
  Future<void> _searchText() async {
    final ctrl = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('بحث داخل PDF'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'كلمة للبحث',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'يشتغل مع PDFs فيها نص حقيقي\n(مش الممسوحة ضوئيًا)',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('بحث'),
          ),
        ],
      ),
    );
    if (query == null || query.isEmpty) return;

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري البحث...')),
      );
      final pages =
          await PdfToolsService.instance.searchInPdf(widget.filePath, query);
      if (!mounted) return;
      if (pages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'لم يتم العثور على "$query"\n(قد يكون الملف صورة ممسوحة ضوئيًا)'),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      _showSearchResults(query, pages);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في البحث: $e')),
      );
    }
  }

  void _showSearchResults(String query, List<int> pages) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SearchResultsSheet(
        query: query,
        pages: pages,
        onJumpToPage: (pageNumber1Based) {
          _pdfController?.setPage(pageNumber1Based - 1);
        },
      ),
    );
  }

  // ══════════ Delete page ══════════
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

  // ══════════ Extract page as image ══════════
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

  // ══════════ Extract range ══════════
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
            icon: const Icon(Icons.search_rounded),
            tooltip: 'بحث داخل PDF',
            onPressed: _searchText,
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

// ═══════════════════════════════════════════════════════════════════
// SEARCH RESULTS
// ═══════════════════════════════════════════════════════════════════

class _SearchResultsSheet extends StatelessWidget {
  final String query;
  final List<int> pages; // 1-based
  final void Function(int pageNumber1Based) onJumpToPage;

  const _SearchResultsSheet({
    required this.query,
    required this.pages,
    required this.onJumpToPage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'نتائج: "$query"',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${pages.length} صفحة',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pages.length,
                itemBuilder: (ctx, i) {
                  final pageNum = pages[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          const Color(0xFF2563EB).withOpacity(0.15),
                      child: Text(
                        '$pageNum',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB)),
                      ),
                    ),
                    title: Text(
                      'الصفحة $pageNum',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded,
                          size: 18),
                      tooltip: 'اذهب',
                      onPressed: () {
                        Navigator.pop(context);
                        onJumpToPage(pageNum);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}