import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/common.dart';
import 'pdf_viewer_screen.dart';

class GroupScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  const GroupScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final PdfToolsService _tools = PdfToolsService.instance;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;

  // Selection
  final Map<int, Map<String, dynamic>> _selected = {};
  bool get _inSelectionMode => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final groups = await _db.getGroups(parentId: widget.groupId);
    final files = await _db.getFiles(groupId: widget.groupId);
    setState(() {
      _groups = groups;
      _files = files;
      _isLoading = false;
    });
  }

  void _toggleSelection(Map<String, dynamic> f) {
    setState(() {
      final id = f['id'] as int;
      if (_selected.containsKey(id)) {
        _selected.remove(id);
      } else {
        _selected[id] = f;
      }
    });
  }

  void _enterSelection(Map<String, dynamic> f) {
    setState(() => _selected[f['id'] as int] = f);
  }

  void _clearSelection() => setState(() => _selected.clear());

  Future<void> _batchDelete() async {
    final count = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('حذف $count ملف؟'),
        content: const Text('هيتم حذفهم من التطبيق والجهاز نهائياً.'),
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
    if (ok == true) {
      await batchDelete(_selected.values.toList());
      _clearSelection();
      _load();
    }
  }

  Future<void> _batchFavorite() async {
    await batchFavorite(_selected.values.toList(), true);
    _clearSelection();
    _load();
  }

  Future<void> _batchMove() async {
    final target = await pickGroup(context, title: 'نقل إلى...');
    if (target == null) return;
    final gid = target == -1 ? null : target;
    await batchMove(_selected.values.toList(), gid);
    _clearSelection();
    _load();
  }

  Future<void> _batchTag() async {
    final color = await pickTagColor(context);
    if (color == null) return;
    await batchTag(_selected.values.toList(), color);
    _clearSelection();
    _load();
  }

  Future<void> _createSub() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('مجموعة فرعية'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _db.insertGroup(name, parentId: widget.groupId);
      _load();
    }
  }

  Future<void> _importPdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    final appDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${appDir.path}/pdfs');
    if (!await pdfDir.exists()) await pdfDir.create(recursive: true);
    for (final f in result.files) {
      if (f.path == null) continue;
      final dest =
          '${pdfDir.path}/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
      await File(f.path!).copy(dest);
      final stat = await File(dest).stat();
      await _db.insertFile(
        name: f.name,
        path: dest,
        size: stat.size,
        groupId: widget.groupId,
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _inSelectionMode ? _selectionAppBar() : _normalAppBar(),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_groups.isNotEmpty && !_inSelectionMode) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('📁 مجموعات فرعية',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      ..._groups.map((g) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GroupTile(
                              group: g,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  pageRoute(GroupScreen(
                                    groupId: g['id'],
                                    groupName: g['name'],
                                  )),
                                );
                                _load();
                              },
                            ),
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (_files.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('📄 الملفات',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      ..._files.map((f) {
                        final isSel = _selected.containsKey(f['id']);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FileTile(
                            file: f,
                            isSelected: isSel,
                            inSelectionMode: _inSelectionMode,
                            onTap: () {
                              if (_inSelectionMode) {
                                _toggleSelection(f);
                              } else {
                                _openFile(f);
                              }
                            },
                            onLongPress: () {
                              if (!_inSelectionMode) {
                                _enterSelection(f);
                              } else {
                                _toggleSelection(f);
                              }
                            },
                          ),
                        );
                      }),
                    ],
                    if (_groups.isEmpty && _files.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Text('هذه المجموعة فارغة',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                  ],
                ),
        ),
      ),
      floatingActionButton: _inSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _createSub,
              child: const Icon(Icons.create_new_folder),
            ),
    );
  }

  PreferredSizeWidget _normalAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(widget.groupName),
      actions: [
        IconButton(icon: const Icon(Icons.upload_file), onPressed: _importPdfs),
      ],
    );
  }

  PreferredSizeWidget _selectionAppBar() {
    final primary = Theme.of(context).colorScheme.primary;
    return AppBar(
      backgroundColor: primary.withOpacity(0.08),
      leading: IconButton(
          icon: const Icon(Icons.close_rounded), onPressed: _clearSelection),
      title: Text('${_selected.length} محدد',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      actions: [
        IconButton(
            icon: const Icon(Icons.label_rounded),
            onPressed: _batchTag,
            tooltip: 'وسم'),
        IconButton(
            icon: const Icon(Icons.drive_file_move_rounded),
            onPressed: _batchMove,
            tooltip: 'نقل'),
        IconButton(
            icon: const Icon(Icons.star_rounded, color: Colors.amber),
            onPressed: _batchFavorite,
            tooltip: 'مفضلة'),
        IconButton(
            icon: const Icon(Icons.delete_rounded, color: Colors.red),
            onPressed: _batchDelete,
            tooltip: 'حذف'),
      ],
    );
  }

  Future<void> _openFile(Map<String, dynamic> f) async {
    await _db.markOpened(f['id']);
    if (!mounted) return;
    await Navigator.push(
      context,
      pageRoute(PdfViewerScreen(filePath: f['path'], fileName: f['name'])),
    );
    _load();
  }
}