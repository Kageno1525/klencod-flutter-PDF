import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../main.dart';
import '../services/database_service.dart';
import 'group_screen.dart';
import 'pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService.instance;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final groups = await _db.getGroups(parentId: null);
    final files = _searchQuery.isEmpty
        ? await _db.getFiles(groupId: null)
        : await _db.searchFiles(_searchQuery);
    setState(() {
      _groups = groups;
      _files = files;
      _isLoading = false;
    });
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
      );
    }
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم استيراد ${result.files.length} ملف بنجاح')),
      );
    }
  }

  Future<void> _createGroup({int? parentId}) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مجموعة جديدة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم المجموعة'),
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
      await _db.insertGroup(name, parentId: parentId);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مستودع PDF'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: themeProvider.toggleTheme,
            tooltip: 'تبديل الثيم',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن ملف...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadData();
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _loadData();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // عرض المجموعات
                        if (_groups.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('المجموعات',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          ..._groups.map((g) => _buildGroupTile(g)),
                        ],
                        // عرض الملفات
                        if (_files.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('الملفات',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          ..._files.map((f) => _buildFileTile(f)),
                        ],
                        if (_groups.isEmpty && _files.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 80),
                              child: Column(
                                children: [
                                  Icon(Icons.folder_open, size: 80, color: scheme.outline),
                                  const SizedBox(height: 16),
                                  Text('لا توجد ملفات أو مجموعات بعد',
                                      style: TextStyle(fontSize: 16, color: scheme.outline)),
                                  const SizedBox(height: 8),
                                  Text('اضغط + لإضافة مجموعة أو استيراد PDF',
                                      style: TextStyle(color: scheme.outline)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'import',
            onPressed: _importPdf,
            tooltip: 'استيراد PDF',
            child: const Icon(Icons.upload_file),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'group',
            onPressed: () => _createGroup(),
            tooltip: 'مجموعة جديدة',
            child: const Icon(Icons.create_new_folder),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.folder, color: scheme.onPrimaryContainer),
        ),
        title: Text(group['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('مجموعة'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupScreen(
                groupId: group['id'],
                groupName: group['name'],
              ),
            ),
          );
          _loadData();
        },
      ),
    );
  }

  Widget _buildFileTile(Map<String, dynamic> file) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.errorContainer,
          child: Icon(Icons.picture_as_pdf, color: scheme.onErrorContainer),
        ),
        title: Text(file['name'], maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_formatSize(file['size'])),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                filePath: file['path'],
                fileName: file['name'],
              ),
            ),
          );
          _loadData();
        },
        onLongPress: () => _confirmDeleteFile(file),
      ),
    );
  }

  void _confirmDeleteFile(Map<String, dynamic> file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملف'),
        content: Text('هل تريد حذف "${file['name']}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _db.deleteFile(file['id']);
              try {
                await File(file['path']).delete();
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}