// lib/services/auth_service.dart - FIXED: Enhanced role processing and persistence
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
      
      // 🆕 FIXED: Load and validate stored config URL and role
      if (_isLoggedIn) {
        await _validateStoredConfig();
      }
    } catch (e) {
      debugPrint('❌ Error loading auth state: $e');
      _isLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 🆕 FIXED: Validate that stored config and role are still valid
  Future<void> _validateStoredConfig() async {
    try {
      final configService = ConfigService();
      
      // Check if we have a stored dynamic config URL and role
      final prefs = await SharedPreferences.getInstance();
      final storedConfigUrl = prefs.getString('dynamic_config_url');
      final storedRole = prefs.getString('user_role');
      
      if (storedConfigUrl != null) {
        debugPrint('✅ Found stored config URL: $storedConfigUrl');
        debugPrint('👤 Found stored role: ${storedRole ?? 'none'}');
        
        // Force reload config with stored role to ensure URLs are processed
        if (storedRole != null && storedRole.isNotEmpty) {
          debugPrint('🔄 Reprocessing config with stored role...');
          await configService.loadConfig();
        }
      } else {
        debugPrint('⚠️ No stored config URL found, user may need to re-login');
      }
    } catch (e) {
      debugPrint('❌ Error validating stored config: $e');
    }
  }

  /// 🆕 ENHANCED: Login with comprehensive config URL and role preservation
  Future<void> login({String? configUrl, BuildContext? context}) async {
    try {
      debugPrint('🔄 Processing login with enhanced role preservation...');
      if (configUrl != null) {
        debugPrint('🔗 Login includes config URL: $configUrl');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      
      _isLoggedIn = true;
      
      if (configUrl != null) {
        await _handleConfigUrlWithEnhancedRolePreservation(configUrl, context);
      }
      
      notifyListeners();
      
      debugPrint('✅ User logged in with enhanced role preservation completed');
    } catch (e) {
      debugPrint('❌ Error during enhanced login: $e');
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  Future<void> _handleConfigUrlWithEnhancedRolePreservation(String configUrl, [BuildContext? context]) async {
    try {
      debugPrint('🔗 Processing config URL with enhanced role preservation: $configUrl');
      
      final parsedData = ConfigService.parseLoginConfigUrl(configUrl);
      
      if (parsedData.isNotEmpty && parsedData.containsKey('configUrl')) {
        final fullConfigUrl = parsedData['configUrl']!;
        final userRole = parsedData['role'];
        
        debugPrint('✅ Extracted config URL: $fullConfigUrl');
        debugPrint('👤 Extracted user role: ${userRole ?? 'not specified'}');
        
        // 🆕 CRITICAL: Validate role before proceeding
        if (userRole == null || userRole.trim().isEmpty) {
          debugPrint('⚠️ Warning: No role found in login URL, empty user-role parameters will remain empty');
        } else {
          debugPrint('✅ Valid role found: ${userRole.trim()}');
        }
        
        await ConfigService().setDynamicConfigUrl(
          fullConfigUrl,
          role: userRole?.trim(),
        );
        
        if (context != null) {
          debugPrint('🔄 Immediately reloading configuration with role processing...');
          await ConfigService().loadConfig(context);
          
          await _validateRoleApplication(userRole?.trim());
          
          debugPrint('✅ Configuration reloaded with user role applied to all URLs');
        } else {
          debugPrint('⚠️ No context provided, role will be applied on next config load');
        }
        
        debugPrint('🎉 Login with comprehensive role preservation completed successfully');
      } else {
        debugPrint('⚠️ Failed to parse config URL, using default configuration');
      }
    } catch (e) {
      debugPrint('❌ Error handling config URL with enhanced role preservation: $e');
    }
  }

  Future<void> _validateRoleApplication(String? expectedRole) async {
    try {
      if (expectedRole == null || expectedRole.isEmpty) {
        debugPrint('⚠️ No role to validate');
        return;
      }

      final config = ConfigService().config;
      if (config == null) {
        debugPrint('❌ No config available for role validation');
        return;
      }

      debugPrint('🔍 Validating role application in URLs...');

      // Check main icons
      for (int i = 0; i < config.mainIcons.length; i++) {
        final mainIcon = config.mainIcons[i];
        if (mainIcon.link.contains('user-role=')) {
          final uri = Uri.parse(mainIcon.link);
          final roleInUrl = uri.queryParameters['user-role'];
          
          if (roleInUrl == expectedRole) {
            debugPrint('✅ Main icon $i (${mainIcon.title}): Role correctly applied ($roleInUrl)');
          } else if (roleInUrl == null || roleInUrl.isEmpty) {
            debugPrint('❌ Main icon $i (${mainIcon.title}): Role NOT applied - user-role is empty');
          } else {
            debugPrint('⚠️ Main icon $i (${mainIcon.title}): Different role found ($roleInUrl vs $expectedRole)');
          }
        } else {
          debugPrint('ℹ️ Main icon $i (${mainIcon.title}): No user-role parameter in URL');
        }
      }

      // Check sheet icons
      for (int i = 0; i < config.sheetIcons.length; i++) {
        final sheetIcon = config.sheetIcons[i];
        if (sheetIcon.link.contains('user-role=')) {
          final uri = Uri.parse(sheetIcon.link);
          final roleInUrl = uri.queryParameters['user-role'];
          
          if (roleInUrl == expectedRole) {
            debugPrint('✅ Sheet icon $i (${sheetIcon.title}): Role correctly applied ($roleInUrl)');
          } else if (roleInUrl == null || roleInUrl.isEmpty) {
            debugPrint('❌ Sheet icon $i (${sheetIcon.title}): Role NOT applied - user-role is empty');
          } else {
            debugPrint('⚠️ Sheet icon $i (${sheetIcon.title}): Different role found ($roleInUrl vs $expectedRole)');
          }
        }
      }

      debugPrint('✅ Role validation completed');
    } catch (e) {
      debugPrint('❌ Error during role validation: $e');
    }
  }

  /// Updated logout to clear dynamic config URL and role
  Future<void> logout() async {
    try {
      debugPrint('🔄 Attempting to clear login state, user role, and stored config...');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, false);
      
      _isLoggedIn = false;
      
      await ConfigService().clearDynamicConfigUrl();
      
      notifyListeners();
      
      debugPrint('✅ User logged out, state cleared, role removed, and config reset');
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

  Future<void> setUserConfigUrl(String configUrl, {String? role}) async {
    try {
      debugPrint('🔗 Manually setting user config URL with role: $configUrl');
      debugPrint('👤 Role: ${role ?? 'not specified'}');
      
      await ConfigService().setDynamicConfigUrl(configUrl, role: role?.trim());
      
      if (role != null && role.trim().isNotEmpty) {
        await _validateRoleApplication(role.trim());
      }
      
      debugPrint('✅ User config URL and role set successfully');
    } catch (e) {
      debugPrint('❌ Error setting user config URL: $e');
    }
  }

  Map<String, String?> getUserConfigInfo() {
    final configService = ConfigService();
    final info = {
      'configUrl': configService.currentConfigUrl,
      'role': configService.userRole,
    };
    
    debugPrint('📋 Current user config info:');
    debugPrint('   Config URL: ${info['configUrl']}');
    debugPrint('   User Role: ${info['role'] ?? 'none'}');
    
    return info;
  }

  Future<void> refreshConfigWithStoredRole([BuildContext? context]) async {
    try {
      debugPrint('🔄 Refreshing config with stored role...');
      
      final configService = ConfigService();
      final currentRole = configService.userRole;
      
      if (currentRole != null && currentRole.isNotEmpty) {
        debugPrint('👤 Using stored role: $currentRole');
        await configService.loadConfig(context);
        await _validateRoleApplication(currentRole);
        debugPrint('✅ Config refreshed with stored role applied');
      } else {
        debugPrint('⚠️ No stored role found, loading config without role processing');
        await configService.loadConfig(context);
      }
      
    } catch (e) {
      debugPrint('❌ Error refreshing config with stored role: $e');
    }
  }

  bool hasValidRoleConfiguration() {
    final configService = ConfigService();
    final hasRole = configService.userRole != null && configService.userRole!.isNotEmpty;
    final hasConfig = configService.config != null;
    
    debugPrint('🔍 Role configuration status:');
    debugPrint('   Has role: $hasRole (${configService.userRole ?? 'none'})');
    debugPrint('   Has config: $hasConfig');
    
    return hasRole && hasConfig;
  }
}