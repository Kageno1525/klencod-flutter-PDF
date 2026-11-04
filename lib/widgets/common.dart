import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/pdf_tools_service.dart';

// ═══════════════════════════════════════════════════════════════════
// GLOBAL STATE
// ═══════════════════════════════════════════════════════════════════

final ValueNotifier<int> selectedTabNotifier = ValueNotifier<int>(0);

enum ViewMode { gridSmall, gridLarge, listCompact, listDetailed }

final ValueNotifier<ViewMode> viewModeNotifier =
    ValueNotifier<ViewMode>(ViewMode.gridSmall);

Future<void> loadViewMode() async {
  try {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('viewMode');
    if (s != null) {
      viewModeNotifier.value = ViewMode.values.firstWhere(
        (v) => v.name == s,
        orElse: () => ViewMode.gridSmall,
      );
    }
  } catch (_) {}
}

void setViewMode(ViewMode mode) {
  viewModeNotifier.value = mode;
  SharedPreferences.getInstance().then((p) => p.setString('viewMode', mode.name));
}

bool isGridMode(ViewMode m) =>
    m == ViewMode.gridSmall || m == ViewMode.gridLarge;

SliverGridDelegateWithMaxCrossAxisExtent gridDelegateForMode(ViewMode mode) {
  switch (mode) {
    case ViewMode.gridSmall:
      return const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      );
    case ViewMode.gridLarge:
      return const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      );
    default:
      return const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
      );
  }
}

// ═══════════════════════════════════════════════════════════════════
// APP BACKGROUND
// ═══════════════════════════════════════════════════════════════════

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

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
              : const [Color(0xFFFEF2F2), Color(0xFFEFF6FF)],
        ),
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// THEME TOGGLE
// ═══════════════════════════════════════════════════════════════════

class ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const ThemeToggleButton({super.key, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.2),
        highlightColor: Colors.transparent,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFFFBBF24), Color(0xFFF97316)]
                  : const [Color(0xFFDC2626), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
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

// ═══════════════════════════════════════════════════════════════════
// VIEW MODE TOGGLE
// ═══════════════════════════════════════════════════════════════════

class ViewModeToggle extends StatelessWidget {
  const ViewModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.grid_view_rounded, size: 22),
      tooltip: 'شكل العرض',
      onPressed: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ValueListenableBuilder<ViewMode>(
        valueListenable: viewModeNotifier,
        builder: (ctx, current, __) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('شكل العرض',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    _opt(ctx, ViewMode.gridSmall, Icons.grid_view_rounded,
                        'شبكة صغيرة', current),
                    _opt(ctx, ViewMode.gridLarge, Icons.apps_rounded,
                        'شبكة كبيرة', current),
                    _opt(ctx, ViewMode.listCompact, Icons.view_list_rounded,
                        'قائمة', current),
                    _opt(ctx, ViewMode.listDetailed, Icons.view_agenda_rounded,
                        'قائمة مفصلة', current),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _opt(BuildContext ctx, ViewMode mode, IconData icon, String label,
      ViewMode current) {
    final selected = mode == current;
    final primary = Theme.of(ctx).colorScheme.primary;
    return ListTile(
      leading: Icon(icon, color: selected ? primary : null),
      title: Text(label,
          style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      trailing: selected
          ? Icon(Icons.check_rounded, color: primary, size: 20)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: selected,
      selectedTileColor: primary.withOpacity(0.08),
      onTap: () {
        setViewMode(mode);
        Navigator.pop(ctx);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MAIN BOTTOM BAR
// ═══════════════════════════════════════════════════════════════════

class MainBottomBar extends StatelessWidget {
  final int currentTab;
  const MainBottomBar({super.key, required this.currentTab});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            selectedIndex: currentTab,
            onDestinationSelected: (i) {
              final nav = Navigator.of(context);
              if (nav.canPop()) nav.popUntil((r) => r.isFirst);
              if (i != currentTab) selectedTabNotifier.value = i;
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.picture_as_pdf_outlined),
                selectedIcon: Icon(Icons.picture_as_pdf_rounded),
                label: 'الملفات',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_books_outlined),
                selectedIcon: Icon(Icons.library_books_rounded),
                label: 'المجموعات',
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════════

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String? trailing;
  final bool showTopPadding;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    this.trailing,
    this.showTopPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, showTopPadding ? 20 : 0, 16, 12),
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
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(trailing!,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FILE GRID ITEM
// ═══════════════════════════════════════════════════════════════════

class FileGridItem extends StatefulWidget {
  final Map<String, dynamic> file;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool inSelectionMode;

  const FileGridItem({
    super.key,
    required this.file,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.inSelectionMode = false,
  });

  @override
  State<FileGridItem> createState() => _FileGridItemState();
}

class _FileGridItemState extends State<FileGridItem> {
  File? _thumb;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FileGridItem old) {
    super.didUpdateWidget(old);
    if (old.file['path'] != widget.file['path']) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final t = await PdfToolsService.instance
        .getThumbnail(widget.file['path'] as String);
    if (mounted) {
      setState(() {
        _thumb = t;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final isFav = widget.file['is_favorite'] == 1;
    final tagColor = widget.file['tag_color'] != null
        ? Color(widget.file['tag_color'] as int)
        : null;

    return Material(
      color: widget.isSelected
          ? primary.withOpacity(0.1)
          : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: widget.isSelected
                ? Border.all(color: primary, width: 2)
                : Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.05),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                      child: _loading
                          ? Container(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              ),
                            )
                          : _thumb != null
                              ? Image.file(
                                  _thumb!,
                                  fit: BoxFit.cover,
                                  cacheWidth: 400,
                                  errorBuilder: (_, __, ___) => _placeholder(),
                                )
                              : _placeholder(),
                    ),
                    if (widget.isSelected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white),
                        ),
                      )
                    else if (isFav)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star_rounded,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    if (tagColor != null)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: tagColor,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.file['name'],
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.25),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sizeText(widget.file['size'] as int),
                      style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFDC2626).withOpacity(0.25),
            const Color(0xFF2563EB).withOpacity(0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.picture_as_pdf_rounded,
            size: 40, color: Color(0xFFDC2626)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FILE DETAIL TILE (large list row)
// ═══════════════════════════════════════════════════════════════════

class FileDetailTile extends StatefulWidget {
  final Map<String, dynamic> file;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool inSelectionMode;

  const FileDetailTile({
    super.key,
    required this.file,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.inSelectionMode = false,
  });

  @override
  State<FileDetailTile> createState() => _FileDetailTileState();
}

class _FileDetailTileState extends State<FileDetailTile> {
  File? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await PdfToolsService.instance
        .getThumbnail(widget.file['path'] as String);
    if (mounted) setState(() => _thumb = t);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final isFav = widget.file['is_favorite'] == 1;
    final tagColor = widget.file['tag_color'] != null
        ? Color(widget.file['tag_color'] as int)
        : null;
    final date = DateFormat('yyyy/MM/dd').format(
        DateTime.fromMillisecondsSinceEpoch(widget.file['added_at'] as int));

    return Material(
      color: widget.isSelected
          ? primary.withOpacity(0.1)
          : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: widget.isSelected
                ? Border.all(color: primary, width: 2)
                : null,
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (widget.inSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    widget.isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: widget.isSelected ? primary : Colors.grey,
                    size: 24,
                  ),
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 60,
                  height: 80,
                  child: _thumb != null
                      ? Image.file(_thumb!,
                          fit: BoxFit.cover, cacheWidth: 200)
                      : Container(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05),
                          child: const Center(
                            child: Icon(Icons.picture_as_pdf_rounded,
                                color: Color(0xFFDC2626), size: 30),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.file['name'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
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
                        Text(sizeText(widget.file['size'] as int),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600])),
                        const SizedBox(width: 8),
                        Text('·',
                            style: TextStyle(color: Colors.grey[400])),
                        const SizedBox(width: 8),
                        Text(date,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600])),
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
              if (!widget.inSelectionMode)
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FOLDER GRID ITEM
// ═══════════════════════════════════════════════════════════════════

class FolderGridItem extends StatelessWidget {
  final Map<String, dynamic> folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int? filesCount;
  final int? foldersCount;
  final bool isPartition;

  const FolderGridItem({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
    this.filesCount,
    this.foldersCount,
    this.isPartition = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isPartition
                        ? const LinearGradient(
                            colors: [Color(0xFFDC2626), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                  ),
                  child: Center(
                    child: Icon(
                      isPartition
                          ? Icons.library_books_rounded
                          : Icons.folder_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      folder['name'],
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.25),
                    ),
                    if (filesCount != null || foldersCount != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${foldersCount ?? 0} 📁 · ${filesCount ?? 0} 📄',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FILE TILE (compact list row)
// ═══════════════════════════════════════════════════════════════════

class FileTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showOpenTime;
  final bool isSelected;
  final bool inSelectionMode;

  const FileTile({
    super.key,
    required this.file,
    required this.onTap,
    this.onLongPress,
    this.showOpenTime = false,
    this.isSelected = false,
    this.inSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final tagColor =
        file['tag_color'] != null ? Color(file['tag_color'] as int) : null;
    final isFav = file['is_favorite'] == 1;
    final when =
        showOpenTime ? file['last_opened_at'] as int? : file['added_at'] as int;
    final dateStr = when != null
        ? DateFormat('yyyy/MM/dd')
            .format(DateTime.fromMillisecondsSinceEpoch(when))
        : '';

    return Material(
      color: isSelected
          ? primary.withOpacity(0.08)
          : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: Colors.transparent,
        highlightColor:
            (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border:
                isSelected ? Border.all(color: primary, width: 1.5) : null,
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (inSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? primary : Colors.grey,
                    size: 24,
                  ),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      color: Colors.white, size: 24),
                ),
              if (inSelectionMode) const SizedBox(width: 4),
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
                        Flexible(
                          child: Text(
                            '${sizeText(file['size'])} · $dateStr',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
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
              if (!inSelectionMode)
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PARTITION TILE (list row for folder/partition)
// ═══════════════════════════════════════════════════════════════════

class PartitionTile extends StatelessWidget {
  final Map<String, dynamic> partition;
  final int foldersCount;
  final int filesCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const PartitionTile({
    super.key,
    required this.partition,
    required this.foldersCount,
    required this.filesCount,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: Colors.transparent,
        highlightColor:
            (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.library_books_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(partition['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.folder_rounded,
                            size: 13, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('$foldersCount مجلد',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        const SizedBox(width: 10),
                        Icon(Icons.picture_as_pdf_rounded,
                            size: 13, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('$filesCount ملف',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
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

// ═══════════════════════════════════════════════════════════════════
// MODE HELPERS
// ═══════════════════════════════════════════════════════════════════

Widget fileTileForMode({
  required BuildContext context,
  required Map<String, dynamic> file,
  required ViewMode mode,
  required VoidCallback onTap,
  VoidCallback? onLongPress,
  bool isSelected = false,
  bool inSelectionMode = false,
  bool showOpenTime = false,
}) {
  if (mode == ViewMode.listDetailed) {
    return FileDetailTile(
        file: file,
        onTap: onTap,
        onLongPress: onLongPress,
        isSelected: isSelected,
        inSelectionMode: inSelectionMode);
  }
  if (mode == ViewMode.listCompact) {
    return FileTile(
        file: file,
        onTap: onTap,
        onLongPress: onLongPress,
        isSelected: isSelected,
        inSelectionMode: inSelectionMode,
        showOpenTime: showOpenTime);
  }
  return FileGridItem(
      file: file,
      onTap: onTap,
      onLongPress: onLongPress,
      isSelected: isSelected,
      inSelectionMode: inSelectionMode);
}

Widget folderTileForMode({
  required BuildContext context,
  required Map<String, dynamic> folder,
  required ViewMode mode,
  required VoidCallback onTap,
  VoidCallback? onLongPress,
  int? filesCount,
  int? foldersCount,
  bool isPartition = false,
}) {
  if (isGridMode(mode)) {
    return FolderGridItem(
      folder: folder,
      onTap: onTap,
      onLongPress: onLongPress,
      filesCount: filesCount,
      foldersCount: foldersCount,
      isPartition: isPartition,
    );
  }
  return PartitionTile(
    partition: folder,
    foldersCount: foldersCount ?? 0,
    filesCount: filesCount ?? 0,
    onTap: onTap,
    onLongPress: onLongPress,
  );
}

Widget filesSliver({
  required List<Map<String, dynamic>> files,
  required ViewMode mode,
  required Map<int, Map<String, dynamic>> selectedFiles,
  required bool inSelectionMode,
  required void Function(Map<String, dynamic>) onTap,
  void Function(Map<String, dynamic>)? onLongPress,
  bool showOpenTime = false,
}) {
  if (isGridMode(mode)) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: gridDelegateForMode(mode),
        delegate: SliverChildBuilderDelegate(
          (c, i) {
            final f = files[i];
            return RepaintBoundary(
              child: fileTileForMode(
                context: c,
                file: f,
                mode: mode,
                onTap: () => onTap(f),
                onLongPress:
                    onLongPress != null ? () => onLongPress(f) : null,
                isSelected: selectedFiles.containsKey(f['id']),
                inSelectionMode: inSelectionMode,
                showOpenTime: showOpenTime,
              ),
            );
          },
          childCount: files.length,
        ),
      ),
    );
  }
  return SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    sliver: SliverList.builder(
      itemCount: files.length,
      itemBuilder: (c, i) {
        final f = files[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RepaintBoundary(
            child: fileTileForMode(
              context: c,
              file: f,
              mode: mode,
              onTap: () => onTap(f),
              onLongPress: onLongPress != null ? () => onLongPress(f) : null,
              isSelected: selectedFiles.containsKey(f['id']),
              inSelectionMode: inSelectionMode,
              showOpenTime: showOpenTime,
            ),
          ),
        );
      },
    ),
  );
}

Widget buildFilesBox({
  required List<Map<String, dynamic>> files,
  required ViewMode mode,
  required Map<int, Map<String, dynamic>> selectedFiles,
  required bool inSelectionMode,
  required void Function(Map<String, dynamic>) onTap,
  void Function(Map<String, dynamic>)? onLongPress,
  bool showOpenTime = false,
}) {
  if (isGridMode(mode)) {
    return GridView.builder(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 120),
      gridDelegate: gridDelegateForMode(mode),
      itemCount: files.length,
      itemBuilder: (c, i) {
        final f = files[i];
        return RepaintBoundary(
          child: fileTileForMode(
            context: c,
            file: f,
            mode: mode,
            onTap: () => onTap(f),
            onLongPress: onLongPress != null ? () => onLongPress(f) : null,
            isSelected: selectedFiles.containsKey(f['id']),
            inSelectionMode: inSelectionMode,
            showOpenTime: showOpenTime,
          ),
        );
      },
    );
  }
  return ListView.builder(
    physics:
        const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
    padding: const EdgeInsets.fromLTRB(12, 16, 12, 120),
    itemCount: files.length,
    itemBuilder: (c, i) {
      final f = files[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RepaintBoundary(
          child: fileTileForMode(
            context: c,
            file: f,
            mode: mode,
            onTap: () => onTap(f),
            onLongPress: onLongPress != null ? () => onLongPress(f) : null,
            isSelected: selectedFiles.containsKey(f['id']),
            inSelectionMode: inSelectionMode,
            showOpenTime: showOpenTime,
          ),
        ),
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;

  const EmptyState({
    super.key,
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
                  color: c.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 50, color: c),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ADD MENU SHEET
// ═══════════════════════════════════════════════════════════════════

class AddMenuSheet extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onImages;
  final VoidCallback onCamera;
  final VoidCallback onGroup;

  const AddMenuSheet({
    super.key,
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
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
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
              const Text('إضافة جديد',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _opt(Icons.upload_file_rounded,
                  const [Color(0xFFDC2626), Color(0xFFEF4444)],
                  'استيراد ملف PDF', onImport),
              _opt(Icons.image_rounded,
                  const [Color(0xFF2563EB), Color(0xFF3B82F6)],
                  'صور إلى PDF', onImages),
              _opt(Icons.camera_alt_rounded,
                  const [Color(0xFFF59E0B), Color(0xFFEF4444)],
                  'مسح بالكاميرا', onCamera),
              _opt(Icons.library_books_rounded,
                  const [Color(0xFFDC2626), Color(0xFF2563EB)],
                  'قسم جديد', onGroup),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opt(
      IconData icon, List<Color> colors, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.black.withOpacity(0.04),
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
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold))),
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

// ═══════════════════════════════════════════════════════════════════
// FILE OPTIONS SHEET
// ═══════════════════════════════════════════════════════════════════

class FileOptionsSheet extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onChanged;

  const FileOptionsSheet(
      {super.key, required this.file, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final tools = PdfToolsService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFav = file['is_favorite'] == 1;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
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
                        color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(file['name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
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
                final color = await pickTagColor(context);
                if (color != null) {
                  await db.updateFile(file['id'],
                      {'tag_color': color.value, 'tag_label': 'وسم'});
                  onChanged();
                }
              }),
              _opt(Icons.drive_file_move_rounded, Colors.orange, 'نقل إلى...',
                  () async {
                Navigator.pop(context);
                final target = await pickGroup(context, title: 'نقل إلى...');
                if (target == null) return;
                final gid = target == -1 ? null : target;
                await db.moveFile(file['id'], gid);
                onChanged();
              }),
              _opt(Icons.info_rounded, Colors.teal, 'بيانات الملف', () {
                Navigator.pop(context);
                showFileInfo(context, file);
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

  Future<void> _rename(BuildContext context, Map<String, dynamic> file,
      VoidCallback onDone) async {
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
              child: const Text('حفظ')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await DatabaseService.instance
          .updateFile(file['id'], {'name': newName});
      onDone();
    }
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> file,
      VoidCallback onDone) async {
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
            const Text('يحتوي هذا الـ QR على بيانات الملف فقط',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// GROUP OPTIONS SHEET
// ═══════════════════════════════════════════════════════════════════

class GroupOptionsSheet extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onChanged;

  const GroupOptionsSheet(
      {super.key, required this.group, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
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
                      child: Text(group['name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
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
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(context);
                  final ctrl = TextEditingController(text: group['name']);
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
                            child: const Text('حفظ')),
                      ],
                    ),
                  );
                  if (n != null && n.isNotEmpty) {
                    await DatabaseService.instance
                        .updateGroup(group['id'] as int, n);
                    onChanged();
                  }
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_rounded,
                    color: Colors.red, size: 22),
                title: const Text('حذف',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      title: const Text('حذف؟'),
                      content: const Text('سيتم حذف كل ما بداخله.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء')),
                        FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('حذف')),
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
// FILE INFO SHEET
// ═══════════════════════════════════════════════════════════════════

void showFileInfo(BuildContext context, Map<String, dynamic> file) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => FileInfoSheet(file: file),
  );
}

class FileInfoSheet extends StatelessWidget {
  final Map<String, dynamic> file;
  const FileInfoSheet({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final db = DatabaseService.instance;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(file['name'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _row(context, 'الحجم', sizeText(file['size'])),
              _row(
                context,
                'تاريخ الإضافة',
                DateFormat('yyyy/MM/dd HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(file['added_at'])),
              ),
              if (file['last_opened_at'] != null)
                _row(
                  context,
                  'آخر فتح',
                  DateFormat('yyyy/MM/dd HH:mm').format(
                      DateTime.fromMillisecondsSinceEpoch(
                          file['last_opened_at'])),
                ),
              if (file['tag_color'] != null)
                _row(context, 'الوسم', file['tag_label'] ?? 'وسم ملون',
                    color: Color(file['tag_color'])),
              FutureBuilder<Map<String, dynamic>?>(
                future: file['group_id'] != null
                    ? db.getGroupById(file['group_id'] as int)
                    : Future.value(null),
                builder: (ctx, snap) {
                  final groupName = snap.data?['name'] ??
                      (file['group_id'] == null ? 'غير محدد' : '...');
                  return _row(context, 'المجلد', groupName);
                },
              ),
              const Divider(height: 20),
              _row(context, 'المسار', file['path'], wrap: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: file['path']));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('تم نسخ المسار')));
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('نسخ المسار'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('تم'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool wrap = false, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment:
            wrap ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (color != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[isDark ? 400 : 600],
                )),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PICKERS
// ═══════════════════════════════════════════════════════════════════

Future<int?> pickGroup(BuildContext context,
    {String? title, bool showRoot = true}) async {
  final db = DatabaseService.instance;
  final all = await db.getAllGroups();

  final children = <int?, List<Map<String, dynamic>>>{};
  for (final g in all) {
    final p = g['parent_id'] as int?;
    children.putIfAbsent(p, () => []).add(g);
  }
  final flat = <MapEntry<Map<String, dynamic>, int>>[];
  void walk(int? parent, int depth) {
    final list = children[parent] ?? [];
    list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    for (final g in list) {
      flat.add(MapEntry(g, depth));
      walk(g['id'] as int, depth + 1);
    }
  }
  walk(null, 0);

  if (!context.mounted) return null;
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title ?? 'اختر المكان'),
      content: SizedBox(
        width: double.maxFinite,
        child: flat.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد أقسام بعد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              )
            : ListView(
                shrinkWrap: true,
                children: flat
                    .map((e) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.only(
                              left: 12.0 + e.value * 20.0, right: 12),
                          leading: Icon(
                            e.value == 0
                                ? Icons.library_books_rounded
                                : Icons.folder_rounded,
                            color: e.value == 0 ? Colors.red : Colors.amber,
                            size: 20,
                          ),
                          title: Text(e.key['name'],
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          onTap: () =>
                              Navigator.pop(ctx, e.key['id'] as int),
                        ))
                    .toList(),
              ),
      ),
      actions: [
        if (showRoot)
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, -1),
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('بدون مجلد'),
          ),
        TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('إلغاء')),
      ],
    ),
  );
}

Future<Color?> pickTagColor(BuildContext context) async {
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
                      decoration:
                          BoxDecoration(color: c, shape: BoxShape.circle),
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

// ═══════════════════════════════════════════════════════════════════
// BATCH HELPERS
// ═══════════════════════════════════════════════════════════════════

Future<void> batchDelete(List<Map<String, dynamic>> files) async {
  final db = DatabaseService.instance;
  for (final f in files) {
    try {
      await File(f['path']).delete();
    } catch (_) {}
    await db.deleteFile(f['id'] as int);
  }
}

Future<void> batchFavorite(
    List<Map<String, dynamic>> files, bool isFav) async {
  final db = DatabaseService.instance;
  for (final f in files) {
    await db.toggleFavorite(f['id'] as int, isFav);
  }
}

Future<void> batchMove(
    List<Map<String, dynamic>> files, int? groupId) async {
  final db = DatabaseService.instance;
  for (final f in files) {
    await db.moveFile(f['id'] as int, groupId);
  }
}

Future<void> batchTag(List<Map<String, dynamic>> files, Color color) async {
  final db = DatabaseService.instance;
  for (final f in files) {
    await db.updateFile(
        f['id'] as int, {'tag_color': color.value, 'tag_label': 'وسم'});
  }
}

Future<void> batchShare(List<Map<String, dynamic>> files) async {
  if (files.isEmpty) return;
  final xfiles = files
      .map((f) => XFile(f['path'] as String, name: f['name'] as String))
      .toList();
  await Share.shareXFiles(
    xfiles,
    subject: files.length == 1
        ? files.first['name'] as String
        : '${files.length} ملفات PDF',
  );
}

// ═══════════════════════════════════════════════════════════════════
// SAVE PDF DIALOG
// ═══════════════════════════════════════════════════════════════════

class SavePdfResult {
  final String name;
  final int? groupId;
  const SavePdfResult({required this.name, this.groupId});
}

Future<SavePdfResult?> showSavePdfDialog(
  BuildContext context, {
  String defaultName = '',
  int? defaultGroupId,
}) async {
  final nameCtrl = TextEditingController(text: defaultName);
  int? groupId = defaultGroupId;

  return showDialog<SavePdfResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        final db = DatabaseService.instance;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.save_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('حفظ ملف PDF'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'اسم الملف',
                  hintText: 'مثال: تقرير_2024',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.picture_as_pdf_rounded),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final target = await pickGroup(ctx,
                      title: 'اختر المجلد', showRoot: true);
                  if (target != null) {
                    setState(() => groupId = target == -1 ? null : target);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_rounded,
                          color: Colors.amber, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FutureBuilder<Map<String, dynamic>?>(
                          future: groupId != null
                              ? db.getGroupById(groupId!)
                              : Future.value(null),
                          builder: (c, snap) {
                            final name = groupId == null
                                ? 'بدون مجلد'
                                : (snap.data?['name'] ?? '...');
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('المجلد',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                Text(name,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                              ],
                            );
                          },
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('اكتب اسم للملف')),
                  );
                  return;
                }
                Navigator.pop(ctx,
                    SavePdfResult(name: name, groupId: groupId));
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('حفظ'),
            ),
          ],
        );
      },
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════

Route<T> pageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
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

String sizeText(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}