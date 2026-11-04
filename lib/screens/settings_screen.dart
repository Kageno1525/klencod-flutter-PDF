import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBackground(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const SectionHeader(
            icon: Icons.palette_rounded,
            title: 'المظهر',
            color: Color(0xFFDC2626),
            showTopPadding: false,
          ),
          Container(
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
            child: SwitchListTile(
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFFFBBF24), Color(0xFFF97316)]
                        : const [Color(0xFFDC2626), Color(0xFF2563EB)],
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
          const SectionHeader(
            icon: Icons.info_rounded,
            title: 'معلومات',
            color: Color(0xFF2563EB),
            showTopPadding: false,
          ),
          Container(
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
          const SectionHeader(
            icon: Icons.favorite_rounded,
            title: 'عن التطبيق',
            color: Color(0xFFDC2626),
            showTopPadding: false,
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
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