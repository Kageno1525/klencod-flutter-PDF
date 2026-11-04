import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/common.dart';
import 'pdf_viewer_screen.dart';

class RecentScreen extends StatefulWidget {
  final int refreshTick;
  final VoidCallback onChanged;
  final Map<int, Map<String, dynamic>> selectedFiles;
  final void Function(Map<String, dynamic>) onToggleSelection;
  final void Function(Map<String, dynamic>) onEnterSelection;
  final void Function(List<Map<String, dynamic>>) onFilesLoaded;

  const RecentScreen({
    super.key,
    required this.refreshTick,
    required this.onChanged,
    required this.selectedFiles,
    required this.onToggleSelection,
    required this.onEnterSelection,
    required this.onFilesLoaded,
  });

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  final _db = DatabaseService.instance;
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;

  bool get _inSelectionMode => widget.selectedFiles.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RecentScreen old) {
    super.didUpdateWidget(old);
    if (widget.refreshTick != old.refreshTick) _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final files = await _db.getRecentFiles(limit: 50);
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
    widget.onFilesLoaded(files);
  }

  Future<void> _openFile(Map<String, dynamic> f) async {
    await _db.markOpened(f['id']);
    if (!mounted) return;
    await Navigator.push(
      context,
      pageRoute(PdfViewerScreen(filePath: f['path'], fileName: f['name'])),
    );
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _files.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      EmptyState(
                        icon: Icons.history_rounded,
                        title: 'لا يوجد سجل بعد',
                        subtitle: 'افتح أي ملف PDF وسيظهر هنا',
                        color: Color(0xFF2563EB),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: _files.length,
                    itemBuilder: (ctx, i) {
                      final f = _files[i];
                      final isSel =
                          widget.selectedFiles.containsKey(f['id']);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RepaintBoundary(
                          child: FileTile(
                            file: f,
                            isSelected: isSel,
                            inSelectionMode: _inSelectionMode,
                            showOpenTime: true,
                            onTap: () {
                              if (_inSelectionMode) {
                                widget.onToggleSelection(f);
                              } else {
                                _openFile(f);
                              }
                            },
                            onLongPress: () {
                              if (!_inSelectionMode) {
                                widget.onEnterSelection(f);
                              } else {
                                widget.onToggleSelection(f);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}