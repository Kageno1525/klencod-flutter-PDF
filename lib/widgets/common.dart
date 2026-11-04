import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/database_service.dart';
import '../services/pdf_tools_service.dart';

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
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

// ═══════════════════════════════════════════════════════════════════
// PARTITION TILE (القسم)
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
                    Text(
                      partition['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
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
// FOLDER TILE (مجلد جوا قسم)
// ═══════════════════════════════════════════════════════════════════

class GroupTile extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const GroupTile({
    super.key,
    required this.group,
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
            ),
            child: const Icon(Icons.folder_rounded,
                color: Colors.white, size: 26),
          ),
          title: Text(
            group['name'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: const Text('مجلد',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
          trailing: Icon(Icons.chevron_right_rounded,
              color: Colors.grey.withOpacity(0.6)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FILE TILE
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
                      colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                    ),
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
                color: c.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 50, color: c),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
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

// ═══════════════════════════════════════════════════════════════════
// FILE OPTIONS SHEET
// ═══════════════════════════════════════════════════════════════════

class FileOptionsSheet extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onChanged;

  const FileOptionsSheet({
    super.key,
    required this.file,
    required this.onChanged,
  });

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
                final color = await pickTagColor(context);
                if (color != null) {
                  await db.updateFile(
                    file['id'],
                    {'tag_color': color.value, 'tag_label': 'وسم'},
                  );
                  onChanged();
                }
              }),
              _opt(Icons.drive_file_move_rounded, Colors.orange,
                  'نقل إلى...', () async {
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
        title: Text(file['name'], maxLines: 2, overflow: TextOverflow.ellipsis),
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

// ═══════════════════════════════════════════════════════════════════
// GROUP OPTIONS SHEET
// ═══════════════════════════════════════════════════════════════════

class GroupOptionsSheet extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onChanged;

  const GroupOptionsSheet({
    super.key,
    required this.group,
    required this.onChanged,
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
                          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                          child: const Text('حفظ'),
                        ),
                      ],
                    ),
                  );
                  if (n != null && n.isNotEmpty) {
                    await DatabaseService.instance.updateGroup(
                        group['id'] as int, n);
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
                    child: Text(
                      file['name'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _row(context, 'الحجم', sizeText(file['size'])),
              _row(
                context,
                'تاريخ الإضافة',
                DateFormat('yyyy/MM/dd HH:mm').format(
                  DateTime.fromMillisecondsSinceEpoch(file['added_at']),
                ),
              ),
              if (file['last_opened_at'] != null)
                _row(
                  context,
                  'آخر فتح',
                  DateFormat('yyyy/MM/dd HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(
                        file['last_opened_at']),
                  ),
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
                            const SnackBar(content: Text('تم نسخ المسار')),
                          );
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
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[isDark ? 400 : 600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PICKERS
// ═══════════════════════════════════════════════════════════════════

/// Returns `-1` for root, `id` for a group, `null` if user cancelled.
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
                child: Text(
                  'لا توجد أقسام بعد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
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
                          title: Text(
                            e.key['name'],
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
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
    await db.updateFile(f['id'] as int,
        {'tag_color': color.value, 'tag_label': 'وسم'});
  }
}

// ═══════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════

Route pageRoute(Widget page) {
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

String sizeText(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}