// lib/main.dart - Updated with splash screen management
import 'package:ERPForever/services/refresh_state_manager.dart';
import 'package:ERPForever/themes/dynamic_theme.dart';
import 'package:ERPForever/widgets/screenshot_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/theme_service.dart';
import 'package:ERPForever/services/auth_service.dart';
import 'package:ERPForever/pages/main_screen.dart';
import 'package:ERPForever/pages/login_page.dart';

void main() async {
  // Preserve the native splash screen
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Initialize services
  final configService = ConfigService();
  final themeService = ThemeService();
  final authService = AuthService();
  
  // Load configuration
  debugPrint('🚀 ERPForever App Starting...');
  debugPrint('📡 Loading configuration from remote source...');
  
  await configService.loadConfig();
  
  // Log configuration status
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
        // NEW: Add splash state provider
        ChangeNotifierProvider(create: (_) => SplashStateManager()),
      ],
      child: MyApp(
        initialThemeMode: savedTheme,
        isLoggedIn: isLoggedIn,
      ),
    ),
  );
}

// NEW: Splash state manager to coordinate splash removal
class SplashStateManager extends ChangeNotifier {
  bool _isWebViewReady = false;
  bool _isMinTimeElapsed = false;
  bool _isSplashRemoved = false;
  late DateTime _startTime;

  SplashStateManager() {
    _startTime = DateTime.now();
    _startMinTimeTimer();
  }

  bool get isSplashRemoved => _isSplashRemoved;

  void _startMinTimeTimer() {
    Future.delayed(const Duration(seconds: 2), () {
      _isMinTimeElapsed = true;
      debugPrint('⏱️ Minimum 2 seconds elapsed');
      _checkSplashRemoval();
    });
  }

  void setWebViewReady() {
    if (!_isWebViewReady) {
      _isWebViewReady = true;
      debugPrint('🌐 First WebView is ready');
      _checkSplashRemoval();
    }
  }

  void _checkSplashRemoval() {
    if (_isMinTimeElapsed && _isWebViewReady && !_isSplashRemoved) {
      _removeSplash();
    }
  }

  void _removeSplash() {
    _isSplashRemoved = true;
    
    try {
      FlutterNativeSplash.remove();
      debugPrint('✅ Splash screen removed successfully!');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing splash screen: $e');
    }
  }
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
              child: shouldShowMainScreen ? const MainScreen() : const LoginPage(),
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