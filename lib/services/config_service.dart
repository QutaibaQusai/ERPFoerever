// lib/services/config_service.dart - UPDATED: Always use remote URL, no local fallback
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ERPForever/models/app_config_model.dart';
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

  // Configuration URLs - REMOVED local config path
  static const String _defaultRemoteConfigUrl = 'https://mobile.erpforever.com/config';
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
  bool _hasNetworkError = false; // NEW: Track network connectivity

  AppConfigModel? get config => _config;
  bool get isLoading => _isLoading;
  bool get isLoaded => _config != null;
  String? get error => _error;
  String? get currentConfigUrl => _dynamicConfigUrl ?? _defaultRemoteConfigUrl;
  String? get userRole => _userRole;
  bool get hasNetworkError => _hasNetworkError;

  AppConfigModel _processConfigWithUserRole(AppConfigModel config, String? userRole) {
    if (userRole == null || userRole.trim().isEmpty) {
      debugPrint('⚠️ No user role to apply to config URLs');
      return config;
    }

    final cleanRole = userRole.trim();
    debugPrint('🔄 Processing config URLs to replace empty/missing user-role with: $cleanRole');

    try {
      final updatedMainIcons = config.mainIcons.map((icon) {
        final updatedLink = _replaceUserRoleInUrl(icon.link, cleanRole);

        List<HeaderIconModel>? updatedHeaderIcons;
        if (icon.headerIcons != null) {
          updatedHeaderIcons = icon.headerIcons!.map((headerIcon) {
            return HeaderIconModel(
              title: headerIcon.title,
              icon: headerIcon.icon,
              link: _replaceUserRoleInUrl(headerIcon.link, cleanRole),
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

      final updatedSheetIcons = config.sheetIcons.map((icon) {
        final updatedLink = _replaceUserRoleInUrl(icon.link, cleanRole);

        List<HeaderIconModel>? updatedHeaderIcons;
        if (icon.headerIcons != null) {
          updatedHeaderIcons = icon.headerIcons!.map((headerIcon) {
            return HeaderIconModel(
              title: headerIcon.title,
              icon: headerIcon.icon,
              link: _replaceUserRoleInUrl(headerIcon.link, cleanRole),
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

      debugPrint('✅ Config URLs processed successfully with user role: $cleanRole');
      return updatedConfig;
    } catch (e) {
      debugPrint('❌ Error processing config with user role: $e');
      return config; 
    }
  }

  String _replaceUserRoleInUrl(String url, String userRole) {
    try {
      debugPrint('🔍 Processing URL: $url');
      debugPrint('👤 User role to apply: $userRole');
      
      if (url.isEmpty || userRole.isEmpty) {
        debugPrint('⚠️ Empty URL or role, returning original URL');
        return url;
      }

      final uri = Uri.parse(url);
      final queryParams = Map<String, String>.from(uri.queryParameters);

      bool urlWasModified = false;

      if (queryParams.containsKey('user-role')) {
        final currentRole = queryParams['user-role'] ?? '';
        
        if (currentRole.isEmpty) {
          queryParams['user-role'] = userRole;
          urlWasModified = true;
          debugPrint('✅ Replaced empty user-role parameter');
        } else {
          debugPrint('ℹ️ URL already has user-role: $currentRole, keeping as-is');
        }
      } 
      else if (queryParams.isNotEmpty) {
        queryParams['user-role'] = userRole;
        urlWasModified = true;
        debugPrint('✅ Added missing user-role parameter');
      }
      else {
        queryParams['user-role'] = userRole;
        urlWasModified = true;
        debugPrint('✅ Added user-role parameter to URL without query params');
      }

      if (urlWasModified) {
        final updatedUri = uri.replace(queryParameters: queryParams);
        final updatedUrl = updatedUri.toString();
        
        debugPrint('🔄 URL transformation:');
        debugPrint('   Before: $url');
        debugPrint('   After:  $updatedUrl');
        
        return updatedUrl;
      }

      return url;
    } catch (e) {
      debugPrint('❌ Error processing URL $url: $e');
      return url; 
    }
  }

  static Map<String, String> parseLoginConfigUrl(String loginUrl) {
    try {
      debugPrint('🔍 Parsing login config URL: $loginUrl');

      if (!loginUrl.startsWith('loggedin://')) {
        debugPrint('❌ Invalid login URL format - must start with loggedin://');
        return {};
      }

      String cleanUrl = loginUrl.replaceFirst('loggedin://', '');
      
      Uri uri;
      try {
        uri = Uri.parse('https://$cleanUrl');
      } catch (e) {
        debugPrint('❌ Error parsing URI: $e');
        return {};
      }

      String configPath = uri.path;
      if (configPath.isEmpty || configPath == '/') {
        configPath = '/config';
      }

      String baseUrl = 'https://mobile.erpforever.com';
      String fullConfigUrl = '$baseUrl$configPath';

      if (uri.queryParameters.isNotEmpty) {
        final queryString = uri.query;
        fullConfigUrl += '?$queryString';
      }

      String? role = uri.queryParameters['role'] ?? 
                    uri.queryParameters['user-role'] ?? 
                    uri.queryParameters['userRole'] ??
                    uri.queryParameters['user_role'];

      debugPrint('✅ Parsed results:');
      debugPrint('   Config URL: $fullConfigUrl');
      debugPrint('   Extracted role: ${role ?? 'not specified'}');
      debugPrint('   All query params: ${uri.queryParameters}');

      final result = {'configUrl': fullConfigUrl};
      if (role != null && role.trim().isNotEmpty) {
        result['role'] = role.trim();
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error parsing login config URL: $e');
      return {};
    }
  }

  Future<void> setDynamicConfigUrl(String configUrl, {String? role}) async {
    try {
      debugPrint('🔄 Setting dynamic config URL: $configUrl');
      debugPrint('👤 User role: ${role ?? 'not specified'}');

      _dynamicConfigUrl = configUrl;
      _userRole = role?.trim();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dynamicConfigUrlKey, configUrl);
      
      if (_userRole != null && _userRole!.isNotEmpty) {
        await prefs.setString(_userRoleKey, _userRole!);
        debugPrint('✅ User role saved: $_userRole');
      } else {
        await prefs.remove(_userRoleKey);
        debugPrint('⚠️ No valid role provided, removing stored role');
      }

      debugPrint('✅ Dynamic config URL and role saved successfully');

      await loadConfig();
    } catch (e) {
      debugPrint('❌ Error setting dynamic config URL: $e');
    }
  }

  Future<void> _loadSavedDynamicConfigUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dynamicConfigUrl = prefs.getString(_dynamicConfigUrlKey);
      _userRole = prefs.getString(_userRoleKey);

      if (_dynamicConfigUrl != null) {
        debugPrint('📱 Loaded saved dynamic config URL: $_dynamicConfigUrl');
        debugPrint('👤 Loaded saved user role: ${_userRole ?? 'none'}');
      }
    } catch (e) {
      debugPrint('❌ Error loading saved dynamic config URL: $e');
    }
  }

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

  // UPDATED: Only try remote config, no fallbacks to local/default
  Future<void> loadConfig([BuildContext? context]) async {
    try {
      _isLoading = true;
      _error = null;
      _hasNetworkError = false; // Reset network error state
      notifyListeners();

      debugPrint('🔄 Starting configuration loading process (REMOTE ONLY)...');
      debugPrint('👤 Current stored user role: ${_userRole ?? 'none'}');

      await _loadSavedDynamicConfigUrl();

      // ONLY try remote config - no fallbacks
      bool remoteSuccess = await _tryLoadRemoteConfig(context);

      if (remoteSuccess) {
        debugPrint('✅ Remote configuration loaded successfully');

        if (_config != null && _userRole != null && _userRole!.isNotEmpty) {
          debugPrint('🔄 Processing config with stored user role: $_userRole');
          _config = _processConfigWithUserRole(_config!, _userRole);
          debugPrint('✅ Config processed with user role applied to all URLs');
        } else {
          debugPrint('⚠️ No user role available for URL processing');
        }

        await _cacheConfiguration();
        return;
      }

      // If remote fails, set network error and don't load anything
      debugPrint('❌ Remote configuration failed - showing network error');
      _hasNetworkError = true;
      _error = 'Unable to connect to configuration server. Please check your internet connection.';
      
    } catch (e) {
      debugPrint('❌ Configuration loading error: $e');
      _hasNetworkError = true;
      _error = 'Failed to load configuration: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _tryLoadRemoteConfig([BuildContext? context]) async {
    try {
      String baseConfigUrl = _dynamicConfigUrl ?? _defaultRemoteConfigUrl;

      debugPrint('🌐 Fetching remote configuration from: $baseConfigUrl');
      debugPrint('👤 Will apply user role after loading: ${_userRole ?? 'none'}');

      final appData = await AppDataService().collectDataForServer(context);

      if (_userRole != null && _userRole!.isNotEmpty) {
        appData['user-role'] = _userRole!;
        debugPrint('👤 Added user-role to request: $_userRole');
      }

      final enhancedConfigUrl = _buildEnhancedConfigUrl(baseConfigUrl, appData);
      final headers = _buildAppDataHeaders(appData, context);

      debugPrint('🔗 Final request URL: $enhancedConfigUrl');

      final response = await http
          .get(Uri.parse(enhancedConfigUrl), headers: headers)
          .timeout(const Duration(seconds: 15)); // Increased timeout

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

  String _buildEnhancedConfigUrl(String baseUrl, Map<String, String> appData) {
    try {
      final uri = Uri.parse(baseUrl);
      final originalParams = Map<String, String>.from(uri.queryParameters);

      debugPrint('📋 Original config URL parameters: ${originalParams.keys.toList()}');

      final enhancedParams = <String, String>{};

      enhancedParams.addAll(originalParams);

      final appDataToAdd = {
        if (appData['user-role'] != null && appData['user-role']!.isNotEmpty) 
          'user-role': appData['user-role']!,

        'flutter_app_source': appData['flutter_app_source'] ?? 'flutter_app',
        'flutter_app_version': appData['app_version'] ?? 'unknown',
        'flutter_platform': appData['platform'] ?? 'unknown',
        'flutter_device_model': appData['device_model'] ?? 'unknown',

        'flutter_language': appData['current_language'] ?? 'en',
        'flutter_theme': appData['current_theme_mode'] ?? 'system',
        'flutter_direction': appData['text_direction'] ?? 'LTR',

        'flutter_notification_id': appData['notification_id'] ?? AppDataService.NOTIFICATION_ID,
        'flutter_timestamp': DateTime.now().millisecondsSinceEpoch.toString(),

        'app_data': _encodeAppDataToString(appData),
      };

      for (final entry in appDataToAdd.entries) {
        if (!enhancedParams.containsKey(entry.key)) {
          enhancedParams[entry.key] = entry.value;
        } else {
          debugPrint('⚠️ Skipping ${entry.key} - already exists in original URL');
        }
      }

      final newUri = uri.replace(queryParameters: enhancedParams);

      debugPrint('✅ Config URL enhanced successfully');
      debugPrint('📊 Total parameters: ${enhancedParams.length}');
      debugPrint('📋 Original: ${originalParams.length}, Added: ${enhancedParams.length - originalParams.length}');

      return newUri.toString();
    } catch (e) {
      debugPrint('❌ Error building enhanced config URL: $e');
      return baseUrl;
    }
  }

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

  Map<String, String> _buildAppDataHeaders(Map<String, String> appData, [BuildContext? context]) {
    final headers = <String, String>{
      'User-Agent': 'ERPForever-Flutter-App/1.0',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',

      'X-Flutter-App-Source': 'flutter_mobile',
      'X-Flutter-Client-Version': appData['app_version'] ?? 'unknown',
      'X-Flutter-Platform': appData['platform'] ?? 'unknown',
      'X-Flutter-Device-Model': appData['device_model'] ?? 'unknown',
      'X-Flutter-Timestamp': DateTime.now().toIso8601String(),

      'X-Flutter-Language': appData['current_language'] ?? 'en',
      'X-Flutter-Theme': appData['current_theme_mode'] ?? 'system',
      'X-Flutter-Direction': appData['text_direction'] ?? 'LTR',
      'X-Flutter-Theme-Setting': appData['theme_setting'] ?? 'system',

      'X-Flutter-Notification-ID': appData['notification_id'] ?? AppDataService.NOTIFICATION_ID,
    };

    if (_userRole != null && _userRole!.isNotEmpty) {
      headers['X-User-Role'] = _userRole!;
    }

    return headers;
  }

  // REMOVED: _tryLoadCachedConfig method
  // REMOVED: _tryLoadLocalConfig method
  // REMOVED: _loadDefaultConfig method

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

  Future<void> reloadConfig({bool bypassCache = false, BuildContext? context}) async {
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
    _hasNetworkError = false;
    notifyListeners();

    try {
      bool success = await _tryLoadRemoteConfig(context);
      if (success) {
        // Process config with user role after force reload
        if (_config != null && _userRole != null && _userRole!.isNotEmpty) {
          debugPrint('🔄 Processing force-reloaded config with user role: $_userRole');
          _config = _processConfigWithUserRole(_config!, _userRole);
        }

        await _cacheConfiguration();
        debugPrint('✅ Force remote reload successful');
      } else {
        _hasNetworkError = true;
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
    _hasNetworkError = false; // Clear network error if config is updated
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
        'cacheTimestamp': DateTime.fromMillisecondsSinceEpoch(cacheTimestamp).toIso8601String(),
      };
    } catch (e) {
      return {'hasCachedConfig': false, 'error': e.toString()};
    }
  }

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
          debugPrint('🔄 Cache is ${cacheAgeMinutes.round()} minutes old, checking for updates...');

          final success = await _tryLoadRemoteConfig(context);
          if (success) {
            // Process updated config with user role
            if (_config != null && _userRole != null && _userRole!.isNotEmpty) {
              debugPrint('🔄 Processing updated config with user role: $_userRole');
              _config = _processConfigWithUserRole(_config!, _userRole);
            }

            await _cacheConfiguration();
            debugPrint('✅ Configuration updated from remote');
            notifyListeners();
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