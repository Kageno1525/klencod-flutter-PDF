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

  ThemeProvider(this._prefs) {
    _isDark = _prefs.getBool('isDark') ?? false;
  }

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
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'مستودع PDF',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      darkTheme: _buildDarkTheme(),
      theme: _buildLightTheme(),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildLightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C5CE7),
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C5CE7),
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: const Color(0xFF1A1A2E),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
    );
  }
}