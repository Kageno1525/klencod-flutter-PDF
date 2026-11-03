import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'dart:io';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfViewerScreen({super.key, required this.filePath, required this.fileName});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _controller = PdfViewerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _controller.zoomUp(),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _controller.zoomDown(),
          ),
        ],
      ),
      body: PdfViewer.file(
        widget.filePath,
        controller: _controller,
        params: PdfViewerParams(
          enableTextSelection: true,
          panAxis: PanAxis.free,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.first_page),
              onPressed: () => _controller.goToPage(pageNumber: 1),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _controller.goToPreviousPage(),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _controller.goToNextPage(),
            ),
            IconButton(
              icon: const Icon(Icons.last_page),
              onPressed: () => _controller.goToPage(pageNumber: _controller.pageCount),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}