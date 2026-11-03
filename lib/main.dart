import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDark') ?? false;
  themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'PDF Vault',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _light(),
          darkTheme: _dark(),
          home: const LibraryScreen(),
        );
      },
    );
  }

  ThemeData _light() {
    final s = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
    return ThemeData(
      colorScheme: s,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F5FB),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF7F5FB),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: s.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  ThemeData _dark() {
    final s = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: s,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF121016),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF121016),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: s.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}