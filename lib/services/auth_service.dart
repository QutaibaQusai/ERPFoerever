// lib/services/auth_service.dart - Updated with config URL support
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ERPForever/services/config_service.dart';

class AuthService extends ChangeNotifier {
  static const String _isLoggedInKey = 'isLoggedIn';
  
  bool _isLoggedIn = false;
  bool _isLoading = false;
  
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  AuthService() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      
      debugPrint('📱 Auth state loaded: isLoggedIn = $_isLoggedIn');
    } catch (e) {
      debugPrint('❌ Error loading auth state: $e');
      _isLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// NEW: Login with optional config URL from loggedin:// protocol
 // lib/services/auth_service.dart - REPLACE THE login method with this:

/// 🆕 ENHANCED: Login with optional config URL and context support
Future<void> login({String? configUrl, BuildContext? context}) async {
  try {
    debugPrint('🔄 Attempting to save login state...');
    if (configUrl != null) {
      debugPrint('🔗 Login includes config URL: $configUrl');
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    
    _isLoggedIn = true;
    
    // 🆕 ENHANCED: If config URL is provided, parse and set it with context
    if (configUrl != null) {
      await _handleConfigUrl(configUrl, context);
    }
    
    notifyListeners();
    
    debugPrint('✅ User logged in and state saved to SharedPreferences');
  } catch (e) {
    debugPrint('❌ Error saving login state: $e');
    _isLoggedIn = true;
    notifyListeners();
  }
}
Future<void> _handleConfigUrl(String configUrl, [BuildContext? context]) async {
  try {
    debugPrint('🔗 Processing config URL from login: $configUrl');
    
    final parsedData = ConfigService.parseLoginConfigUrl(configUrl);
    
    if (parsedData.isNotEmpty && parsedData.containsKey('configUrl')) {
      final fullConfigUrl = parsedData['configUrl']!;
      final userRole = parsedData['role'];
      
      debugPrint('✅ Setting dynamic config URL: $fullConfigUrl');
      debugPrint('👤 User role: ${userRole ?? 'not specified'}');
      
      // 🆕 ENHANCED: Set the dynamic config URL with context for better app data
      await ConfigService().setDynamicConfigUrl(
        fullConfigUrl,
        role: userRole,
      );
      
      // 🆕 NEW: If context is available, reload config immediately with enhanced data
      if (context != null) {
        debugPrint('🔄 Reloading configuration with login context...');
        await ConfigService().loadConfig(context);
        debugPrint('✅ Configuration reloaded with enhanced app data');
      }
      
      debugPrint('🔄 Configuration updated with new URL and user role');
    } else {
      debugPrint('⚠️ Failed to parse config URL, using default configuration');
    }
  } catch (e) {
    debugPrint('❌ Error handling config URL: $e');
  }
}
  /// Updated logout to clear dynamic config URL
  Future<void> logout() async {
    try {
      debugPrint('🔄 Attempting to clear login state...');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, false);
      
      _isLoggedIn = false;
      
      // NEW: Clear dynamic config URL on logout
      await ConfigService().clearDynamicConfigUrl();
      
      notifyListeners();
      
      debugPrint('✅ User logged out and state cleared from SharedPreferences');
      debugPrint('🧹 Dynamic config URL cleared, will use default');
    } catch (e) {
      debugPrint('❌ Error clearing login state: $e');
      // Even if SharedPreferences fails, we still logout the session
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  Future<bool> checkAuthState() async {
    await _loadAuthState();
    return _isLoggedIn;
  }

  /// NEW: Method to manually set config URL (for testing or special cases)
  Future<void> setUserConfigUrl(String configUrl, {String? role}) async {
    try {
      debugPrint('🔗 Manually setting user config URL: $configUrl');
      
      await ConfigService().setDynamicConfigUrl(configUrl, role: role);
      
      debugPrint('✅ User config URL set successfully');
    } catch (e) {
      debugPrint('❌ Error setting user config URL: $e');
    }
  }

  /// NEW: Get current user's config URL and role
  Map<String, String?> getUserConfigInfo() {
    final configService = ConfigService();
    return {
      'configUrl': configService.currentConfigUrl,
      'role': configService.userRole,
    };
  }
}