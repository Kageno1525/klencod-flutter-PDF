import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/pdf_tools_service.dart';
import 'group_screen.dart';
import 'pdf_viewer_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// SHELL
// ═══════════════════════════════════════════════════════════════════

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

  static const _titles = [
    'مستودع PDF',
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
    setState(() => _tab = i);
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      extendBody: true,
      drawer: _buildDrawer(),
      appBar: AppBar(
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
          _ThemeToggleButton(isDark: tp.isDark, onTap: tp.toggleTheme),
          const SizedBox(width: 8),
        ],
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _tab = i),
        children: [
          _HomeTab(
            refreshTick: _refreshTick,
            onOpenGroup: _openGroup,
            onOpenFile: _openFile,
            onFileOptions: _openFileOptions,
            onGroupOptions: _openGroupOptions,
            onRefresh: _bumpRefresh,
          ),
          _FavoritesTab(
            refreshTick: _refreshTick,
            onOpenFile: _openFile,
          ),
          _RecentTab(
            refreshTick: _refreshTick,
            onOpenFile: _openFile,
          ),
          _ToolsTab(
            onImport: _importPdfs,
            onImagesToPdf: _imagesToPdf,
            onCameraScan: _cameraScan,
            onBackupFull: _backupFull,
            onBackupDb: _backupDb,
            onRestore: _restore,
          ),
          const _SettingsTab(),
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
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'الرئيسية',
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
      floatingActionButton: _tab == 0 ? _buildFab() : null,
    );
  }

  Widget _buildFab() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _showAddMenu,
        child: Ink(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
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
                  colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
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
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: primary, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      onTap: onTap,
    );
  }

  // ───────────── Actions ─────────────
  Future<void> _showAddMenu() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddMenuSheet(
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
          _createGroup();
        },
      ),
    );
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
      await _db.insertFile(name: f.name, path: dest, size: stat.size);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  Future<void> _createGroup() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('مجموعة جديدة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم المجموعة'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  Future<void> _openFile(Map<String, dynamic> f) async {
    await _db.markOpened(f['id']);
    if (!mounted) return;
    await Navigator.push(
      context,
      _pageRoute(PdfViewerScreen(filePath: f['path'], fileName: f['name'])),
    );
    _bumpRefresh();
  }

  void _openGroup(Map<String, dynamic> g) async {
    await Navigator.push(
      context,
      _pageRoute(
        GroupScreen(groupId: g['id'], groupName: g['name']),
      ),
    );
    _bumpRefresh();
  }

  void _openFileOptions(Map<String, dynamic> f) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FileOptionsSheet(
        file: f,
        onChanged: _bumpRefresh,
      ),
    );
  }

  void _openGroupOptions(Map<String, dynamic> g) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GroupOptionsSheet(
        group: g,
        onChanged: _bumpRefresh,
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF7C3AED)),
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
              'مستودعك الشخصي لملفات PDF\nمع مجموعات متداخلة، بحث، وأدوات احترافية.',
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
// TAB 0: HOME
// ═══════════════════════════════════════════════════════════════════

class _HomeTab extends StatefulWidget {
  final int refreshTick;
  final Future<void> Function(Map<String, dynamic>) onOpenFile;
  final void Function(Map<String, dynamic>) onOpenGroup;
  final void Function(Map<String, dynamic>) onOpenFileOptions;
  final void Function(Map<String, dynamic>) onOpenGroupOptions;
  final VoidCallback onRefresh;

