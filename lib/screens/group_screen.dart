import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/database_service.dart';
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
  List<Map<String, dynamic>> _subGroups = [];
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
      _subGroups = groups;
      _files = files;
      _isLoading = false;
    });
  }

  Future<void> _createSubGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مجموعة فرعية'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم المجموعة الفرعية'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
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

  Future<void> _importPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final appDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${appDir.path}/pdfs');
    if (!await pdfDir.exists()) await pdfDir.create(recursive: true);

    for (final file in result.files) {
      if (file.path == null) continue;
      final sourceFile = File(file.path!);
      final destPath = '${pdfDir.path}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await sourceFile.copy(destPath);
      final stat = await File(destPath).stat();
      await _db.insertFile(
        name: file.name,
        path: destPath,
        size: stat.size,
        groupId: widget.groupId,
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _importPdf,
            tooltip: 'استيراد PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_subGroups.isNotEmpty) ...[
                  const Text('المجموعات الفرعية',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._subGroups.map((g) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scheme.secondaryContainer,
                            child: Icon(Icons.folder, color: scheme.onSecondaryContainer),
                          ),
                          title: Text(g['name']),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupScreen(
                                  groupId: g['id'],
                                  groupName: g['name'],
                                ),
                              ),
                            );
                            _load();
                          },
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
                if (_files.isNotEmpty) ...[
                  const Text('الملفات',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._files.map((f) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scheme.errorContainer,
                            child: Icon(Icons.picture_as_pdf, color: scheme.onErrorContainer),
                          ),
                          title: Text(f['name'], maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(_formatSize(f['size'])),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PdfViewerScreen(
                                  filePath: f['path'],
                                  fileName: f['name'],
                                ),
                              ),
                            );
                          },
                        ),
                      )),
                ],
                if (_subGroups.isEmpty && _files.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          Icon(Icons.folder_open, size: 80, color: scheme.outline),
                          const SizedBox(height: 16),
                          Text('هذه المجموعة فارغة',
                              style: TextStyle(fontSize: 16, color: scheme.outline)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSubGroup,
        tooltip: 'مجموعة فرعية',
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}