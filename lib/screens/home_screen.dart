import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/pdf_tools_service.dart';
import 'group_screen.dart';
import 'pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final PdfToolsService _tools = PdfToolsService.instance;

  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _recent = [];
  bool _isLoading = true;
  bool _favoritesOnly = false;
  String _sortBy = 'added_at DESC';
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _isLoading = true);
    final groups = await _db.getGroups(parentId: null);
    final files = _search.isEmpty
        ? await _db.getFiles(favoritesOnly: _favoritesOnly, sortBy: _sortBy)
        : await _db.searchFiles(_search);
    final recent = await _db.getRecentFiles(limit: 5);
    setState(() {
      _groups = groups;
      _files = files;
      _recent = recent;
      _isLoading = false;
    });
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
      await _db.insertFile(name: f.name, path: dest, size: stat.size);
    }
    _reload();
  }

  Future<void> _createGroup() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مجموعة جديدة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم المجموعة'),
        ),
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
      await _db.insertGroup(name);
      _reload();
    }
  }

  Future<void> _showTools() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _toolsSheet(),
    );
  }

  Widget _toolsSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'أدوات إضافية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _toolTile(
                icon: Icons.image,
                title: 'صور إلى PDF',
                subtitle: 'اختر صور وحوّلها لملف PDF',
                onTap: () async {
                  Navigator.pop(context);
                  final id = await _tools.importImagesAsPdf(context);
                  if (id != null) {
                    _reload();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إنشاء ملف PDF')),
                      );
                    }
                  }
                },
              ),
              _toolTile(
                icon: Icons.camera_alt,
                title: 'مسح بالكاميرا',
                subtitle: 'صوّر ورقة وحولها لـ PDF',
                onTap: () async {
                  Navigator.pop(context);
                  final path = await _tools.scanFromCamera();
                  if (path != null) {
                    final stat = await File(path).stat();
                    await _db.insertFile(
                      name: path.split('/').last,
                      path: path,
                      size: stat.size,
                    );
                    _reload();
                  }
                },
              ),
              _toolTile(
                icon: Icons.backup,
                title: 'نسخة احتياطية كاملة (ZIP)',
                subtitle: 'الداتابيز + كل الملفات',
                onTap: () async {
                  Navigator.pop(context);
                  await _backupFull();
                },
              ),
              _toolTile(
                icon: Icons.storage,
                title: 'نسخة احتياطية للداتابيز فقط',
                subtitle: 'ملف .db بإصدار وتاريخ',
                onTap: () async {
                  Navigator.pop(context);
                  await _backupDb();
                },
              ),
              _toolTile(
                icon: Icons.restore,
                title: 'استعادة نسخة احتياطية',
                subtitle: 'اختر ملف .db لاستعادته',
                onTap: () async {
                  Navigator.pop(context);
                  await _restoreDb();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      onTap: onTap,
    );
  }

  Future<void> _backupFull() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري إنشاء النسخة...')),
      );
      final file = await _tools.exportFullBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم الحفظ في: ${file.path}'),
          action: SnackBarAction(
            label: 'مشاركة',
            onPressed: () => _tools.shareBackup(file.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  Future<void> _backupDb() async {
    try {
      final file = await _db.exportDatabaseBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم الحفظ في: ${file.path}'),
          action: SnackBarAction(
            label: 'مشاركة',
            onPressed: () => _tools.shareBackup(file.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  Future<void> _restoreDb() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    if (!path.endsWith('.db')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الملف لازم يكون .db')),
        );
      }
      return;
    }
    try {
      await _db.restoreDatabaseFromBackup(path);
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الاستعادة بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  Future<void> _showFileOptions(Map<String, dynamic> file) async {
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
                leading: Icon(
                  file['is_favorite'] == 1 ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                title: Text(file['is_favorite'] == 1 ? 'إزالة من المفضلة' : 'إضافة للمفضلة'),
                onTap: () async {
                  await _db.toggleFavorite(file['id'], file['is_favorite'] != 1);
                  if (mounted) Navigator.pop(context);
                  _reload();
                },
              ),
              ListTile(
                leading: const Icon(Icons.label, color: Colors.blue),
                title: const Text('إضافة وسم ملون'),
                onTap: () async {
                  Navigator.pop(context);
                  final color = await _pickTagColor();
                  if (color != null) {
                    await _db.updateFile(
                      file['id'],
                      {'tag_color': color.value, 'tag_label': 'وسم'},
                    );
                    _reload();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.green),
                title: const Text('مشاركة'),
                onTap: () {
                  Navigator.pop(context);
                  _tools.shareFile(file['path'], file['name']);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code, color: Colors.purple),
                title: const Text('عرض QR Code'),
                onTap: () {
                  Navigator.pop(context);
                  _showQr(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.indigo),
                title: const Text('إعادة تسمية'),
                onTap: () async {
                  Navigator.pop(context);
                  await _rename(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف نهائي'),
                onTap: () async {
                  Navigator.pop(context);
                  await _delete(file);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Color?> _pickTagColor() async {
    const colors = [
      Colors.red, Colors.orange, Colors.yellow,
      Colors.green, Colors.blue, Colors.purple, Colors.pink,
    ];
    return showDialog<Color>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('اختر اللون'),
        children: colors
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, c),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(c.toString().split('(').last.split(')').first),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _showQr(Map<String, dynamic> file) {
    final info = 'File: ${file['name']}\nSize: ${file['size']} bytes\nAdded: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(file['added_at']))}';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(file['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: QrImageView(
                data: info,
                version: QrVersions.auto,
                size: 220,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'هذا QR يحتوي على بيانات الملف فقط للعرض على الجهاز نفسه',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(Map<String, dynamic> file) async {
    final ctrl = TextEditingController(text: file['name']);
    final newName = await showDialog<String>(
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
    if (newName != null && newName.isNotEmpty) {
      await _db.updateFile(file['id'], {'name': newName});
      _reload();
    }
  }

  Future<void> _delete(Map<String, dynamic> file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملف؟'),
        content: const Text('هيتم حذفه من التطبيق والجهاز نهائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await File(file['path']).delete();
      } catch (_) {}
      await _db.deleteFile(file['id']);
      _reload();
    }
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
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
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
        title: const Text('مستودع PDF', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: themeProvider.toggleTheme,
            tooltip: 'تبديل الثيم',
          ),
          IconButton(
            icon: const Icon(Icons.build_circle_outlined),
            onPressed: _showTools,
            tooltip: 'أدوات',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bg),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _glass(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم الملف...',
                      prefixIcon: const Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                                _reload();
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) {
                      setState(() => _search = v);
                      _reload();
                    },
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    FilterChip(
                      label: const Text('⭐ المفضلة'),
                      selected: _favoritesOnly,
                      onSelected: (v) {
                        setState(() => _favoritesOnly = v);
                        _reload();
                      },
                    ),
                    const SizedBox(width: 8),
                    _sortChip('الأحدث', 'added_at DESC'),
                    const SizedBox(width: 8),
                    _sortChip('الأقدم', 'added_at ASC'),
                    const SizedBox(width: 8),
                    _sortChip('الحجم', 'size DESC'),
                    const SizedBox(width: 8),
                    _sortChip('أبجدي', 'name ASC'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            if (_recent.isNotEmpty && _search.isEmpty) ...[
                              _sectionTitle('🕐 آخر ما فتحت'),
                              SizedBox(
                                height: 100,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _recent.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (_, i) {
                                    final f = _recent[i];
                                    return GestureDetector(
                                      onTap: () => _openFile(f),
                                      child: _glass(
                                        width: 140,
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 32),
                                            const SizedBox(height: 4),
                                            Text(f['name'],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_groups.isNotEmpty) ...[
                              _sectionTitle('📁 المجموعات'),
                              ..._groups.map(_groupTile),
                              const SizedBox(height: 16),
                            ],
                            if (_files.isNotEmpty || _groups.isEmpty)
                              _sectionTitle('📄 الملفات'),
                            ..._files.map(_fileTile),
                            if (_files.isEmpty && _groups.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 60),
                                  child: Text(
                                    'لا توجد ملفات بعد\nاضغط + لاستيراد PDF',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'import',
            onPressed: _importPdfs,
            child: const Icon(Icons.upload_file),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'group',
            onPressed: _createGroup,
            child: const Icon(Icons.create_new_folder),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );

  Widget _sortChip(String label, String value) => ChoiceChip(
        label: Text(label),
        selected: _sortBy == value,
        onSelected: (_) {
          setState(() => _sortBy = value);
          _reload();
        },
      );

  Widget _groupTile(Map<String, dynamic> g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _glass(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.amber.withOpacity(0.2),
            child: const Icon(Icons.folder, color: Colors.amber),
          ),
          title: Text(g['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              _fadeSlideRoute(GroupScreen(groupId: g['id'], groupName: g['name'])),
            );
            _reload();
          },
        ),
      ),
    );
  }

  Widget _fileTile(Map<String, dynamic> f) {
    final tagColor = f['tag_color'] != null ? Color(f['tag_color'] as int) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _glass(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.withOpacity(0.15),
            child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
          ),
          title: Text(f['name'], maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Row(children: [
            Text(
              DateFormat('yyyy/MM/dd').format(
                DateTime.fromMillisecondsSinceEpoch(f['added_at']),
              ),
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 6),
            Text(_sizeText(f['size']), style: const TextStyle(fontSize: 11)),
            if (tagColor != null) ...[
              const SizedBox(width: 6),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle),
              ),
            ],
          ]),
          trailing: f['is_favorite'] == 1
              ? const Icon(Icons.star, color: Colors.amber, size: 20)
              : null,
          onTap: () => _openFile(f),
          onLongPress: () => _showFileOptions(f),
        ),
      ),
    );
  }

  Future<void> _openFile(Map<String, dynamic> f) async {
    await _db.markOpened(f['id']);
    await Navigator.push(
      context,
      _fadeSlideRoute(PdfViewerScreen(filePath: f['path'], fileName: f['name'])),
    );
    _reload();
  }

  String _sizeText(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _glass({
    required Widget child,
    double? width,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.8),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}