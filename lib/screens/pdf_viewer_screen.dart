import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdfrx/pdfrx.dart';
import '../service/database_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final PdfDoc doc;
  const PdfViewerScreen({super.key, required this.doc});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfViewerController _controller = PdfViewerController();
  int _lastSaved = 0;
  late int _currentPage;
  late int _totalPages;
  bool _showToolbar = true;

  @override
  void initState() {
    super.initState();
    _lastSaved = widget.doc.lastPage;
    _currentPage = widget.doc.lastPage > 0 ? widget.doc.lastPage : 1;
    _totalPages = widget.doc.pageCount;
  }

  Future<void> _saveProgress() async {
    try {
      final page = _controller.pageNumber;
      if (page != null && page != _lastSaved) {
        _lastSaved = page;
        await DatabaseService.instance.updateLastPage(widget.doc.id!, page);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _saveProgress();
    super.dispose();
  }

  void _jumpToPage() async {
    final ctrl = TextEditingController(text: '$_currentPage');
    final page = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الانتقال إلى صفحة'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '1 - $_totalPages',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              if (n != null && n >= 1 && n <= _totalPages) {
                Navigator.pop(ctx, n);
              }
            },
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
    if (page != null) {
      _controller.goToPage(pageNumber: page);
    }
  }

  void _next() {
    if (_currentPage < _totalPages) {
      _controller.goToPage(pageNumber: _currentPage + 1);
    }
  }

  void _prev() {
    if (_currentPage > 1) {
      _controller.goToPage(pageNumber: _currentPage - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _saveProgress();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(theme, progress),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showToolbar = !_showToolbar),
                  child: PdfViewer.file(
                    widget.doc.filePath,
                    controller: _controller,
                    initialPageNumber: _lastSaved > 0 ? _lastSaved : 1,
                    params: PdfViewerParams(
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                        _saveProgress();
                      },
                    ),
                  ),
                ),
              ),
              _buildBottomBar(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme, double progress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    GestureDetector(
                      onTap: _jumpToPage,
                      child: Text(
                        'صفحة $_currentPage من $_totalPages',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(widget.doc.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded),
                color: widget.doc.isFavorite ? Colors.amber : null,
                onPressed: () async {
                  await DatabaseService.instance.toggleFavorite(
                      widget.doc.id!, !widget.doc.isFavorite);
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      offset: _showToolbar ? Offset.zero : const Offset(0, 1.5),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showToolbar ? 1 : 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navBtn(Icons.chevron_right_rounded, _prev, _currentPage > 1),
              GestureDetector(
                onTap: _jumpToPage,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              _navBtn(Icons.chevron_left_rounded, _next,
                  _currentPage < _totalPages),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap, bool enabled) {
    final theme = Theme.of(context);
    return Material(
      color: enabled
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon,
              color: enabled
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}