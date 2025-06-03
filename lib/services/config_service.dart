// lib/services/config_service.dart - Updated with dynamic URL support
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ERPForever/models/app_config_model.dart';
import 'package:ERPForever/models/theme_config_model.dart';
import 'package:ERPForever/models/main_icon_model.dart';

class ConfigService extends ChangeNotifier with WidgetsBindingObserver {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal() {
    // Listen for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  // Configuration URLs
  static const String _defaultRemoteConfigUrl = 'https://mobile.erpforever.com/config';
  static const String _localConfigPath = 'assets/config.json';
  static const String _cacheKey = 'cached_config';
  static const String _cacheTimestampKey = 'config_cache_timestamp';
  static const String _dynamicConfigUrlKey = 'dynamic_config_url'; // NEW: Store dynamic URL
  static const String _userRoleKey = 'user_role'; // NEW: Store user role
  static const Duration _cacheExpiry = Duration(hours: 1);

  AppConfigModel? _config;
  bool _isLoading = false;
  String? _error;
  String? _dynamicConfigUrl; // NEW: Current dynamic config URL
  String? _userRole; // NEW: Current user role

  AppConfigModel? get config => _config;
  bool get isLoading => _isLoading;
  bool get isLoaded => _config != null;
  String? get error => _error;
  String? get currentConfigUrl => _dynamicConfigUrl ?? _defaultRemoteConfigUrl; // NEW: Get current URL
  String? get userRole => _userRole; // NEW: Get user role

  /// NEW: Set dynamic configuration URL from login
  Future<void> setDynamicConfigUrl(String configUrl, {String? role}) async {
    try {
      debugPrint('🔄 Setting dynamic config URL: $configUrl');
      debugPrint('👤 User role: ${role ?? 'not specified'}');

      _dynamicConfigUrl = configUrl;
      _userRole = role;

      // Save to SharedPreferences for persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dynamicConfigUrlKey, configUrl);
      if (role != null) {
        await prefs.setString(_userRoleKey, role);
      }

      debugPrint('✅ Dynamic config URL saved and will be used for next config load');
      
      // Optionally reload config immediately with new URL
      await loadConfig();
      
    } catch (e) {
      debugPrint('❌ Error setting dynamic config URL: $e');
    }
  }

  /// NEW: Load saved dynamic config URL
  Future<void> _loadSavedDynamicConfigUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dynamicConfigUrl = prefs.getString(_dynamicConfigUrlKey);
      _userRole = prefs.getString(_userRoleKey);
      
