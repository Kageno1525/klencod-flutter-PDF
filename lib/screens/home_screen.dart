import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/common.dart';
import 'favorites_screen.dart';
import 'groups_screen.dart';
import 'pdf_viewer_screen.dart';
import 'photo_review_screen.dart';
import 'recent_screen.dart';
import 'settings_screen.dart';
import 'tools_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService.instance;
  final _tools = PdfToolsService.instance;
  final _pageCtrl = PageController();
  int _tab = 0;
  int _refreshTick = 0;

  final Map<int, Map<String, dynamic>> _selectedFiles = {};
  bool get _inSelectionMode => _selectedFiles.isNotEmpty;

  List<Map<String, dynamic>> _currentTabFiles = [];

  static const _titles = [
    'كل الملفات',
    'المجموعات',
    'المفضلة',
    'الأخيرة',
    'الأدوات',
    'الإعدادات',
  ];

  @override
  void initState() {
    super.initState();
    selectedTabNotifier.addListener(_onTabNotify);
  }

  @override
  void dispose() {
    selectedTabNotifier.removeListener(_onTabNotify);
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onTabNotify() {
    final i = selectedTabNotifier.value;
    if (_tab != i && mounted) _onTabSelected(i);
  }

  void _bumpRefresh() => setState(() => _refreshTick++);

  void _onTabSelected(int i) {
    setState(() {
      _selectedFiles.clear();
      _tab = i;
    });
    _pageCtrl.jumpToPage(i);
  }

  void _toggleSelection(Map<String, dynamic> f) {
    setState(() {
      final id = f['id'] as int;
      if (_selectedFiles.containsKey(id)) {
        _selectedFiles.remove(id);
      } else {
        _selectedFiles[id] = f;
      }
    });
  }

  void _enterSelection(Map<String, dynamic> f) {
    setState(() => _selectedFiles[f['id'] as int] = f);
  }

  void _clearSelection() => setState(() => _selectedFiles.clear());

  void _selectAll() {
    setState(() {
      for (final f in _currentTabFiles) {
        _selectedFiles[f['id'] as int] = f;
      }
    });
  }

  void _onFilesLoaded(List<Map<String, dynamic>> files) {
    _currentTabFiles = files;
  }

  Future<void> _batchShare() async {
    await batchShare(_selectedFiles.values.toList());
    _clearSelection();
  }

  Future<void> _batchDelete() async {
    final count = _selectedFiles.length;
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
      await batchDelete(_selectedFiles.values.toList());
      _clearSelection();
      _bumpRefresh();
    }
  }

  Future<void> _batchFavorite() async {
    await batchFavorite(_selectedFiles.values.toList(), true);
    _clearSelection();
    _bumpRefresh();
  }

  Future<void> _batchMove() async {
    final target = await pickGroup(context, title: 'نقل إلى...');
    if (target == null) return;
    final gid = target == -1 ? null : target;
    await batchMove(_selectedFiles.values.toList(), gid);
    _clearSelection();
    _bumpRefresh();
  }

  Future<void> _batchTag() async {
    final color = await pickTagColor(context);
    if (color == null) return;
    await batchTag(_selectedFiles.values.toList(), color);
    _clearSelection();
    _bumpRefresh();
  }

  PreferredSizeWidget _buildNormalAppBar() {
    final tp = context.watch<ThemeProvider>();
    return AppBar(
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, size: 26),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Text(_titles[_tab],
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      actions: [
        ThemeToggleButton(isDark: tp.isDark, onTap: tp.toggleTheme),
        const SizedBox(width: 8),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final primary = Theme.of(context).colorScheme.primary;
    return AppBar(
      backgroundColor: primary.withOpacity(0.08),
      leading: IconButton(
          icon: const Icon(Icons.close_rounded), onPressed: _clearSelection),
      title: Text('${_selectedFiles.length} محدد',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      actions: [
        IconButton(
            icon: const Icon(Icons.select_all_rounded),
            onPressed: _selectAll,
            tooltip: 'تحديد الكل'),
        IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.green),
            onPressed: _batchShare,
            tooltip: 'مشاركة'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      drawer: _buildDrawer(),
      appBar:
          _inSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _tab = i),
        children: [
          HomeTab(
            refreshTick: _refreshTick,
            onChanged: _bumpRefresh,
            selectedFiles: _selectedFiles,
            onToggleSelection: _toggleSelection,
            onEnterSelection: _enterSelection,
            onFilesLoaded: _onFilesLoaded,
          ),
          GroupsScreen(refreshTick: _refreshTick, onChanged: _bumpRefresh),
          FavoritesScreen(
            refreshTick: _refreshTick,
            onChanged: _bumpRefresh,
            selectedFiles: _selectedFiles,
            onToggleSelection: _toggleSelection,
            onEnterSelection: _enterSelection,
            onFilesLoaded: _onFilesLoaded,
          ),
          RecentScreen(
            refreshTick: _refreshTick,
            onChanged: _bumpRefresh,
            selectedFiles: _selectedFiles,
            onToggleSelection: _toggleSelection,
            onEnterSelection: _enterSelection,
            onFilesLoaded: _onFilesLoaded,
          ),
          ToolsScreen(
            onImport: _importPdfs,
            onImagesToPdf: _imagesToPdf,
            onCameraScan: _cameraScan,
            onMergePdfs: _mergePdfs,
            onSplitPdf: _splitPdf,
            onBackupFull: _backupFull,
            onBackupDb: _backupDb,
            onRestore: _restore,
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: MainBottomBar(currentTab: _tab),
      floatingActionButton:
          (_tab == 0 || _tab == 1) && !_inSelectionMode ? _buildFab() : null,
    );
  }

  Widget _buildFab() {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _tab == 0 ? _showAddMenu : _createPartition,
        splashColor: Colors.white.withOpacity(0.2),
        highlightColor: Colors.transparent,
        child: Ink(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            _tab == 0 ? Icons.add_rounded : Icons.create_new_folder_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Theme.of(context).cardColor,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PDF Vault',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text('مستودع ملفاتك',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _drawerItem(Icons.library_books_rounded, 'المجموعات', () {
              Navigator.pop(context);
              _onTabSelected(1);
            }, highlight: true),
            const Divider(height: 8, indent: 16, endIndent: 16),
            _drawerItem(Icons.upload_file_rounded, 'استيراد PDF', () {
              Navigator.pop(context);
              _importPdfs();
            }),
            _drawerItem(Icons.image_rounded, 'صور إلى PDF', () {
              Navigator.pop(context);
              _imagesToPdf();
            }),
            _drawerItem(Icons.camera_alt_rounded, 'مسح بالكاميرا', () {
              Navigator.pop(context);
              _cameraScan();
            }),
            const Divider(height: 24),
            _drawerItem(Icons.backup_rounded, 'نسخة احتياطية كاملة', () {
              Navigator.pop(context);
              _backupFull();
            }),
            _drawerItem(Icons.storage_rounded, 'نسخة الداتابيز فقط', () {
              Navigator.pop(context);
              _backupDb();
            }),
            _drawerItem(Icons.restore_rounded, 'استعادة نسخة', () {
              Navigator.pop(context);
              _restore();
            }),
            const Spacer(),
            const Divider(height: 1),
            _drawerItem(Icons.info_outline_rounded, 'حول التطبيق', () {
              Navigator.pop(context);
              _showAbout();
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap,
      {bool highlight = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: highlight
              ? const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: highlight ? null : primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: highlight ? Colors.white : primary, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              fontSize: 14)),
      onTap: onTap,
    );
  }

  Future<void> _showAddMenu() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddMenuSheet(
        onImport: () {
          Navigator.pop(context);
          _importPdfs();
        },
        onImages: () {
          Navigator.pop(context);
          _imagesToPdf();
        },
        onCamera: () {
          Navigator.pop(context);
          _cameraScan();
        },
        onGroup: () {
          Navigator.pop(context);
          _createPartition();
        },
      ),
    );
  }

  Future<void> _createPartition() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('قسم جديد'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم القسم'),
        ),
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
      await _db.insertGroup(name);
      _bumpRefresh();
    }
  }

  Future<void> _importPdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    final target = await pickGroup(context, title: 'أين تحفظ الملفات؟');
    if (target == null) return;
    final groupId = target == -1 ? null : target;

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
          name: f.name, path: dest, size: stat.size, groupId: groupId);
    }
    _bumpRefresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم استيراد ${result.files.length} ملف')),
    );
  }

  Future<void> _imagesToPdf() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    if (!mounted) return;
    final saveResult = await showSavePdfDialog(
      context,
      defaultName: 'صور_${DateTime.now().millisecondsSinceEpoch}',
    );
    if (saveResult == null) return;

    try {
      final path = await _tools.imagesToPdf(
        images,
        baseName: saveResult.name,
      );
      final stat = await File(path).stat();
      await _db.insertFile(
        name: saveResult.name,
        path: path,
        size: stat.size,
        groupId: saveResult.groupId,
      );
      _bumpRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء PDF من الصور')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _cameraScan() async {
    final picker = ImagePicker();
    final files = <File>[];

    while (true) {
      final photo = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 90);
      if (photo == null) break;
      files.add(File(photo.path));
      if (!mounted) return;
      final more = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('صورة أخرى؟'),
          content: Text('التقطت ${files.length} صورة. تضيف صورة؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('لا، خلاص')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('نعم')),
          ],
        ),
      );
      if (more != true) break;
    }
    if (files.isEmpty) return;

    if (!mounted) return;
    final reviewed = await Navigator.push<List<File>>(
      context,
      pageRoute(PhotoReviewScreen(photos: files)),
    );
    if (reviewed == null || reviewed.isEmpty) return;

    if (!mounted) return;
    final saveResult = await showSavePdfDialog(
      context,
      defaultName: 'مسح_${DateTime.now().millisecondsSinceEpoch}',
    );
    if (saveResult == null) return;

    try {
      final path = await _tools.imagesToPdf(
        reviewed.map((f) => XFile(f.path)).toList(),
        baseName: saveResult.name,
      );
      final stat = await File(path).stat();
      await _db.insertFile(
        name: saveResult.name,
        path: path,
        size: stat.size,
        groupId: saveResult.groupId,
      );
      _bumpRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ ${reviewed.length} صور في PDF')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _mergePdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.length < 2) {
      if (mounted && (result?.files.length ?? 0) == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر ملفين على الأقل للدمج')),
        );
      }
      return;
    }
    final paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();
    if (paths.length < 2) return;

    if (!mounted) return;
    final saveResult = await showSavePdfDialog(
      context,
      defaultName: 'مدموج_${DateTime.now().millisecondsSinceEpoch}',
    );
    if (saveResult == null) return;

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري الدمج...')),
      );
      final file =
          await _tools.mergePdfs(paths, baseName: saveResult.name);
      final stat = await file.stat();
      await _db.insertFile(
        name: saveResult.name,
        path: file.path,
        size: stat.size,
        groupId: saveResult.groupId,
      );
      _bumpRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم دمج ${paths.length} ملفات'),
          action: SnackBarAction(
            label: 'مشاركة',
            onPressed: () => _tools.shareFile(file.path, saveResult.name),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _splitPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    if (!mounted) return;
    final range = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => _SplitDialog(),
    );
    if (range == null) return;

    if (!mounted) return;
    final saveResult = await showSavePdfDialog(
      context,
      defaultName: 'مستخرج_${range['start']}_${range['end']}',
    );
    if (saveResult == null) return;

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري الاستخراج...')),
      );
      final file = await _tools.extractRange(
          path, range['start']!, range['end']!,
          baseName: saveResult.name);
      final stat = await file.stat();
      await _db.insertFile(
        name: saveResult.name,
        path: file.path,
        size: stat.size,
        groupId: saveResult.groupId,
      );
      _bumpRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'تم استخراج الصفحات ${range['start']}-${range['end']}'),
          action: SnackBarAction(
            label: 'مشاركة',
            onPressed: () => _tools.shareFile(file.path, saveResult.name),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
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
          content: Text('تم الحفظ: ${file.path}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
              label: 'مشاركة',
              onPressed: () => _tools.shareBackup(file.path)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _backupDb() async {
    try {
      final file = await _db.exportDatabaseBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم الحفظ: ${file.path}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
              label: 'مشاركة',
              onPressed: () => _tools.shareBackup(file.path)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    try {
      if (path.endsWith('.zip')) {
        await _tools.restoreFullBackup(path);
      } else if (path.endsWith('.db')) {
        await _db.restoreDatabaseFromBackup(path);
      } else {
        return;
      }
      _bumpRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الاستعادة بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 12),
            Text('PDF Vault'),
          ],
        ),
        content: const Text(
            'الإصدار: 1.0.0\nمستودع PDF مع أقسام ومجلدات وأدوات احترافية.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً')),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SPLIT DIALOG
// ═══════════════════════════════════════════════════════════════════

class _SplitDialog extends StatefulWidget {
  @override
  State<_SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends State<_SplitDialog> {
  final _startCtrl = TextEditingController(text: '1');
  final _endCtrl = TextEditingController(text: '1');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('استخراج صفحات'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'من صفحة',
                      border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _endCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'إلى صفحة',
                      border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('مثال: من 1 إلى 3 = بيحفظ أول 3 صفحات',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            final s = int.tryParse(_startCtrl.text.trim());
            final e = int.tryParse(_endCtrl.text.trim());
            if (s == null || e == null || s < 1 || e < s) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('أرقام غير صحيحة')),
              );
              return;
            }
            Navigator.pop(context, {'start': s, 'end': e});
          },
          child: const Text('استخراج'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HOME TAB (GRID + ZOOM)
// ═══════════════════════════════════════════════════════════════════

class HomeTab extends StatefulWidget {
  final int refreshTick;
  final VoidCallback onChanged;
  final Map<int, Map<String, dynamic>> selectedFiles;
  final void Function(Map<String, dynamic>) onToggleSelection;
  final void Function(Map<String, dynamic>) onEnterSelection;
  final void Function(List<Map<String, dynamic>>) onFilesLoaded;

  const HomeTab({
    super.key,
    required this.refreshTick,
    required this.onChanged,
    required this.selectedFiles,
    required this.onToggleSelection,
    required this.onEnterSelection,
    required this.onFilesLoaded,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _db = DatabaseService.instance;
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  String _sortBy = 'added_at DESC';
  final _searchCtrl = TextEditingController();
  String _search = '';

  bool get _inSelectionMode => widget.selectedFiles.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HomeTab old) {
    super.didUpdateWidget(old);
    if (widget.refreshTick != old.refreshTick) _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final files = _search.isEmpty
        ? await _db.getFiles(allGroups: true, sortBy: _sortBy)
        : await _db.searchFiles(_search);
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
    widget.onFilesLoaded(files);
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: ValueListenableBuilder<double>(
        valueListenable: gridSizeNotifier,
        builder: (_, gridSize, __) {
          return PinchZoomWrapper(
            child: RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _buildSearch()),
                  SliverToBoxAdapter(child: _buildSortChips()),
                  if (_files.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: SectionHeader(
                        icon: Icons.picture_as_pdf_rounded,
                        title:
                            _search.isEmpty ? 'كل الملفات' : 'نتائج البحث',
                        color: const Color(0xFFDC2626),
                        trailing: '${_files.length}',
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: gridSize,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.82,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final f = _files[i];
                            final isSel =
                                widget.selectedFiles.containsKey(f['id']);
                            return RepaintBoundary(
                              child: FileGridItem(
                                file: f,
                                isSelected: isSel,
                                inSelectionMode: _inSelectionMode,
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
                            );
                          },
                          childCount: _files.length,
                        ),
                      ),
                    ),
                  ],
                  if (_loading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  if (!_loading && _files.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.picture_as_pdf_outlined,
                        title: _search.isEmpty
                            ? 'لا توجد ملفات بعد'
                            : 'لا توجد نتائج',
                        subtitle: _search.isEmpty
                            ? 'اضغط زر + لاستيراد ملف PDF'
                            : 'جرّب كلمة بحث أخرى',
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearch() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06)),
        ),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'ابحث في كل الملفات...',
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                      _load();
                    },
                  )
                : null,
          ),
          onChanged: (v) {
            setState(() => _search = v);
            _load();
          },
        ),
      ),
    );
  }

  Widget _buildSortChips() {
    final sorts = [
      ('الأحدث', 'added_at DESC'),
      ('الأقدم', 'added_at ASC'),
      ('الحجم', 'size DESC'),
      ('أبجدي', 'name ASC'),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sorts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final selected = _sortBy == sorts[i].$2;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                setState(() => _sortBy = sorts[i].$2);
                _load();
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFF2563EB)])
                      : null,
                  color: selected
                      ? null
                      : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: selected
                      ? null
                      : Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.center,
                child: Text(
                  sorts[i].$1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
}