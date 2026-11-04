import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(prefs),
      child: const PdfVaultApp(),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  late bool _isDark;
  ThemeProvider(this._prefs) : _isDark = _prefs.getBool('isDark') ?? false;
  bool get isDark => _isDark;
  void toggleTheme() {
    _isDark = !_isDark;
    _prefs.setBool('isDark', _isDark);
    notifyListeners();
  }
}

class PdfVaultApp extends StatelessWidget {
  const PdfVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'PDF Vault',
      debugShowCheckedModeBanner: false,
      themeMode: tp.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: _light(),
      darkTheme: _dark(),
      home: const HomeScreen(),
    );
  }

  ThemeData _light() {
    const primary = Color(0xFF7C3AED);
    const secondary = Color(0xFFEC4899);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: primary);
          }
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 26);
          }
          return const IconThemeData(size: 24);
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
            color: Colors.black.withOpacity(0.35), fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      dividerTheme: DividerThemeData(
          color: Colors.black.withOpacity(0.06), thickness: 1),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  ThemeData _dark() {
    const primary = Color(0xFFA78BFA);
    const secondary = Color(0xFFF472B6);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: secondary,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: const Color(0xFF1E1B4B),
        indicatorColor: primary.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: primary);
          }
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 26);
          }
          return const IconThemeData(size: 24);
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.35), fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      dividerTheme: DividerThemeData(
          color: Colors.white.withOpacity(0.08), thickness: 1),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}