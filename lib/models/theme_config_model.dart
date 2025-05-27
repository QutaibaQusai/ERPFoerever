// lib/models/theme_config_model.dart
import 'package:flutter/material.dart';

class ThemeConfigModel {
  final String primaryColor;
  final String lightBackground;
  final String darkBackground;
  final String darkSurface;
  final String defaultMode;
  final String direction; // New field for RTL/LTR

  ThemeConfigModel({
    required this.primaryColor,
    required this.lightBackground,
    required this.darkBackground,
    required this.darkSurface,
    required this.defaultMode,
    required this.direction,
  });

  factory ThemeConfigModel.fromJson(Map<String, dynamic> json) {
    return ThemeConfigModel(
      primaryColor: json['primaryColor'],
      lightBackground: json['lightBackground'],
      darkBackground: json['darkBackground'],
      darkSurface: json['darkSurface'],
      defaultMode: json['defaultMode'],
      direction: json['direction'] ?? 'LTR', // Default to LTR if not specified
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primaryColor': primaryColor,
      'lightBackground': lightBackground,
      'darkBackground': darkBackground,
      'darkSurface': darkSurface,
      'defaultMode': defaultMode,
      'direction': direction,
    };
  }

  // Helper method to get TextDirection enum
  TextDirection get textDirection {
    return direction.toUpperCase() == 'RTL' ? TextDirection.rtl : TextDirection.ltr;
  }

  // Helper method to check if RTL
  bool get isRTL {
    return direction.toUpperCase() == 'RTL';
  }
}