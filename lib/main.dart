import 'package:ERPForever/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedThemeMode = prefs.getString('themeMode') ?? 'system';
  
  runApp(MyApp(initialThemeMode: savedThemeMode));
}

class MyApp extends StatefulWidget {
  final String initialThemeMode;
  
  const MyApp({super.key, required this.initialThemeMode});

  @override
  State<MyApp> createState() => _MyAppState();
  
  static _MyAppState of(BuildContext context) => 
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;
  
  @override
  void initState() {
    super.initState();
    _themeMode = _getThemeModeFromString(widget.initialThemeMode);
  }
  
  ThemeMode _getThemeModeFromString(String mode) {
    switch (mode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }
  
  Future<void> updateThemeMode(String mode) async {
    final newThemeMode = _getThemeModeFromString(mode);
    setState(() {
      _themeMode = newThemeMode;
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode);
  }

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.tajawalTextTheme();
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ERPForever',
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0078d7)),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          titleTextStyle: GoogleFonts.tajawal(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: baseTextTheme, 
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0078d7),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: GoogleFonts.tajawal(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: baseTextTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        bottomAppBarTheme: const BottomAppBarTheme(
          color: Color(0xFF1E1E1E),
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}