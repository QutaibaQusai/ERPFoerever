// lib/main.dart
import 'package:ERPForever/services/refresh_state_manager.dart';
import 'package:ERPForever/themes/dynamic_theme.dart';
import 'package:ERPForever/widgets/screenshot_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/theme_service.dart';
import 'package:ERPForever/services/auth_service.dart';
import 'package:ERPForever/pages/main_screen.dart';
import 'package:ERPForever/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final configService = ConfigService();
  final themeService = ThemeService();
  final authService = AuthService();
  
  // Load configuration with enhanced logging
  debugPrint('🚀 ERPForever App Starting...');
  debugPrint('📡 Loading configuration from remote source...');
  
  await configService.loadConfig();
  
  // Log configuration source
  final cacheStatus = await configService.getCacheStatus();
  debugPrint('💾 Cache Status: $cacheStatus');
  
  if (configService.config != null) {
    debugPrint('✅ Configuration loaded successfully');
    debugPrint('🔗 Main Icons: ${configService.config!.mainIcons.length}');
    debugPrint('📋 Sheet Icons: ${configService.config!.sheetIcons.length}');
    debugPrint('🌍 Language: ${configService.config!.lang}');
    debugPrint('🌍 Direction: ${configService.config!.theme.direction}');
  } else {
    debugPrint('⚠️ Using fallback configuration');
  }
  
  // Load saved theme
  final savedTheme = await themeService.getSavedThemeMode();
  
  // Check authentication state
  final isLoggedIn = await authService.checkAuthState();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: configService),
        ChangeNotifierProvider(create: (_) => themeService),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(create: (_) => RefreshStateManager()),
      ],
      child: MyApp(
        initialThemeMode: savedTheme,
        isLoggedIn: isLoggedIn,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialThemeMode;
  final bool? isLoggedIn; 
  
  const MyApp({
    super.key, 
    required this.initialThemeMode,
    this.isLoggedIn, 
  });

  @override
  Widget build(BuildContext context) {
    return Consumer3<ConfigService, ThemeService, AuthService>(
      builder: (context, configService, themeService, authService, child) {
        final shouldShowMainScreen = isLoggedIn ?? authService.isLoggedIn;
        
        final textDirection = configService.getTextDirection();

        return Directionality(
          textDirection: textDirection,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'ERPForever',
            themeMode: themeService.themeMode,
            theme: DynamicTheme.buildLightTheme(configService.config),
            darkTheme: DynamicTheme.buildDarkTheme(configService.config),
            home: ScreenshotWrapper(
              child: shouldShowMainScreen ? const MainScreen() : const LoginPage()
            ),
            builder: (context, widget) {
              return Directionality(
                textDirection: textDirection,
                child: widget ?? Container(),
              );
            },
          ),
        );
      },
    );
  }
}