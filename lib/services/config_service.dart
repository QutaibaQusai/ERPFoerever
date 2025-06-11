// lib/services/config_service.dart - COMPLETE REWRITE with User Role Processing
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ERPForever/models/app_config_model.dart';
import 'package:ERPForever/models/theme_config_model.dart';
import 'package:ERPForever/models/main_icon_model.dart';
import 'package:ERPForever/models/header_icon_model.dart';
import 'package:ERPForever/models/sheet_icon_model.dart';
import 'package:ERPForever/services/app_data_service.dart';

class ConfigService extends ChangeNotifier with WidgetsBindingObserver {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  // Configuration URLs
  static const String _defaultRemoteConfigUrl =
      'https://mobile.erpforever.com/config';
  static const String _localConfigPath = 'assets/config.json';
  static const String _cacheKey = 'cached_config';
  static const String _cacheTimestampKey = 'config_cache_timestamp';
  static const String _dynamicConfigUrlKey = 'dynamic_config_url';
  static const String _userRoleKey = 'user_role';
  static const Duration _cacheExpiry = Duration(hours: 1);

  AppConfigModel? _config;
  bool _isLoading = false;
  String? _error;
  String? _dynamicConfigUrl;
  String? _userRole;

  AppConfigModel? get config => _config;
  bool get isLoading => _isLoading;
  bool get isLoaded => _config != null;
  String? get error => _error;
  String? get currentConfigUrl => _dynamicConfigUrl ?? _defaultRemoteConfigUrl;
  String? get userRole => _userRole;

  /// 🆕 NEW: Process URLs in config to replace empty user-role with actual role
  AppConfigModel _processConfigWithUserRole(
    AppConfigModel config,
    String? userRole,
  ) {
    if (userRole == null || userRole.isEmpty) {
      debugPrint('⚠️ No user role to apply to config URLs');
      return config;
    }

    debugPrint(
      '🔄 Processing config URLs to replace empty user-role with: $userRole',
    );

    try {
      // Process main icons
      final updatedMainIcons =
          config.mainIcons.map((icon) {
            final updatedLink = _replaceEmptyUserRole(icon.link, userRole);

            // Process header icons if they exist
            List<HeaderIconModel>? updatedHeaderIcons;
            if (icon.headerIcons != null) {
              updatedHeaderIcons =
                  icon.headerIcons!.map((headerIcon) {
                    return HeaderIconModel(
                      title: headerIcon.title,
                      icon: headerIcon.icon,
                      link: _replaceEmptyUserRole(headerIcon.link, userRole),
                      linkType: headerIcon.linkType,
                    );
                  }).toList();
            }

            return MainIconModel(
              title: icon.title,
              iconLine: icon.iconLine,
              iconSolid: icon.iconSolid,
              link: updatedLink,
              linkType: icon.linkType,
              headerIcons: updatedHeaderIcons,
            );
          }).toList();

      // Process sheet icons
      final updatedSheetIcons =
          config.sheetIcons.map((icon) {
            final updatedLink = _replaceEmptyUserRole(icon.link, userRole);

            // Process header icons if they exist
            List<HeaderIconModel>? updatedHeaderIcons;
            if (icon.headerIcons != null) {
              updatedHeaderIcons =
                  icon.headerIcons!.map((headerIcon) {
                    return HeaderIconModel(
                      title: headerIcon.title,
                      icon: headerIcon.icon,
                      link: _replaceEmptyUserRole(headerIcon.link, userRole),
                      linkType: headerIcon.linkType,
                    );
                  }).toList();
            }

            return SheetIconModel(
              title: icon.title,
              iconLine: icon.iconLine,
              iconSolid: icon.iconSolid,
              link: updatedLink,
              linkType: icon.linkType,
              headerIcons: updatedHeaderIcons,
            );
          }).toList();

      final updatedConfig = AppConfigModel(
        lang: config.lang,
        theme: config.theme,
        mainIcons: updatedMainIcons,
        sheetIcons: updatedSheetIcons,
      );

      debugPrint('✅ Config URLs processed successfully with user role');
      return updatedConfig;
    } catch (e) {
      debugPrint('❌ Error processing config with user role: $e');
      return config; // Return original config on error
    }
  }

