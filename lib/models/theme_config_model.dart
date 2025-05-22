// lib/models/theme_config_model.dart
class ThemeConfigModel {
  final String primaryColor;
  final String lightBackground;
  final String darkBackground;
  final String darkSurface;
  final String defaultMode;

  ThemeConfigModel({
    required this.primaryColor,
    required this.lightBackground,
    required this.darkBackground,
    required this.darkSurface,
    required this.defaultMode,
  });

  factory ThemeConfigModel.fromJson(Map<String, dynamic> json) {
    return ThemeConfigModel(
      primaryColor: json['primaryColor'],
      lightBackground: json['lightBackground'],
      darkBackground: json['darkBackground'],
      darkSurface: json['darkSurface'],
      defaultMode: json['defaultMode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primaryColor': primaryColor,
      'lightBackground': lightBackground,
      'darkBackground': darkBackground,
      'darkSurface': darkSurface,
      'defaultMode': defaultMode,
    };
  }
}