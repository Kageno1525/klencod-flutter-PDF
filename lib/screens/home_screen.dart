import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/common.dart';
import 'favorites_screen.dart';
import 'groups_screen.dart';
import 'pdf_viewer_screen.dart';
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
    'المفضلة',
    'الأخيرة',
    'الأدوات',
    'الإعدادات',
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _bumpRefresh() => setState(() => _refreshTick++);

  void _onTabSelected(int i) {
    setState(() {
      _selectedFiles.clear();
      _tab = i;
    });
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  // ────── Selection ──────
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت الإضافة للمفضلة')),
    );
  }

  Future<void> _batchMove() async {
    final target = await pickGroup(context, title: 'نقل إلى...');
    if (target == null) return;
    final gid = target == -1 ? null : target;
    await batchMove(_selectedFiles.values.toList(), gid);
    _clearSelection();
    _bumpRefresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم النقل')),
    );
  }

  Future<void> _batchTag() async {
    final color = await pickTagColor(context);
    if (color == null) return;
    await batchTag(_selectedFiles.values.toList(), color);
    _clearSelection();
    _bumpRefresh();
  }

  // ────── AppBars ──────
  PreferredSizeWidget _buildNormalAppBar() {
    final tp = context.watch<ThemeProvider>();
    return AppBar(
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, size: 26),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
          tooltip: 'القائمة',
        ),
      ),
      title: Text(
        _titles[_tab],
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
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
        icon: const Icon(Icons.close_rounded),
        onPressed: _clearSelection,
        tooltip: 'إلغاء التحديد',
      ),
      title: Text(
        '${_selectedFiles.length} محدد',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all_rounded),
          onPressed: _selectAll,
          tooltip: 'تحديد الكل',
        ),
        IconButton(
          icon: const Icon(Icons.label_rounded),
          onPressed: _batchTag,
          tooltip: 'وسم',
        ),
        IconButton(
          icon: const Icon(Icons.drive_file_move_rounded),
          onPressed: _batchMove,
          tooltip: 'نقل',
        ),
        IconButton(
          icon: const Icon(Icons.star_rounded, color: Colors.amber),
          onPressed: _batchFavorite,
          tooltip: 'مفضلة',
        ),
        IconButton(
          icon: const Icon(Icons.delete_rounded, color: Colors.red),
          onPressed: _batchDelete,
          tooltip: 'حذف',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      drawer: _buildDrawer(),
      appBar: _inSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
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
            onBackupFull: _backupFull,
            onBackupDb: _backupDb,
            onRestore: _restore,
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _onTabSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.picture_as_pdf_outlined),
                  selectedIcon: Icon(Icons.picture_as_pdf_rounded),
                  label: 'الملفات',
                ),
                NavigationDestination(
                  icon: Icon(Icons.star_outline_rounded),
                  selectedIcon: Icon(Icons.star_rounded),
                  label: 'المفضلة',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_rounded),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: 'الأخيرة',
                ),
                NavigationDestination(
                  icon: Icon(Icons.handyman_outlined),
                  selectedIcon: Icon(Icons.handyman_rounded),
                  label: 'أدوات',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'الإعدادات',
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton:
          _tab == 0 && !_inSelectionMode ? _buildFab() : null,
    );
  }

  Widget _buildFab() {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _showAddMenu,
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
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
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
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _drawerItem(Icons.library_books_rounded, 'المجموعات', () {
              Navigator.pop(context);
              _openGroups();
            }, highlight: true),
            const Divider(height: 8, indent: 16, endIndent: 16),
            _drawerItem(Icons.upload_file_rounded, 'استيراد PDF سريع', () {
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
      trailing: highlight
          ? Icon(Icons.chevron_right_rounded, color: primary, size: 20)
          : null,
      onTap: onTap,
    );
  }

  void _openGroups() async {
    await Navigator.push(context, pageRoute(const GroupsScreen()));
    _bumpRefresh();
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء القسم "$name"'),
          action: SnackBarAction(
            label: 'اذهب',
            onPressed: _openGroups,
          ),
        ),
      );
    }
  }

  Future<void> _importPdfs({int? presetGroupId}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    int? groupId = presetGroupId;
    if (presetGroupId == null) {
      if (!mounted) return;
      final target = await pickGroup(context, title: 'أين تحفظ الملفات؟');
      if (target == null) return;
      groupId = target == -1 ? null : target;
    }

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
        groupId: groupId,
      );
    }
    _bumpRefresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم استيراد ${result.files.length} ملف')),
    );
  }

  Future<void> _imagesToPdf() async {
    try {
      final id = await _tools.importImagesAsPdf(context);
      if (id != null) {
        _bumpRefresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء PDF من الصور')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _cameraScan() async {
    try {
      final path = await _tools.scanFromCamera();
      if (path == null) return;
      final stat = await File(path).stat();
      await _db.insertFile(
        name: path.split('/').last,
        path: path,
        size: stat.size,
      );
      _bumpRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم المسح والحفظ')),
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
            onPressed: () => _tools.shareBackup(file.path),
          ),
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
            onPressed: () => _tools.shareBackup(file.path),
          ),
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
    if (!path.endsWith('.db') && !path.endsWith('.zip')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر ملف .db أو .zip')),
      );
      return;
    }
    try {
      if (path.endsWith('.zip')) {
        await _tools.restoreFullBackup(path);
      } else {
        await _db.restoreDatabaseFromBackup(path);
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإصدار: 1.0.0', style: TextStyle(fontSize: 13)),
            SizedBox(height: 8),
            Text(
              'مستودعك الشخصي لملفات PDF\nمع أقسام ومجلدات متداخلة، بحث، وأدوات احترافية.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HOME TAB (الملفات فقط)
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
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildSearch()),
            SliverToBoxAdapter(child: _buildSortChips()),
            if (_files.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  icon: Icons.picture_as_pdf_rounded,
                  title: _search.isEmpty ? 'كل الملفات' : 'نتائج البحث',
                  color: const Color(0xFFDC2626),
                  trailing: '${_files.length}',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: _files.length,
                  itemBuilder: (ctx, i) {
                    final f = _files[i];
                    final isSel = widget.selectedFiles.containsKey(f['id']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RepaintBoundary(
                        child: FileTile(
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
                      ),
                    );
                  },
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
                  title: _search.isEmpty ? 'لا توجد ملفات بعد' : 'لا توجد نتائج',
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
                : Colors.black.withOpacity(0.06),
            width: 1,
          ),
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
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFF2563EB)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
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
                              : Colors.black.withOpacity(0.06),
                          width: 1,
                        ),
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