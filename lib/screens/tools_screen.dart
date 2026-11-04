import 'package:flutter/material.dart';
import '../widgets/common.dart';

class ToolsScreen extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onImagesToPdf;
  final VoidCallback onCameraScan;
  final VoidCallback onBackupFull;
  final VoidCallback onBackupDb;
  final VoidCallback onRestore;

  const ToolsScreen({
    super.key,
    required this.onImport,
    required this.onImagesToPdf,
    required this.onCameraScan,
    required this.onBackupFull,
    required this.onBackupDb,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const SectionHeader(
            icon: Icons.handyman_rounded,
            title: 'أدوات الملفات',
            color: Color(0xFFDC2626),
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
                colors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
                label: 'استيراد PDF',
                onTap: onImport,
              ),
              _ToolCard(
                icon: Icons.image_rounded,
                colors: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
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
                colors: const [Color(0xFF06B6D4), Color(0xFF2563EB)],
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
                colors: const [Color(0xFFDC2626), Color(0xFF2563EB)],
                label: 'استعادة',
                onTap: onRestore,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader(
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
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor:
            (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        child: Padding(
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
              ? const Color(0xFF1A1A2E).withOpacity(0.5)
              : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            width: 1,
          ),
        ),
        child: ListTile(
          leading: const Icon(Icons.hourglass_top, color: Colors.grey, size: 22),
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