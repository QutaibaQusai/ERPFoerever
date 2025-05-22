// lib/main.dart
import 'package:ERPForever/themes/dynamic_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/theme_service.dart';
import 'package:ERPForever/pages/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final configService = ConfigService();
  final themeService = ThemeService();
  
  // Load configuration
  await configService.loadConfig();
  
  // Load saved theme
  final savedTheme = await themeService.getSavedThemeMode();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: configService),
        ChangeNotifierProvider(create: (_) => themeService),
      ],
      child: MyApp(initialThemeMode: savedTheme),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialThemeMode;
  
  const MyApp({super.key, required this.initialThemeMode});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConfigService, ThemeService>(
      builder: (context, configService, themeService, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ERPForever',
          themeMode: themeService.themeMode,
          theme: DynamicTheme.buildLightTheme(configService.config),
          darkTheme: DynamicTheme.buildDarkTheme(configService.config),
          home: const MainScreen(),
        );
      },
    );
  }
}