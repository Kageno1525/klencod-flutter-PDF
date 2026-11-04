import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/pdf_editor_service.dart';
import '../widgets/common.dart';

enum EditorTool { cover, text }

class PdfEditorScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  const PdfEditorScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  List<Uint8List> _pageImages = [];
  final List<PdfEdit> _edits = [];
  int _currentPage = 0;
  EditorTool _tool = EditorTool.cover;
  bool _loading = true;
  bool _saving = false;

  Offset? _dragStart;
  Offset? _dragCurrent;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    try {
      final pages = await PdfEditorService.instance
          .renderPagesForPreview(File(widget.filePath));
      if (mounted) {
        setState(() {
          _pageImages = pages;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  void _undo() {
    if (_edits.isEmpty) return;
    setState(() => _edits.removeLast());
  }

  void _clearPage() {
    setState(() {
      _edits.removeWhere((e) => e.pageIndex == _currentPage);
    });
  }

  Future<void> _save() async {
    if (_edits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم إجراء أي تعديل')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final file = await PdfEditorService.instance.applyEdits(
        widget.filePath,
        _edits,
        baseName: widget.fileName.replaceAll('.pdf', '') + '_edited',
      );
      if (!mounted) return;

      final saveResult = await showSavePdfDialog(
        context,
        defaultName: '${widget.fileName.replaceAll('.pdf', '')}_edited',
      );
      if (saveResult == null) {
        await file.delete();
        if (mounted) setState(() => _saving = false);
        return;
      }

      final stat = await file.stat();
      await DatabaseService.instance.insertFile(
        name: saveResult.name,
        path: file.path,
        size: stat.size,
        groupId: saveResult.groupId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ بنجاح')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  Future<void> _showTextDialog(Offset normalizedPosition) async {
    final textCtrl = TextEditingController();
    double fontSize = 18;
    Color chosenColor = Colors.black;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.text_fields_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('إضافة نص'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                autofocus: true,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'النص',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('الحجم:', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: fontSize,
                      min: 8,
                      max: 48,
                      divisions: 20,
                      label: fontSize.round().toString(),
                      onChanged: (v) =>
                          setDialogState(() => fontSize = v),
                    ),
                  ),
                  Text(fontSize.round().toString(),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final c in [
                    Colors.black,
                    Colors.red,
                    Colors.blue,
                    Colors.green,
                  ])
                    GestureDetector(
                      onTap: () => setDialogState(() => chosenColor = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: chosenColor == c
                                ? const Color(0xFFDC2626)
                                : Colors.transparent,
                            width: 3,
                          ),
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
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final t = textCtrl.text.trim();
                if (t.isEmpty) return;
                Navigator.pop(ctx, {
                  'text': t,
                  'fontSize': fontSize,
                  'color': chosenColor,
                });
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    setState(() {
      _edits.add(PdfEdit(
        type: PdfEditType.text,
        pageIndex: _currentPage,
        normalizedBounds: Rect.fromLTWH(
          normalizedPosition.dx,
          normalizedPosition.dy,
          0.001,
          0.001,
        ),
        text: result['text'] as String,
        color: result['color'] as Color,
        fontSize: result['fontSize'] as double,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.fileName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title:
            Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_edits.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'تراجع',
              onPressed: _undo,
            ),
          IconButton(
            icon: const Icon(Icons.layers_clear_rounded, color: Colors.orange),
            tooltip: 'مسح تعديلات الصفحة',
            onPressed: _clearPage,
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded, color: Colors.green),
            tooltip: 'حفظ',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_pageImages.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'صفحة ${_currentPage + 1} / ${_pageImages.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < _pageImages.length - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            ),
          Expanded(child: _buildEditorArea(primary)),
          _buildToolbar(primary),
        ],
      ),
    );
  }

  Widget _buildEditorArea(Color primary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pngBytes = _pageImages[_currentPage];
        final imageSize = PdfEditorService.instance.getImageSize(pngBytes);
        final imageAspect = imageSize.width / imageSize.height;
        final widgetAspect = constraints.maxWidth / constraints.maxHeight;

        Rect imageRect;
        if (imageAspect > widgetAspect) {
          final h = constraints.maxWidth / imageAspect;
          final y = (constraints.maxHeight - h) / 2;
          imageRect = Rect.fromLTWH(0, y, constraints.maxWidth, h);
        } else {
          final w = constraints.maxHeight * imageAspect;
          final x = (constraints.maxWidth - w) / 2;
          imageRect = Rect.fromLTWH(x, 0, w, constraints.maxHeight);
        }

        Offset toScreen(Offset n) => Offset(
              imageRect.left + n.dx * imageRect.width,
              imageRect.top + n.dy * imageRect.height,
            );

        Offset fromScreen(Offset s) => Offset(
              ((s.dx - imageRect.left) / imageRect.width).clamp(0.0, 1.0),
              ((s.dy - imageRect.top) / imageRect.height).clamp(0.0, 1.0),
            );

        final pageEdits =
            _edits.where((e) => e.pageIndex == _currentPage).toList();

        Widget content = Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: Image.memory(
                pngBytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
            CustomPaint(
              painter: _EditsPainter(
                edits: pageEdits,
                imageRect: imageRect,
                imageSize: imageSize,
                dragStart: _dragStart != null
                    ? toScreen(fromScreen(_dragStart!))
                    : null,
                dragCurrent: _dragCurrent != null
                    ? toScreen(fromScreen(_dragCurrent!))
                    : null,
              ),
            ),
          ],
        );

        if (_tool == EditorTool.cover) {
          return GestureDetector(
            onPanStart: (d) => setState(() => _dragStart = d.localPosition),
            onPanUpdate: (d) =>
                setState(() => _dragCurrent = d.localPosition),
            onPanEnd: (d) {
              if (_dragStart != null && _dragCurrent != null) {
                final n1 = fromScreen(_dragStart!);
                final n2 = fromScreen(_dragCurrent!);
                final rect = Rect.fromPoints(n1, n2);
                if (rect.width > 0.01 && rect.height > 0.01) {
                  setState(() {
                    _edits.add(PdfEdit(
                      type: PdfEditType.cover,
                      pageIndex: _currentPage,
                      normalizedBounds: rect,
                      color: Colors.white,
                    ));
                  });
                }
              }
              setState(() {
                _dragStart = null;
                _dragCurrent = null;
              });
            },
            child: content,
          );
        } else {
          return GestureDetector(
            onTapUp: (d) async {
              final norm = fromScreen(d.localPosition);
              await _showTextDialog(norm);
            },
            child: content,
          );
        }
      },
    );
  }

  Widget _buildToolbar(Color primary) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _toolButton(
                icon: Icons.crop_square_rounded,
                label: 'Cover',
                subtitle: 'غطِّ النص',
                active: _tool == EditorTool.cover,
                color: primary,
                onTap: () => setState(() => _tool = EditorTool.cover),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _toolButton(
                icon: Icons.text_fields_rounded,
                label: 'Text',
                subtitle: 'أضف نص',
                active: _tool == EditorTool.text,
                color: primary,
                onTap: () => setState(() => _tool = EditorTool.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? color.withOpacity(0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? color : Colors.grey, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active ? color : null,
                ),
              ),
              Text(subtitle,
                  style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditsPainter extends CustomPainter {
  final List<PdfEdit> edits;
  final Rect imageRect;
  final Size imageSize;
  final Offset? dragStart;
  final Offset? dragCurrent;

  _EditsPainter({
    required this.edits,
    required this.imageRect,
    required this.imageSize,
    required this.dragStart,
    required this.dragCurrent,
  });

  Offset _toScreen(Offset n) => Offset(
        imageRect.left + n.dx * imageRect.width,
        imageRect.top + n.dy * imageRect.height,
      );

  @override
  void paint(Canvas canvas, Size size) {
    for (final edit in edits) {
      if (edit.type == PdfEditType.cover) {
        final r = Rect.fromPoints(
          _toScreen(edit.normalizedBounds.topLeft),
          _toScreen(edit.normalizedBounds.bottomRight),
        );
        canvas.drawRect(r, Paint()..color = edit.color ?? Colors.white);
      } else {
        final p = _toScreen(edit.normalizedBounds.topLeft);
        final tp = TextPainter(
          text: TextSpan(
            text: edit.text ?? '',
            style: TextStyle(
              fontSize: edit.fontSize,
              color: edit.color ?? Colors.black,
            ),
          ),
          textDirection: TextDirection.rtl,
        );
        tp.layout();
        tp.paint(canvas, p);
      }
    }

    if (dragStart != null && dragCurrent != null) {
      final r = Rect.fromPoints(dragStart!, dragCurrent!);
      canvas.drawRect(
        r,
        Paint()
          ..color = Colors.red.withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        r,
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EditsPainter oldDelegate) => true;
}