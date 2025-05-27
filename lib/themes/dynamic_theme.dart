// lib/themes/dynamic_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ERPForever/models/app_config_model.dart';

class DynamicTheme {
  static ThemeData buildLightTheme(AppConfigModel? config) {
    final baseTextTheme = GoogleFonts.tajawalTextTheme();
    
    final primaryColor = config != null 
        ? _hexToColor(config.theme.primaryColor)
        : const Color(0xFF0078d7);
    
    final backgroundColor = config != null
        ? _hexToColor(config.theme.lightBackground)
        : const Color(0xFFF5F5F5);
    
    // Get text direction
    final isRTL = config?.theme.isRTL ?? false;

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: GoogleFonts.tajawal(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        // RTL support for AppBar
        centerTitle: false,
        titleSpacing: isRTL ? 0 : NavigationToolbar.kMiddleSpacing,
      ),
      // RTL-aware text theme
      textTheme: baseTextTheme.apply(
        // For RTL, we might want to adjust text alignment
        fontFamily: isRTL ? 'Tajawal' : null,
      ),
      // RTL-aware visual density
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: true,
    );
  }

  static ThemeData buildDarkTheme(AppConfigModel? config) {
    final baseTextTheme = GoogleFonts.tajawalTextTheme();
    
    final primaryColor = config != null 
        ? _hexToColor(config.theme.primaryColor)
        : const Color(0xFF0078d7);
    
    final backgroundColor = config != null
        ? _hexToColor(config.theme.darkBackground)
        : const Color(0xFF121212);

    final surfaceColor = config != null
        ? _hexToColor(config.theme.darkSurface)
        : const Color(0xFF1E1E1E);
    
    // Get text direction
    final isRTL = config?.theme.isRTL ?? false;

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.tajawal(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        // RTL support for AppBar
        centerTitle: false,
        titleSpacing: isRTL ? 0 : NavigationToolbar.kMiddleSpacing,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
        // For RTL, we might want to adjust text alignment
        fontFamily: isRTL ? 'Tajawal' : null,
      ),
      bottomAppBarTheme: BottomAppBarTheme(color: surfaceColor),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: true,
    );
  }

  static Color _hexToColor(String hexColor) {
    return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  }
}