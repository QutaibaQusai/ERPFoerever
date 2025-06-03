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
  Future<void> login({String? configUrl}) async {
    try {
      debugPrint('🔄 Attempting to save login state...');
      if (configUrl != null) {
        debugPrint('🔗 Login includes config URL: $configUrl');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      
      _isLoggedIn = true;
      
      // NEW: If config URL is provided, parse and set it in ConfigService
      if (configUrl != null) {
        await _handleConfigUrl(configUrl);
      }
      
      notifyListeners();
      
      debugPrint('✅ User logged in and state saved to SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error saving login state: $e');
      // Even if SharedPreferences fails, we can still proceed with the session
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  /// NEW: Handle config URL from loggedin:// protocol
  Future<void> _handleConfigUrl(String configUrl) async {
    try {
      debugPrint('🔗 Processing config URL from login: $configUrl');
      
      // Parse the config URL
      final parsedData = ConfigService.parseLoginConfigUrl(configUrl);
      
      if (parsedData.isNotEmpty && parsedData.containsKey('configUrl')) {
        final fullConfigUrl = parsedData['configUrl']!;
        final userRole = parsedData['role'];
        
        debugPrint('✅ Setting dynamic config URL: $fullConfigUrl');
        debugPrint('👤 User role: ${userRole ?? 'not specified'}');
        
        // Set the dynamic config URL in ConfigService
        await ConfigService().setDynamicConfigUrl(
          fullConfigUrl,
          role: userRole,
        );
        
        debugPrint('🔄 Configuration will be reloaded with new URL');
      } else {
        debugPrint('⚠️ Failed to parse config URL, using default configuration');
      }
    } catch (e) {
      debugPrint('❌ Error handling config URL: $e');
      // Don't fail login if config URL processing fails
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