  const _HomeTab({
    required this.refreshTick,
    required this.onOpenFile,
    required this.onOpenGroup,
    required this.onOpenFileOptions,
    required this.onOpenGroupOptions,
    required this.onRefresh,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _db = DatabaseService.instance;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  String _sortBy = 'added_at DESC';
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_HomeTab old) {
    super.didUpdateWidget(old);
    if (widget.refreshTick != old.refreshTick) _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final groups = await _db.getGroups(parentId: null);
    final files = _search.isEmpty
        ? await _db.getFiles(sortBy: _sortBy)
        : await _db.searchFiles(_search);
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _files = files;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AppBackground(
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildSearch()),
            SliverToBoxAdapter(child: _buildSortChips()),
            if (_groups.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: Icons.folder_rounded,
                  title: 'المجموعات',
                  color: Colors.amber,
                  trailing: '${_groups.length}',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: _groups.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RepaintBoundary(
                      child: _GroupTile(
                        group: _groups[i],
                        onTap: () => widget.onOpenGroup(_groups[i]),
                        onLongPress: () =>
                            widget.onOpenGroupOptions(_groups[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (_files.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _SectionHeader(
                  icon: Icons.picture_as_pdf_rounded,
                  title: _search.isEmpty ? 'الملفات' : 'نتائج البحث',
                  color: const Color(0xFFEC4899),
                  trailing: '${_files.length}',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: _files.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RepaintBoundary(
                      child: _FileTile(
                        file: _files[i],
                        onTap: () => widget.onOpenFile(_files[i]),
                        onLongPress: () =>
                            widget.onOpenFileOptions(_files[i]),
                      ),
                    ),
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
            if (!_loading && _groups.isEmpty && _files.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyState(
                  icon: Icons.folder_open_rounded,
                  title: _search.isEmpty
                      ? 'لا توجد ملفات بعد'
                      : 'لا توجد نتائج',
                  subtitle: _search.isEmpty
                      ? 'اضغط زر + لإضافة ملف أو مجموعة'
                      : 'جرّب كلمة بحث أخرى',
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
          color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'ابحث عن ملف...',
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
          final primary = Theme.of(context).colorScheme.primary;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFEC4899)])
                  : null,
              color: selected ? null : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: selected
                  ? null
                  : Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.2)),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() => _sortBy = sorts[i].$2);
                  _load();
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Center(
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
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 1: FAVORITES
// ═══════════════════════════════════════════════════════════════════

class _FavoritesTab extends StatefulWidget {
  final int refreshTick;
  final Future<void> Function(Map<String, dynamic>) onOpenFile;
  const _FavoritesTab({required this.refreshTick, required this.onOpenFile});
  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> {
  final _db = DatabaseService.instance;
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_FavoritesTab old) {
    super.didUpdateWidget(old);
    if (widget.refreshTick != old.refreshTick) _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final files = await _db.getFiles(favoritesOnly: true, sortBy: 'added_at DESC');
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AppBackground(
      child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _files.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      _EmptyState(
                        icon: Icons.star_outline_rounded,
                        title: 'لا توجد ملفات مفضلة',
                        subtitle: 'اضغط مطولاً على أي ملف لإضافته للمفضلة',
                        color: Colors.amber,
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: _files.length,
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RepaintBoundary(
                        child: _FileTile(
                          file: _files[i],
                          onTap: () => widget.onOpenFile(_files[i]),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 2: RECENT
// ═══════════════════════════════════════════════════════════════════

class _RecentTab extends StatefulWidget {
  final int refreshTick;
  final Future<void> Function(Map<String, dynamic>) onOpenFile;
  const _RecentTab({required this.refreshTick, required this.onOpenFile});
  @override
  State<_RecentTab> createState() => _RecentTabState();
}

class _RecentTabState extends State<_RecentTab> {
  final _db = DatabaseService.instance;
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_RecentTab old) {
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
  }

  @override
  Widget build(BuildContext context) {
    return _AppBackground(
      child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _files.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      _EmptyState(
                        icon: Icons.history_rounded,
                        title: 'لا يوجد سجل بعد',
                        subtitle: 'افتح أي ملف PDF وسيظهر هنا',
                        color: Color(0xFF06B6D4),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: _files.length,
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RepaintBoundary(
                        child: _FileTile(
                          file: _files[i],
                          onTap: () => widget.onOpenFile(_files[i]),
                          showOpenTime: true,
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 3: TOOLS
// ═══════════════════════════════════════════════════════════════════

class _ToolsTab extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onImagesToPdf;
  final VoidCallback onCameraScan;
  final VoidCallback onBackupFull;
  final VoidCallback onBackupDb;
  final VoidCallback onRestore;

  const _ToolsTab({
    required this.onImport,
    required this.onImagesToPdf,
    required this.onCameraScan,
    required this.onBackupFull,
    required this.onBackupDb,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return _AppBackground(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const _SectionHeader(
            icon: Icons.handyman_rounded,
            title: 'أدوات الملفات',
            color: Color(0xFF7C3AED),
            showTopPadding: false,
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              _ToolCard(
                icon: Icons.upload_file_rounded,
                colors: const [Color(0xFF7C3AED), Color(0xFF6366F1)],
                label: 'استيراد PDF',
                onTap: onImport,
              ),
              _ToolCard(
                icon: Icons.image_rounded,
                colors: const [Color(0xFFEC4899), Color(0xFFEF4444)],
                label: 'صور إلى PDF',
                onTap: onImagesToPdf,
              ),
              _ToolCard(
                icon: Icons.camera_alt_rounded,
                colors: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
                label: 'مسح بالكاميرا',
                onTap: onCameraScan,
              ),
              _ToolCard(
                icon: Icons.backup_rounded,
                colors: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                label: 'نسخة كاملة',
                onTap: onBackupFull,
              ),
              _ToolCard(
                icon: Icons.storage_rounded,
                colors: const [Color(0xFF10B981), Color(0xFF059669)],
                label: 'نسخة الداتابيز',
                onTap: onBackupDb,
              ),
              _ToolCard(
                icon: Icons.restore_rounded,
                colors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                label: 'استعادة',
                onTap: onRestore,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            icon: Icons.hourglass_top_rounded,
            title: 'قريباً',
            color: Colors.grey,
            showTopPadding: false,
          ),
          _ComingSoonItem(icon: Icons.merge_type_rounded, label: 'دمج ملفات PDF'),
          _ComingSoonItem(icon: Icons.content_cut_rounded, label: 'تقسيم PDF'),
          _ComingSoonItem(icon: Icons.text_fields_rounded, label: 'علامة مائية'),
          _ComingSoonItem(icon: Icons.search_rounded, label: 'البحث داخل PDF'),
          _ComingSoonItem(icon: Icons.print_rounded, label: 'طباعة مباشرة'),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final String label;
  final VoidCallback? onTap;
  const _ToolCard({
    required this.icon,
    required this.colors,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ComingSoonItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1B4B).withOpacity(0.5)
              : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: Icon(icon, color: Colors.grey, size: 22),
          title: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'قريباً',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 4: SETTINGS
// ═══════════════════════════════════════════════════════════════════

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _AppBackground(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const _SectionHeader(
            icon: Icons.palette_rounded,
            title: 'المظهر',
            color: Color(0xFFEC4899),
            showTopPadding: false,
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SwitchListTile(
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFFFBBF24), Color(0xFFF97316)]
                        : const [Color(0xFF7C3AED), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: const Text('الوضع الداكن',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(
                tp.isDark ? 'مُفعّل' : 'معطّل',
                style: const TextStyle(fontSize: 12),
              ),
              value: tp.isDark,
              onChanged: (_) => tp.toggleTheme(),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionHeader(
            icon: Icons.info_rounded,
            title: 'معلومات',
            color: Color(0xFF06B6D4),
            showTopPadding: false,
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.apps_rounded, size: 22),
                  title: const Text('اسم التطبيق',
                      style: TextStyle(fontSize: 13)),
                  trailing: const Text('PDF Vault',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const ListTile(
                  leading: Icon(Icons.numbers_rounded, size: 22),
                  title: Text('الإصدار', style: TextStyle(fontSize: 13)),
                  trailing: Text('1.0.0',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.storage_rounded, size: 22),
                  title: const Text('مكان النسخ الاحتياطية',
                      style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                    'Downloads/PdfVault',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionHeader(
            icon: Icons.favorite_rounded,
            title: 'عن التطبيق',
            color: Color(0xFFEF4444),
            showTopPadding: false,
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'PDF Vault',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'مستودعك الشخصي لملفات PDF\nمع مجموعات متداخلة، بحث ذكي، وأدوات احترافية.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _AppBackground extends StatelessWidget {
  final Widget child;
  const _AppBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF0F0F1A), Color(0xFF1A1A2E)]
              : const [Color(0xFFF5F3FF), Color(0xFFFCE7F3)],
        ),
      ),
      child: child,
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _ThemeToggleButton({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFFFBBF24), Color(0xFFF97316)]
                  : const [Color(0xFF7C3AED), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isDark
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF7C3AED))
                    .withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String? trailing;
  final bool showTopPadding;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.trailing,
    this.showTopPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, showTopPadding ? 20 : 0, 16, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                trailing!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _GroupTile({
    required this.group,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.folder_rounded,
                  color: Colors.white, size: 26),
            ),
            title: Text(
              group['name'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: const Text('مجموعة',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: Icon(Icons.chevron_right_rounded,
                color: Colors.grey.withOpacity(0.6)),
          ),
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showOpenTime;

  const _FileTile({
    required this.file,
    required this.onTap,
    this.onLongPress,
    this.showOpenTime = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tagColor = file['tag_color'] != null
        ? Color(file['tag_color'] as int)
        : null;
    final isFav = file['is_favorite'] == 1;
    final when = showOpenTime
        ? file['last_opened_at'] as int?
        : file['added_at'] as int;
    final dateStr = when != null
        ? DateFormat('yyyy/MM/dd').format(
            DateTime.fromMillisecondsSinceEpoch(when))
        : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (tagColor != null) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: tagColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          '${_sizeText(file['size'])} · $dateStr',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                        if (isFav) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 14),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: c.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 50, color: c),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SHEETS
// ═══════════════════════════════════════════════════════════════════

class _AddMenuSheet extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onImages;
  final VoidCallback onCamera;
  final VoidCallback onGroup;

  const _AddMenuSheet({
    required this.onImport,
    required this.onImages,
    required this.onCamera,
    required this.onGroup,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'إضافة جديد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _addOption(Icons.upload_file_rounded,
                  const [Color(0xFF7C3AED), Color(0xFF6366F1)],
                  'استيراد ملف PDF', onImport),
              _addOption(Icons.image_rounded,
                  const [Color(0xFFEC4899), Color(0xFFEF4444)],
                  'صور إلى PDF', onImages),
              _addOption(Icons.camera_alt_rounded,
                  const [Color(0xFFF59E0B), Color(0xFFEF4444)],
                  'مسح بالكاميرا', onCamera),
              _addOption(Icons.create_new_folder_rounded,
                  const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                  'مجموعة جديدة', onGroup),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addOption(
      IconData icon, List<Color> colors, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.grey.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FileOptionsSheet extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onChanged;

  const _FileOptionsSheet({required this.file, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final tools = PdfToolsService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFav = file['is_favorite'] == 1;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded,
                        color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              _opt(
                Icons.star_rounded,
                isFav ? Colors.amber.shade700 : Colors.amber,
                isFav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                () async {
                  await db.toggleFavorite(file['id'], !isFav);
                  if (context.mounted) Navigator.pop(context);
                  onChanged();
                },
              ),
              _opt(Icons.label_rounded, Colors.blue, 'وسم ملون', () async {
                Navigator.pop(context);
                final color = await _pickTagColor(context);
                if (color != null) {
                  await db.updateFile(
                    file['id'],
                    {'tag_color': color.value, 'tag_label': 'وسم'},
                  );
                  onChanged();
                }
              }),
              _opt(Icons.share_rounded, Colors.green, 'مشاركة', () {
                Navigator.pop(context);
                tools.shareFile(file['path'], file['name']);
              }),
              _opt(Icons.qr_code_rounded, Colors.purple, 'عرض QR Code', () {
                Navigator.pop(context);
                _showQr(context, file);
              }),
              _opt(Icons.edit_rounded, Colors.indigo, 'إعادة تسمية', () async {
                Navigator.pop(context);
                await _rename(context, file, onChanged);
              }),
              _opt(Icons.delete_rounded, Colors.red, 'حذف نهائي', () async {
                Navigator.pop(context);
                await _delete(context, file, onChanged);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opt(IconData icon, Color color, String label, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  Future<Color?> _pickTagColor(BuildContext context) {
    const colors = [
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.pink,
    ];
    return showDialog<Color>(
      context: context,
      builder: (_) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('اختر اللون'),
        children: colors
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, c),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: c, shape: BoxShape.circle),
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

  Future<void> _rename(
      BuildContext context, Map<String, dynamic> file, VoidCallback onDone) async {
    final ctrl = TextEditingController(text: file['name']);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('إعادة تسمية'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await DatabaseService.instance
          .updateFile(file['id'], {'name': newName});
      onDone();
    }
  }

  Future<void> _delete(
      BuildContext context, Map<String, dynamic> file, VoidCallback onDone) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('حذف الملف؟'),
        content: const Text('هيتم حذفه من التطبيق والجهاز نهائياً.'),
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
      try {
        await File(file['path']).delete();
      } catch (_) {}
      await DatabaseService.instance.deleteFile(file['id']);
      onDone();
    }
  }

  void _showQr(BuildContext context, Map<String, dynamic> file) {
    final info =
        'File: ${file['name']}\nSize: ${file['size']} bytes\nAdded: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(file['added_at']))}';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(file['name'],
            maxLines: 2, overflow: TextOverflow.ellipsis),
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
              'يحتوي هذا الـ QR على بيانات الملف فقط',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupOptionsSheet extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onChanged;

  const _GroupOptionsSheet({required this.group, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.folder_rounded,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              ListTile(
                dense: true,
                leading: const Icon(Icons.edit_rounded,
                    color: Colors.indigo, size: 22),
                title: const Text('إعادة تسمية',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(context);
                  final ctrl =
                      TextEditingController(text: group['name']);
                  final n = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      title: const Text('إعادة تسمية'),
                      content: TextField(controller: ctrl),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('إلغاء')),
                        FilledButton(
                          onPressed: () =>
                              Navigator.pop(ctx, ctrl.text.trim()),
                          child: const Text('حفظ'),
                        ),
                      ],
                    ),
                  );
                  if (n != null && n.isNotEmpty) {
                    final db = DatabaseService.instance;
                    final raw = await db.database;
                    await raw.update('groups', {'name': n},
                        where: 'id = ?', whereArgs: [group['id']]);
                    onChanged();
                  }
                },
              ),
              ListTile(
                dense: true,
                leading:
                    const Icon(Icons.delete_rounded, color: Colors.red, size: 22),
                title: const Text('حذف المجموعة',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      title: const Text('حذف المجموعة؟'),
                      content: const Text('سيتم حذف كل ما بداخلها.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء')),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await DatabaseService.instance.deleteGroup(group['id']);
                    onChanged();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════

Route _pageRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

String _sizeText(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}