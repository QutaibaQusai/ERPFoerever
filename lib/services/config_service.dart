// lib/services/config_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ERPForever/models/app_config_model.dart';
import 'package:ERPForever/models/theme_config_model.dart';
import 'package:ERPForever/models/main_icon_model.dart';

class ConfigService extends ChangeNotifier {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  AppConfigModel? _config;
  bool _isLoading = false;
  String? _error;

  AppConfigModel? get config => _config;
  bool get isLoading => _isLoading;
  bool get isLoaded => _config != null;
  String? get error => _error;

  Future<void> loadConfig() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final String configString = await rootBundle.loadString(
        'assets/config.json',
      );
      final Map<String, dynamic> configJson = json.decode(configString);

      _config = AppConfigModel.fromJson(configJson);

      debugPrint('✅ Configuration loaded successfully');
      debugPrint('📱 Main Icons: ${_config!.mainIcons.length}');
      debugPrint('📋 Sheet Icons: ${_config!.sheetIcons.length}');
      debugPrint('🌍 Direction: ${_config!.theme.direction}');
    } catch (e) {
      _error = 'Failed to load configuration: $e';
      debugPrint('❌ Error loading configuration: $e');
      _loadDefaultConfig();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRemoteConfig(String url) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // TODO: Implement HTTP call
      await loadConfig();
    } catch (e) {
      _error = 'Failed to load remote configuration: $e';
      debugPrint('❌ Error loading remote configuration: $e');
      await loadConfig();
    }
  }

  Future<void> reloadConfig() async {
    await loadConfig();
  }

  void updateConfig(AppConfigModel newConfig) {
    _config = newConfig;
    notifyListeners();
    debugPrint('🔄 Configuration updated at runtime');
  }

  void _loadDefaultConfig() {
    _config = AppConfigModel(
      theme: ThemeConfigModel(
        primaryColor: '#0078d7',
        lightBackground: '#F5F5F5',
        darkBackground: '#121212',
        darkSurface: '#1E1E1E',
        defaultMode: 'system',
        direction: 'LTR', // Default direction
      ),
      mainIcons: [
        MainIconModel(
          title: 'Home',
          iconLine: 'https://cdn-icons-png.flaticon.com/128/1946/1946488.png',
          iconSolid: 'https://cdn-icons-png.flaticon.com/128/1946/1946436.png',
          link: 'https://erpforever.com/mobile',
          linkType: 'regular_webview',
        ),
      ],
      sheetIcons: [],
      lang: '',
    );
    debugPrint('⚠️ Using default configuration');
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

  // New method to get text direction
  TextDirection getTextDirection() {
    if (_config == null) return TextDirection.ltr;
    return _config!.theme.textDirection;
  }

  // New method to check if RTL
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
}