  /// Helper method to replace empty user-role parameter in URLs
  String _replaceEmptyUserRole(String url, String userRole) {
    try {
      // Check if URL contains user-role parameter
      if (!url.contains('user-role=')) {
        return url; // No user-role parameter, return as-is
      }

      // Parse the URL
      final uri = Uri.parse(url);
      final queryParams = Map<String, String>.from(uri.queryParameters);

      // Check if user-role exists and is empty
      if (queryParams.containsKey('user-role')) {
        final currentRole = queryParams['user-role'] ?? '';

        if (currentRole.isEmpty) {
          // Replace empty user-role with actual role
          queryParams['user-role'] = userRole;

          // Rebuild URL with updated parameters
          final updatedUri = uri.replace(queryParameters: queryParams);
          final updatedUrl = updatedUri.toString();

          debugPrint('🔄 Updated URL: $url → $updatedUrl');
          return updatedUrl;
        } else {
          debugPrint(
            'ℹ️ URL already has user-role: $currentRole, keeping as-is',
          );
          return url; // Already has a role, keep it
        }
      }

      return url; // No user-role parameter found
    } catch (e) {
      debugPrint('❌ Error processing URL $url: $e');
      return url; // Return original URL on error
    }
  }

  /// Set dynamic configuration URL from login
  Future<void> setDynamicConfigUrl(String configUrl, {String? role}) async {
    try {
      debugPrint('🔄 Setting dynamic config URL: $configUrl');
      debugPrint('👤 User role: ${role ?? 'not specified'}');

      _dynamicConfigUrl = configUrl;
      _userRole = role;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dynamicConfigUrlKey, configUrl);
      if (role != null) {
        await prefs.setString(_userRoleKey, role);
      }

      debugPrint('✅ Dynamic config URL and role saved');

      // 🆕 NEW: Reload config and process URLs with user role
      await loadConfig();
    } catch (e) {
      debugPrint('❌ Error setting dynamic config URL: $e');
    }
  }

  /// Load saved dynamic config URL
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

  /// Clear dynamic config URL (e.g., on logout)
  Future<void> clearDynamicConfigUrl() async {
    try {
      debugPrint('🧹 Clearing dynamic config URL and user role');

      _dynamicConfigUrl = null;
      _userRole = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dynamicConfigUrlKey);
      await prefs.remove(_userRoleKey);

      debugPrint('✅ Dynamic config URL and user role cleared');
    } catch (e) {
      debugPrint('❌ Error clearing dynamic config URL: $e');
    }
  }

  /// 🆕 ENHANCED: Main method to load configuration with user role processing
  Future<void> loadConfig([BuildContext? context]) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🔄 Starting configuration loading process...');

      await _loadSavedDynamicConfigUrl();

      // Strategy 1: Try remote configuration first
      bool remoteSuccess = await _tryLoadRemoteConfig(context);

      if (remoteSuccess) {
        debugPrint('✅ Remote configuration loaded successfully');

        // 🆕 NEW: Process config with user role after loading
        if (_config != null && _userRole != null) {
          debugPrint('🔄 Processing config with user role: $_userRole');
          _config = _processConfigWithUserRole(_config!, _userRole);
        }

        await _cacheConfiguration();
        return;
      }

      // Strategy 2: Try cached configuration
      debugPrint('⚠️ Remote failed, trying cached configuration...');
      bool cacheSuccess = await _tryLoadCachedConfig();

      if (cacheSuccess) {
        debugPrint('✅ Cached configuration loaded successfully');

        // 🆕 NEW: Process cached config with user role
        if (_config != null && _userRole != null) {
          debugPrint('🔄 Processing cached config with user role: $_userRole');
          _config = _processConfigWithUserRole(_config!, _userRole);
        }

        return;
      }

      // Strategy 3: Fallback to local assets
      debugPrint('⚠️ Cache failed, trying local configuration...');
      bool localSuccess = await _tryLoadLocalConfig();

      if (localSuccess) {
        debugPrint('✅ Local configuration loaded successfully');

        // 🆕 NEW: Process local config with user role
        if (_config != null && _userRole != null) {
          debugPrint('🔄 Processing local config with user role: $_userRole');
          _config = _processConfigWithUserRole(_config!, _userRole);
        }

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

  /// 🆕 ENHANCED: Try to load configuration from remote URL with app data parameters
  Future<bool> _tryLoadRemoteConfig([BuildContext? context]) async {
    try {
      // Use dynamic URL if available, otherwise use default
      String baseConfigUrl = _dynamicConfigUrl ?? _defaultRemoteConfigUrl;

      debugPrint(
        '🌐 Preparing to fetch remote configuration from: $baseConfigUrl',
      );
      debugPrint('👤 User role: ${_userRole ?? 'not specified'}');

      // 🆕 NEW: Collect app data and build enhanced URL
      final appData = await AppDataService().collectDataForServer(context);

      // Add user role to app data if available
      if (_userRole != null) {
        appData['user-role'] = _userRole!;
        debugPrint('👤 Added user-role to app data: $_userRole');
      }

      // Build enhanced URL with all app data parameters
      final enhancedConfigUrl = _buildEnhancedConfigUrl(baseConfigUrl, appData);

      debugPrint('🔗 Enhanced config URL: $enhancedConfigUrl');

      // Build headers with app data
      final headers = _buildAppDataHeaders(appData, context);

      final response = await http
          .get(Uri.parse(enhancedConfigUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final String configString = response.body;
        final Map<String, dynamic> configJson = json.decode(configString);

        _config = AppConfigModel.fromJson(configJson);

        debugPrint('✅ Remote configuration parsed successfully');
        debugPrint('📱 Main Icons: ${_config!.mainIcons.length}');
        debugPrint('📋 Sheet Icons: ${_config!.sheetIcons.length}');
        debugPrint('🌍 Direction: ${_config!.theme.direction}');
        debugPrint(
          '🔗 Config source: ${_dynamicConfigUrl != null ? 'DYNAMIC' : 'DEFAULT'}',
        );
        debugPrint('📊 App data sent: ${appData.length} parameters');

        return true;
      } else {
        debugPrint(
          '❌ Remote config HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ Remote configuration error: $e');
      return false;
    }
  }

  /// 🆕 NEW: Build enhanced config URL with app data parameters
  String _buildEnhancedConfigUrl(String baseUrl, Map<String, String> appData) {
    try {
      final uri = Uri.parse(baseUrl);
      final originalParams = Map<String, String>.from(uri.queryParameters);

      debugPrint(
        '📋 Original config URL parameters: ${originalParams.keys.toList()}',
      );

      // Create enhanced parameters - preserve original + add app data
      final enhancedParams = <String, String>{};

      // FIRST: Add original parameters (PRESERVED)
      enhancedParams.addAll(originalParams);

      // SECOND: Add app data parameters (with conflict prevention)
      final appDataToAdd = {
        // Core user identification
        if (appData['user-role'] != null) 'user-role': appData['user-role']!,

        // App identification
        'flutter_app_source': appData['flutter_app_source'] ?? 'flutter_app',
        'flutter_app_version': appData['app_version'] ?? 'unknown',
        'flutter_platform': appData['platform'] ?? 'unknown',
        'flutter_device_model': appData['device_model'] ?? 'unknown',

        // User preferences
        'flutter_language': appData['current_language'] ?? 'en',
        'flutter_theme': appData['current_theme_mode'] ?? 'system',
        'flutter_direction': appData['text_direction'] ?? 'LTR',

        // Device identification
        'flutter_notification_id':
            appData['notification_id'] ?? AppDataService.NOTIFICATION_ID,
        'flutter_timestamp': DateTime.now().millisecondsSinceEpoch.toString(),

        // Compact encoded data as backup
        'app_data': _encodeAppDataToString(appData),
      };

      // Add app data parameters (only if not already exists)
      for (final entry in appDataToAdd.entries) {
        if (!enhancedParams.containsKey(entry.key)) {
          enhancedParams[entry.key] = entry.value;
        } else {
          debugPrint(
            '⚠️ Skipping ${entry.key} - already exists in original URL',
          );
        }
      }

      final newUri = uri.replace(queryParameters: enhancedParams);

      debugPrint('✅ Config URL enhanced successfully');
      debugPrint('📊 Total parameters: ${enhancedParams.length}');
      debugPrint(
        '📋 Original: ${originalParams.length}, Added: ${enhancedParams.length - originalParams.length}',
      );

      return newUri.toString();
    } catch (e) {
      debugPrint('❌ Error building enhanced config URL: $e');
      return baseUrl;
    }
  }

  /// NEW: Encode app data to compact string
  String _encodeAppDataToString(Map<String, String> appData) {
    try {
      final compactData = {
        'v': appData['app_version'] ?? 'unknown',
        'p': appData['platform'] ?? 'unknown',
        'l': appData['current_language'] ?? 'en',
        't': appData['current_theme_mode'] ?? 'system',
        'd': appData['text_direction'] ?? 'LTR',
        'n': appData['notification_id'] ?? AppDataService.NOTIFICATION_ID,
        'r': appData['user-role'] ?? '',
        'ts': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      final jsonString = jsonEncode(compactData);
      final encodedData = base64Encode(utf8.encode(jsonString));

      return encodedData;
    } catch (e) {
      debugPrint('❌ Error encoding app data: $e');
      return '';
    }
  }

  /// NEW: Build app data headers for config request
  Map<String, String> _buildAppDataHeaders(
    Map<String, String> appData, [
    BuildContext? context,
  ]) {
    final headers = <String, String>{
      'User-Agent': 'ERPForever-Flutter-App/1.0',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',

      // App identification headers
      'X-Flutter-App-Source': 'flutter_mobile',
      'X-Flutter-Client-Version': appData['app_version'] ?? 'unknown',
      'X-Flutter-Platform': appData['platform'] ?? 'unknown',
      'X-Flutter-Device-Model': appData['device_model'] ?? 'unknown',
      'X-Flutter-Timestamp': DateTime.now().toIso8601String(),

      // User context headers
      'X-Flutter-Language': appData['current_language'] ?? 'en',
      'X-Flutter-Theme': appData['current_theme_mode'] ?? 'system',
      'X-Flutter-Direction': appData['text_direction'] ?? 'LTR',
      'X-Flutter-Theme-Setting': appData['theme_setting'] ?? 'system',

      // Device identification
      'X-Flutter-Notification-ID':
          appData['notification_id'] ?? AppDataService.NOTIFICATION_ID,
    };

    // Add user role header if available
    if (_userRole != null) {
      headers['X-User-Role'] = _userRole!;
    }

    // Add additional device data if available
    if (appData['device_brand'] != null) {
      headers['X-Flutter-Device-Brand'] = appData['device_brand']!;
    }
    if (appData['build_number'] != null) {
      headers['X-Flutter-Build-Number'] = appData['build_number']!;
    }
    if (appData['timezone'] != null) {
      headers['X-Flutter-Timezone'] = appData['timezone']!;
    }

    debugPrint('📋 Config request headers created: ${headers.length} headers');
    return headers;
  }

  /// Parse config URL from loggedin:// protocol
  static Map<String, String> parseLoginConfigUrl(String loginUrl) {
    try {
      debugPrint('🔍 Parsing login config URL: $loginUrl');

      if (!loginUrl.startsWith('loggedin://')) {
        debugPrint('❌ Invalid login URL format');
        return {};
      }

      String cleanUrl = loginUrl.replaceFirst('loggedin://', '');
      Uri uri = Uri.parse('https://$cleanUrl');

      String configPath = uri.path;
      if (configPath.isEmpty) {
        configPath = '/config';
      }

      String baseUrl = 'https://mobile.erpforever.com';
      String fullConfigUrl = '$baseUrl$configPath';

      if (uri.queryParameters.isNotEmpty) {
        fullConfigUrl += '?${uri.query}';
      }

      String? role =
          uri.queryParameters['role'] ?? uri.queryParameters['user-role'];

      debugPrint('✅ Parsed config URL: $fullConfigUrl');
      debugPrint('👤 Extracted role: ${role ?? 'not specified'}');

      return {'configUrl': fullConfigUrl, if (role != null) 'role': role};
    } catch (e) {
      debugPrint('❌ Error parsing login config URL: $e');
      return {};
    }
  }

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

      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
      final isExpired = cacheAge > _cacheExpiry.inMilliseconds;

      if (isExpired) {
        debugPrint(
          '❌ Cached configuration expired (${Duration(milliseconds: cacheAge).inHours}h old)',
        );
        return false;
      }

      final Map<String, dynamic> configJson = json.decode(cachedConfig);
      _config = AppConfigModel.fromJson(configJson);

      debugPrint(
        '✅ Cached configuration loaded (${Duration(milliseconds: cacheAge).inMinutes}m old)',
      );
      debugPrint('📱 Main Icons: ${_config!.mainIcons.length}');
      debugPrint('📋 Sheet Icons: ${_config!.sheetIcons.length}');

      return true;
    } catch (e) {
      debugPrint('❌ Cached configuration error: $e');
      return false;
    }
  }

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

  Future<void> reloadConfig({
    bool bypassCache = false,
    BuildContext? context,
  }) async {
    if (bypassCache) {
      await _clearCache();
    }
    await loadConfig(context);
  }

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

  Future<bool> forceRemoteReload([BuildContext? context]) async {
    debugPrint('🔄 Force reloading from remote...');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      bool success = await _tryLoadRemoteConfig(context);
      if (success) {
        // 🆕 NEW: Process config with user role after force reload
        if (_config != null && _userRole != null) {
          debugPrint(
            '🔄 Processing force-reloaded config with user role: $_userRole',
          );
          _config = _processConfigWithUserRole(_config!, _userRole);
        }

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

  void updateConfig(AppConfigModel newConfig) {
    _config = newConfig;
    notifyListeners();
    debugPrint('🔄 Configuration updated at runtime');
    _cacheConfiguration();
  }

  Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey);

      if (cacheTimestamp == null) {
        return {'hasCachedConfig': false, 'cacheAge': 0, 'isExpired': true};
      }

      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
      final isExpired = cacheAge > _cacheExpiry.inMilliseconds;

      return {
        'hasCachedConfig': true,
        'cacheAge': cacheAge,
        'cacheAgeHours': (cacheAge / (1000 * 60 * 60)).round(),
        'isExpired': isExpired,
        'cacheTimestamp':
            DateTime.fromMillisecondsSinceEpoch(
              cacheTimestamp,
            ).toIso8601String(),
      };
    } catch (e) {
      return {'hasCachedConfig': false, 'error': e.toString()};
    }
  }

  void _loadDefaultConfig() {
    _config = AppConfigModel(
      lang: 'en',
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

  // Keep all your existing helper methods unchanged...
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed - checking for config updates...');
      _checkForConfigUpdates();
    }
  }

  Future<void> _checkForConfigUpdates([BuildContext? context]) async {
    try {
      final cacheStatus = await getCacheStatus();
      if (cacheStatus['hasCachedConfig'] == true) {
        final cacheAgeMinutes = (cacheStatus['cacheAge'] as int) / (1000 * 60);

        if (cacheAgeMinutes > 5) {
          debugPrint(
            '🔄 Cache is ${cacheAgeMinutes.round()} minutes old, checking for updates...',
          );

          final success = await _tryLoadRemoteConfig(context);
          if (success) {
            // 🆕 NEW: Process updated config with user role
            if (_config != null && _userRole != null) {
              debugPrint(
                '🔄 Processing updated config with user role: $_userRole',
              );
              _config = _processConfigWithUserRole(_config!, _userRole);
            }

            await _cacheConfiguration();
            debugPrint('✅ Configuration updated from remote');
            notifyListeners();
          }
        } else {
          debugPrint(
            '⏩ Cache is fresh (${cacheAgeMinutes.round()} minutes old), skipping update',
          );
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
