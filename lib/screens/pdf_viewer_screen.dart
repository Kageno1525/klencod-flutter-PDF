import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

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
  late final PdfControllerPinch _controller;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
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
      body: PdfViewPinch(
        controller: _controller,
        onDocumentLoaded: (doc) {
          setState(() => _totalPages = doc.pagesCount);
        },
        onPageChanged: (page) {
          setState(() => _currentPage = page);
        },
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          pageLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, error) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'خطأ في تحميل الملف\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                onPressed: () => _controller.animateToPage(
                  pageNumber: 1,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.ease,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _controller.previousPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.ease,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _controller.nextPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.ease,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: _totalPages > 0
                    ? () => _controller.animateToPage(
                          pageNumber: _totalPages,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.ease,
                        )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}