// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'themeMode';
  
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  ThemeService() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_themeKey) ?? 'system';
    _themeMode = _getThemeModeFromString(themeString);
    notifyListeners();
  }

  Future<String> getSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  Future<void> updateThemeMode(String mode) async {
    final newThemeMode = _getThemeModeFromString(mode);
    if (_themeMode != newThemeMode) {
      _themeMode = newThemeMode;
      notifyListeners();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode);
    }
  }

  ThemeMode _getThemeModeFromString(String mode) {
    switch (mode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }
}