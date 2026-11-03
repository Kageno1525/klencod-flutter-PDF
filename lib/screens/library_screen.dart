import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../service/database_service.dart';
import '../service/import_service.dart';
import 'pdf_viewer_screen.dart';

final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier(ThemeMode.light);

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<PdfDoc> _docs = [];
  Map<String, int> _stats = {'count': 0, 'pages': 0, 'size': 0};
  bool _loading = true;
  bool _importing = false;
  bool _isGrid = false;
  String _query = '';
  SortOption _sort = SortOption.date;
  FilterOption _filter = FilterOption.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_docs.isEmpty) setState(() => _loading = true);
    final docs = await DatabaseService.instance
        .getAll(search: _query, sort: _sort, filter: _filter);
    final stats = await DatabaseService.instance.getStats();
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _stats = stats;
      _loading = false;
    });
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _query = v;
      _load();
    });
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final n = await ImportService.pickAndImport();
      if (!mounted) return;
      if (n > 0) {
        _toast('✓ تم استيراد $n ملف بنجاح', success: true);
        await _load();
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _open(PdfDoc doc) async {
    await DatabaseService.instance.markOpened(doc.id!);
    if (!mounted) return;
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PdfViewerScreen(doc: doc),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(
              CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
    await _load();
  }

  Future<void> _toggleFav(PdfDoc doc) async {
    await DatabaseService.instance.toggleFavorite(doc.id!, !doc.isFavorite);
    await _load();
  }

  Future<void> _delete(PdfDoc doc) async {
    final ok = await _confirm('حذف "${doc.title}"؟', 'لا يمكن التراجع');
    if (ok != true) return;
    await DatabaseService.instance.delete(doc.id!);
    if (doc.thumbPath != null) {
      try {
        await File(doc.thumbPath!).delete();
      } catch (_) {}
    }
    await _load();
    _toast('تم الحذف');
  }

  Future<bool?> _confirm(String title, String sub) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(sub),
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
  }

  void _toast(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          if (success)
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
          if (success) const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? Colors.green.shade700 : null,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toggleTheme() async {
    final isDark = themeModeNotifier.value == ThemeMode.dark;
    themeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', !isDark);
  }

  void _showContextMenu(PdfDoc doc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ListTile(
              leading: Icon(
                  doc.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: Colors.amber),
              title:
                  Text(doc.isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة'),
              onTap: () {
                Navigator.pop(context);
                _toggleFav(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('فتح'),
              onTap: () {
                Navigator.pop(context);
                _open(doc);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _delete(doc);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4)),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('ترتيب حسب',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final s in SortOption.values)
              RadioListTile<SortOption>(
                value: s,
                groupValue: _sort,
                title: Text(_sortLabel(s)),
                onChanged: (v) {
                  Navigator.pop(context);
                  if (v != null) {
                    setState(() => _sort = v);
                    _load();
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _sortLabel(SortOption s) {
    switch (s) {
      case SortOption.date:
        return 'التاريخ (الأحدث)';
      case SortOption.name:
        return 'الاسم (أ-ي)';
      case SortOption.size:
        return 'الحجم (الأكبر)';
      case SortOption.recent:
        return 'آخر قراءة';
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024)
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _relDate(int ts) {
    final d =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (d.inDays >= 30) {
      return DateFormat('d MMM yyyy')
          .format(DateTime.fromMillisecondsSinceEpoch(ts));
    }
    if (d.inDays > 0) return 'منذ ${d.inDays} يوم';
    if (d.inHours > 0) return 'منذ ${d.inHours} ساعة';
    if (d.inMinutes > 0) return 'منذ ${d.inMinutes} دقيقة';
    return 'الآن';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.value == ThemeMode.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildStats(),
            _buildFilters(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeader(bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مستودعي',
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800, letterSpacing: -0.8)),
              Text('${_stats['count']} ملف في المكتبة',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const Spacer(),
          _CircleIconButton(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            onTap: _toggleTheme,
          ),
          const SizedBox(width: 4),
          _CircleIconButton(
            icon:
                _isGrid ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
            onTap: () => setState(() => _isGrid = !_isGrid),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.55),
              theme.colorScheme.tertiaryContainer.withOpacity(0.35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            _statItem(Icons.description_rounded, '${_stats['count']}', 'ملف'),
            _divider(),
            _statItem(Icons.menu_book_rounded, '${_stats['pages']}', 'صفحة'),
            _divider(),
            _statItem(Icons.storage_rounded, _fmtSize(_stats['size'] ?? 0),
                'حجم'),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _statItem(IconData icon, String value, String label) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(value,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: Theme.of(context).dividerColor.withOpacity(0.3),
      );

  Widget _buildFilters() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'ابحث عن ملف...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        _query = '';
                        _load();
                      },
                    ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withOpacity(0.6),
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(FilterOption.all, 'الكل',
                          Icons.library_books_rounded),
                      const SizedBox(width: 8),
                      _filterChip(FilterOption.favorites, 'المفضلة',
                          Icons.star_rounded),
                      const SizedBox(width: 8),
                      _filterChip(FilterOption.recent, 'حديثة',
                          Icons.access_time_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showSortMenu,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.sort_rounded,
                        size: 20, color: theme.colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(FilterOption f, String label, IconData icon) {
    final theme = Theme.of(context);
    final selected = _filter == f;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = f);
        _load();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return _buildShimmer();
    if (_docs.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      onRefresh: _load,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey('$_isGrid-$_filter-${_docs.length}'),
          child: _isGrid ? _buildGrid() : _buildList(),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded,
                    size: 88,
                    color: theme.colorScheme.primary.withOpacity(0.7))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(
                    begin: -8,
                    end: 8,
                    duration: 1600.ms,
                    curve: Curves.easeInOut),
            const SizedBox(height: 20),
            Text('المكتبة فاضية',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700))
                .animate()
                .fadeIn(delay: 200.ms)
                .slideY(begin: 0.3),
            const SizedBox(height: 8),
            Text('ابدأ باستيراد ملفات PDF',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant))
                .animate()
                .fadeIn(delay: 350.ms),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _importing ? null : _import,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة ملف'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.62,
      ),
      itemCount: _docs.length,
      itemBuilder: (_, i) => _GridCard(
        doc: _docs[i],
        index: i,
        onTap: () => _open(_docs[i]),
        onFav: () => _toggleFav(_docs[i]),
        onLong: () => _showContextMenu(_docs[i]),
        relDate: _relDate(_docs[i].addedAt),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: _docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final doc = _docs[i];
        return Dismissible(
          key: ValueKey(doc.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) =>
              _confirm('حذف "${doc.title}"؟', 'لا يمكن التراجع'),
          onDismissed: (_) async {
            await DatabaseService.instance.delete(doc.id!);
            if (doc.thumbPath != null) {
              try {
                await File(doc.thumbPath!).delete();
              } catch (_) {}
            }
            await _load();
            _toast('تم الحذف');
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          child: _ListCard(
            doc: doc,
            index: i,
            onTap: () => _open(doc),
            onFav: () => _toggleFav(doc),
            onLong: () => _showContextMenu(doc),
            relDate: _relDate(doc.addedAt),
            fmtSize: _fmtSize(doc.fileSize),
          ),
        );
      },
    );
  }

  Widget _buildFab() {
    final theme = Theme.of(context);
    return FloatingActionButton.extended(
      onPressed: _importing ? null : _import,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: _importing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.add_rounded),
      label: Text(_importing ? 'جاري...' : 'إضافة PDF',
          style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color:
          theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => RotationTransition(
              turns: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Icon(icon,
                key: ValueKey(icon),
                size: 20,
                color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

class _PdfThumb extends StatelessWidget {
  final PdfDoc doc;
  final double? width;
  final double? height;
  const _PdfThumb({required this.doc, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (doc.thumbPath != null && File(doc.thumbPath!).existsSync()) {
      return Image.file(
        File(doc.thumbPath!),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(theme),
      );
    }
    return _fallback(theme);
  }

  Widget _fallback(ThemeData theme) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.errorContainer.withOpacity(0.65),
            theme.colorScheme.errorContainer.withOpacity(0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.picture_as_pdf_rounded,
            color: theme.colorScheme.error, size: (width ?? 40) * 0.45),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerRight,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  final PdfDoc doc;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onFav;
  final VoidCallback onLong;
  final String relDate;
  const _GridCard({
    required this.doc,
    required this.index,
    required this.onTap,
    required this.onFav,
    required this.onLong,
    required this.relDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        doc.pageCount > 0 ? doc.lastPage / doc.pageCount : 0.0;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLong,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PdfThumb(doc: doc),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _FavButton(isFav: doc.isFavorite, onTap: onFav),
                  ),
                  if (progress > 0)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: _ProgressBar(value: progress),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${doc.pageCount} صفحة · $relDate',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 40).ms, duration: 350.ms)
        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
  }
}

class _ListCard extends StatelessWidget {
  final PdfDoc doc;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onFav;
  final VoidCallback onLong;
  final String relDate;
  final String fmtSize;
  const _ListCard({
    required this.doc,
    required this.index,
    required this.onTap,
    required this.onFav,
    required this.onLong,
    required this.relDate,
    required this.fmtSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        doc.pageCount > 0 ? doc.lastPage / doc.pageCount : 0.0;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLong,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 72,
                  child: _PdfThumb(doc: doc, width: 56, height: 72),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      '${doc.pageCount} صفحة · $fmtSize · $relDate',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11),
                    ),
                    if (progress > 0) ...[
                      const SizedBox(height: 6),
                      _ProgressBar(value: progress),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _FavButton(isFav: doc.isFavorite, onTap: onFav, mini: true),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 30).ms, duration: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }
}

class _FavButton extends StatelessWidget {
  final bool isFav;
  final VoidCallback onTap;
  final bool mini;
  const _FavButton(
      {required this.isFav, required this.onTap, this.mini = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: mini ? Colors.transparent : Colors.black.withOpacity(0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(mini ? 6 : 6),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: child,
            ),
            child: Icon(
              isFav ? Icons.star_rounded : Icons.star_border_rounded,
              key: ValueKey(isFav),
              color: isFav
                  ? Colors.amber
                  : (mini
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Colors.white),
              size: mini ? 22 : 20,
            ),
          ),
        ),
      ),
    );
  }
}