      if (_dynamicConfigUrl != null) {
        debugPrint('📱 Loaded saved dynamic config URL: $_dynamicConfigUrl');
        debugPrint('👤 Loaded saved user role: $_userRole');
      }
    } catch (e) {
      debugPrint('❌ Error loading saved dynamic config URL: $e');
    }
  }

  /// NEW: Clear dynamic config URL (e.g., on logout)
  Future<void> clearDynamicConfigUrl() async {
    try {
      debugPrint('🧹 Clearing dynamic config URL');
      
      _dynamicConfigUrl = null;
      _userRole = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dynamicConfigUrlKey);
      await prefs.remove(_userRoleKey);
      
      debugPrint('✅ Dynamic config URL cleared, will use default URL');
    } catch (e) {
      debugPrint('❌ Error clearing dynamic config URL: $e');
    }
  }

  /// Main method to load configuration with fallback strategy
  Future<void> loadConfig() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🔄 Starting configuration loading process...');
      
      // NEW: Load saved dynamic URL first
      await _loadSavedDynamicConfigUrl();

      // Strategy 1: Try remote configuration first (using dynamic URL if available)
      bool remoteSuccess = await _tryLoadRemoteConfig();
      
      if (remoteSuccess) {
        debugPrint('✅ Remote configuration loaded successfully');
        await _cacheConfiguration();
        return;
      }

      // Strategy 2: Try cached configuration
      debugPrint('⚠️ Remote failed, trying cached configuration...');
      bool cacheSuccess = await _tryLoadCachedConfig();
      
      if (cacheSuccess) {
        debugPrint('✅ Cached configuration loaded successfully');
        return;
      }

      // Strategy 3: Fallback to local assets
      debugPrint('⚠️ Cache failed, trying local configuration...');
      bool localSuccess = await _tryLoadLocalConfig();
      
      if (localSuccess) {
        debugPrint('✅ Local configuration loaded successfully');
        return;
      }

      // Strategy 4: Use hardcoded default
      debugPrint('⚠️ All sources failed, using default configuration...');
      _loadDefaultConfig();

    } catch (e) {
      _error = 'Failed to load configuration: $e';
      debugPrint('❌ Configuration loading error: $e');
      _loadDefaultConfig();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Try to load configuration from remote URL (UPDATED to use dynamic URL)
  Future<bool> _tryLoadRemoteConfig() async {
    try {
      // Use dynamic URL if available, otherwise use default
      final configUrl = _dynamicConfigUrl ?? _defaultRemoteConfigUrl;
      
      debugPrint('🌐 Fetching remote configuration from: $configUrl');
      debugPrint('👤 User role: ${_userRole ?? 'not specified'}');

      // Build headers with user role if available
      final headers = {
        'User-Agent': 'ERPForever-Flutter-App/1.0',
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
      };
      
      if (_userRole != null) {
        headers['X-User-Role'] = _userRole!;
      }

      final response = await http.get(
        Uri.parse(configUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final String configString = response.body;
        final Map<String, dynamic> configJson = json.decode(configString);
        
        _config = AppConfigModel.fromJson(configJson);
        
        debugPrint('✅ Remote configuration parsed successfully');
        debugPrint('📱 Main Icons: ${_config!.mainIcons.length}');
        debugPrint('📋 Sheet Icons: ${_config!.sheetIcons.length}');
        debugPrint('🌍 Direction: ${_config!.theme.direction}');
        debugPrint('🔗 Config source: ${_dynamicConfigUrl != null ? 'DYNAMIC' : 'DEFAULT'}');
        
        return true;
      } else {
        debugPrint('❌ Remote config HTTP ${response.statusCode}: ${response.reasonPhrase}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Remote configuration error: $e');
      return false;
    }
  }

  /// NEW: Parse config URL from loggedin:// protocol
  static Map<String, String> parseLoginConfigUrl(String loginUrl) {
    try {
      debugPrint('🔍 Parsing login config URL: $loginUrl');
      
      if (!loginUrl.startsWith('loggedin://')) {
        debugPrint('❌ Invalid login URL format');
        return {};
      }
      
      // Remove the protocol
      String cleanUrl = loginUrl.replaceFirst('loggedin://', '');
      
      // Parse the URL parts
      Uri uri = Uri.parse('https://$cleanUrl'); // Add dummy scheme for parsing
      
      // Extract the base config URL
      String configPath = uri.path;
      if (configPath.isEmpty) {
        configPath = '/config.php'; // Default path
      }
      
      // Build the full config URL
      String baseUrl = 'https://mobile.erpforever.com'; // Your base domain
      String fullConfigUrl = '$baseUrl$configPath';
      
      // Add query parameters if they exist
      if (uri.queryParameters.isNotEmpty) {
        fullConfigUrl += '?${uri.query}';
      }
      
      // Extract role from query parameters
      String? role = uri.queryParameters['role'];
      
      debugPrint('✅ Parsed config URL: $fullConfigUrl');
      debugPrint('👤 Extracted role: ${role ?? 'not specified'}');
      
      return {
        'configUrl': fullConfigUrl,
        if (role != null) 'role': role,
      };
      
    } catch (e) {
      debugPrint('❌ Error parsing login config URL: $e');
      return {};
    }
  }

  /// Try to load configuration from cache (keeping existing implementation)
  Future<bool> _tryLoadCachedConfig() async {
    try {
      debugPrint('💾 Checking cached configuration...');

      final prefs = await SharedPreferences.getInstance();
      final cachedConfig = prefs.getString(_cacheKey);
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey);

      if (cachedConfig == null || cacheTimestamp == null) {
        debugPrint('❌ No cached configuration found');
        return false;
      }

      // Check if cache is expired
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
      final isExpired = cacheAge > _cacheExpiry.inMilliseconds;

      if (isExpired) {
        debugPrint('❌ Cached configuration expired (${Duration(milliseconds: cacheAge).inHours}h old)');
        return false;
      }

      final Map<String, dynamic> configJson = json.decode(cachedConfig);
      _config = AppConfigModel.fromJson(configJson);

      debugPrint('✅ Cached configuration loaded (${Duration(milliseconds: cacheAge).inMinutes}m old)');
      debugPrint('📱 Main Icons: ${_config!.mainIcons.length}');
      debugPrint('📋 Sheet Icons: ${_config!.sheetIcons.length}');

      return true;
    } catch (e) {
      debugPrint('❌ Cached configuration error: $e');
      return false;
    }
  }

  /// Try to load configuration from local assets (keeping existing implementation)
  Future<bool> _tryLoadLocalConfig() async {
    try {
      debugPrint('📱 Loading local configuration from assets...');

      final String configString = await rootBundle.loadString(_localConfigPath);
      final Map<String, dynamic> configJson = json.decode(configString);
      
      _config = AppConfigModel.fromJson(configJson);
      
      debugPrint('✅ Local configuration loaded successfully');
      debugPrint('📱 Main Icons: ${_config!.mainIcons.length}');
      debugPrint('📋 Sheet Icons: ${_config!.sheetIcons.length}');
      
      return true;
    } catch (e) {
      debugPrint('❌ Local configuration error: $e');
      return false;
    }
  }

  /// Cache the current configuration (keeping existing implementation)
  Future<void> _cacheConfiguration() async {
    try {
      if (_config == null) return;

      debugPrint('💾 Caching configuration...');

      final prefs = await SharedPreferences.getInstance();
      final configJson = json.encode(_config!.toJson());
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await prefs.setString(_cacheKey, configJson);
      await prefs.setInt(_cacheTimestampKey, timestamp);

      debugPrint('✅ Configuration cached successfully');
    } catch (e) {
      debugPrint('❌ Configuration caching error: $e');
    }
  }

  /// Force reload configuration (keeping existing implementation but updated)
  Future<void> reloadConfig({bool bypassCache = false}) async {
    if (bypassCache) {
      await _clearCache();
    }
    await loadConfig();
  }

  /// Clear cached configuration (keeping existing implementation)
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      debugPrint('🗑️ Configuration cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Force remote configuration reload (keeping existing implementation but updated)
  Future<bool> forceRemoteReload() async {
    debugPrint('🔄 Force reloading from remote...');
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      bool success = await _tryLoadRemoteConfig();
      if (success) {
        await _cacheConfiguration();
        debugPrint('✅ Force remote reload successful');
      } else {
        _error = 'Failed to load remote configuration';
        debugPrint('❌ Force remote reload failed');
      }
      return success;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update configuration at runtime (keeping existing implementation)
  void updateConfig(AppConfigModel newConfig) {
    _config = newConfig;
    notifyListeners();
    debugPrint('🔄 Configuration updated at runtime');
    
    // Cache the updated configuration
    _cacheConfiguration();
  }

  /// Get cache status (keeping existing implementation)
  Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey);
      
      if (cacheTimestamp == null) {
        return {
          'hasCachedConfig': false,
          'cacheAge': 0,
          'isExpired': true,
        };
      }

      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
      final isExpired = cacheAge > _cacheExpiry.inMilliseconds;

      return {
        'hasCachedConfig': true,
        'cacheAge': cacheAge,
        'cacheAgeHours': (cacheAge / (1000 * 60 * 60)).round(),
        'isExpired': isExpired,
        'cacheTimestamp': DateTime.fromMillisecondsSinceEpoch(cacheTimestamp).toIso8601String(),
      };
    } catch (e) {
      return {
        'hasCachedConfig': false,
        'error': e.toString(),
      };
    }
  }

  /// Load default configuration as fallback (keeping existing implementation)
  void _loadDefaultConfig() {
    _config = AppConfigModel(
      lang: 'en', // NEW: Default language
      theme: ThemeConfigModel(
        primaryColor: '#0078d7',
        lightBackground: '#F5F5F5',
        darkBackground: '#121212',
        darkSurface: '#1E1E1E',
        defaultMode: 'system',
        direction: 'LTR',
      ),
      mainIcons: [
        MainIconModel(
          title: 'Home',
          iconLine: 'https://cdn-icons-png.flaticon.com/128/1946/1946488.png',
          iconSolid: 'https://cdn-icons-png.flaticon.com/128/1946/1946436.png',
          link: 'https://mobile.erpforever.com/',
          linkType: 'regular_webview',
        ),
      ],
      sheetIcons: [],
    );
    debugPrint('⚠️ Using default configuration as fallback');
  }

  // Keep all existing helper methods...
  Color getColorFromHex(String hexColor) {
    return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  }

  ThemeMode getThemeMode() {
    if (_config == null) return ThemeMode.system;
    
    switch (_config!.theme.defaultMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  TextDirection getTextDirection() {
    if (_config == null) return TextDirection.ltr;
    return _config!.theme.textDirection;
  }

  bool isRTL() {
    if (_config == null) return false;
    return _config!.theme.isRTL;
  }

  MainIconModel? getMainIcon(int index) {
    if (_config == null || index >= _config!.mainIcons.length) return null;
    return _config!.mainIcons[index];
  }

  bool hasHeaderIcons(int index) {
    final mainIcon = getMainIcon(index);
    return mainIcon?.headerIcons != null && mainIcon!.headerIcons!.isNotEmpty;
  }

  /// Handle app lifecycle changes (keeping existing implementation)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed - checking for config updates...');
      _checkForConfigUpdates();
    }
  }

  /// Check for config updates when app resumes (keeping existing implementation)
  Future<void> _checkForConfigUpdates() async {
    try {
      // Only check if we have a cached config and it's been more than 5 minutes
      final cacheStatus = await getCacheStatus();
      if (cacheStatus['hasCachedConfig'] == true) {
        final cacheAgeMinutes = (cacheStatus['cacheAge'] as int) / (1000 * 60);
        
        if (cacheAgeMinutes > 5) { // Check every 5 minutes when app resumes
          debugPrint('🔄 Cache is ${cacheAgeMinutes.round()} minutes old, checking for updates...');
          
          // Try to get remote config without updating UI state
          final success = await _tryLoadRemoteConfig();
          if (success) {
            await _cacheConfiguration();
            debugPrint('✅ Configuration updated from remote');
            notifyListeners(); // Notify widgets of the update
          }
        } else {
          debugPrint('⏩ Cache is fresh (${cacheAgeMinutes.round()} minutes old), skipping update');
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking for config updates: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}