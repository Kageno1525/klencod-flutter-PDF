import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';
import '../services/pdf_tools_service.dart';
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

  Future<void> _createSub() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مجموعة فرعية'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
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
      final dest = '${pdfDir.path}/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
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

  Route _fadeSlideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [const Color(0xFF0F0F1A), const Color(0xFF1A1A2E), const Color(0xFF16213E)]
          : [const Color(0xFFF5F7FA), const Color(0xFFE4E8F0), const Color(0xFFDCE3F0)],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _importPdfs,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bg),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_groups.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('📁 مجموعات فرعية',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      ..._groups.map((g) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _glass(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.amber.withOpacity(0.2),
                                  child: const Icon(Icons.folder, color: Colors.amber),
                                ),
                                title: Text(g['name']),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    _fadeSlideRoute(GroupScreen(
                                      groupId: g['id'],
                                      groupName: g['name'],
                                    )),
                                  );
                                  _load();
                                },
                              ),
                            ),
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (_files.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('📄 الملفات',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      ..._files.map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _glass(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red.withOpacity(0.15),
                                  child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                                ),
                                title: Text(f['name'], maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(_sizeText(f['size']), style: const TextStyle(fontSize: 11)),
                                onTap: () async {
                                  await _db.markOpened(f['id']);
                                  await Navigator.push(
                                    context,
                                    _fadeSlideRoute(PdfViewerScreen(
                                      filePath: f['path'],
                                      fileName: f['name'],
                                    )),
                                  );
                                },
                                onLongPress: () => _showOptions(f),
                              ),
                            ),
                          )),
                    ],
                    if (_groups.isEmpty && _files.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Text('هذه المجموعة فارغة', style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSub,
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }

  void _showOptions(Map<String, dynamic> f) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share, color: Colors.green),
                title: const Text('مشاركة'),
                onTap: () {
                  Navigator.pop(context);
                  _tools.shareFile(f['path'], f['name']);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.indigo),
                title: const Text('إعادة تسمية'),
                onTap: () async {
                  Navigator.pop(context);
                  final ctrl = TextEditingController(text: f['name']);
                  final n = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('إعادة تسمية'),
                      content: TextField(controller: ctrl),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                          child: const Text('حفظ'),
                        ),
                      ],
                    ),
                  );
                  if (n != null && n.isNotEmpty) {
                    await _db.updateFile(f['id'], {'name': n});
                    _load();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف'),
                onTap: () async {
                  Navigator.pop(context);
                  try { await File(f['path']).delete(); } catch (_) {}
                  await _db.deleteFile(f['id']);
                  _load();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sizeText(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _glass({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.8),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}