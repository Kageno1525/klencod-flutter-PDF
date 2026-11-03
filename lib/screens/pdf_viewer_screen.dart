import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  const PdfViewerScreen({super.key, required this.filePath, required this.fileName});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int _currentPage = 1;
  int _totalPages = 0;
  bool _ready = false;
  bool _horizontal = false;
  PDFViewController? _pdfController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(_horizontal ? Icons.swap_vert : Icons.swap_horiz),
            tooltip: _horizontal ? 'عرض عمودي' : 'عرض أفقي',
            onPressed: () {
              setState(() => _horizontal = !_horizontal);
              setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
            onViewCreated: (controller) => _pdfController = controller,
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
                onPressed: _pdfController != null && _currentPage < _totalPages
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