// lib/services/auth_service.dart - UPDATED: Enhanced role processing
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

  /// 🆕 ENHANCED: Login with config URL and role preservation
  Future<void> login({String? configUrl, BuildContext? context}) async {
    try {
      debugPrint('🔄 Processing login with enhanced role preservation...');
      if (configUrl != null) {
        debugPrint('🔗 Login includes config URL: $configUrl');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      
      _isLoggedIn = true;
      
      // 🆕 ENHANCED: Process config URL with role preservation
      if (configUrl != null) {
        await _handleConfigUrlWithRolePreservation(configUrl, context);
      }
      
      notifyListeners();
      
      debugPrint('✅ User logged in with role preservation completed');
    } catch (e) {
      debugPrint('❌ Error during enhanced login: $e');
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  /// 🆕 ENHANCED: Handle config URL with proper role preservation
  Future<void> _handleConfigUrlWithRolePreservation(String configUrl, [BuildContext? context]) async {
    try {
      debugPrint('🔗 Processing config URL with role preservation: $configUrl');
      
      final parsedData = ConfigService.parseLoginConfigUrl(configUrl);
      
      if (parsedData.isNotEmpty && parsedData.containsKey('configUrl')) {
        final fullConfigUrl = parsedData['configUrl']!;
        final userRole = parsedData['role'];
        
        debugPrint('✅ Setting dynamic config URL: $fullConfigUrl');
        debugPrint('👤 User role extracted: ${userRole ?? 'not specified'}');
        
        // 🆕 ENHANCED: Set the dynamic config URL with role
        await ConfigService().setDynamicConfigUrl(
          fullConfigUrl,
          role: userRole,
        );
        
        // 🆕 CRITICAL: Reload config immediately to process URLs with role
        if (context != null) {
          debugPrint('🔄 Reloading configuration with role processing...');
          await ConfigService().loadConfig(context);
          debugPrint('✅ Configuration reloaded with user role applied to URLs');
        } else {
          debugPrint('⚠️ No context provided, role will be applied on next config load');
        }
        
        debugPrint('🎉 Login with role preservation completed successfully');
      } else {
        debugPrint('⚠️ Failed to parse config URL, using default configuration');
      }
    } catch (e) {
      debugPrint('❌ Error handling config URL with role preservation: $e');
    }
  }

  /// Updated logout to clear dynamic config URL and role
  Future<void> logout() async {
    try {
      debugPrint('🔄 Attempting to clear login state and user role...');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, false);
      
      _isLoggedIn = false;
      
      // Clear dynamic config URL and role on logout
      await ConfigService().clearDynamicConfigUrl();
      
      notifyListeners();
      
      debugPrint('✅ User logged out, state cleared, and role removed from URLs');
    } catch (e) {
      debugPrint('❌ Error clearing login state: $e');
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  Future<bool> checkAuthState() async {
    await _loadAuthState();
    return _isLoggedIn;
  }

  /// Method to manually set config URL (for testing or special cases)
  Future<void> setUserConfigUrl(String configUrl, {String? role}) async {
    try {
      debugPrint('🔗 Manually setting user config URL with role: $configUrl');
      
      await ConfigService().setDynamicConfigUrl(configUrl, role: role);
      
      debugPrint('✅ User config URL and role set successfully');
    } catch (e) {
      debugPrint('❌ Error setting user config URL: $e');
    }
  }

  /// Get current user's config URL and role
  Map<String, String?> getUserConfigInfo() {
    final configService = ConfigService();
    return {
      'configUrl': configService.currentConfigUrl,
      'role': configService.userRole,
    };
  }
}