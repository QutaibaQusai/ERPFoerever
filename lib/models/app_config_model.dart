// lib/models/app_config_model.dart
import 'package:ERPForever/models/theme_config_model.dart';
import 'package:ERPForever/models/main_icon_model.dart';
import 'package:ERPForever/models/sheet_icon_model.dart';

class AppConfigModel {
  final String lang; // NEW: Language property
  final ThemeConfigModel theme;
  final List<MainIconModel> mainIcons;
  final List<SheetIconModel> sheetIcons;

  AppConfigModel({
    required this.lang,
    required this.theme,
    required this.mainIcons,
    required this.sheetIcons,
  });

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    return AppConfigModel(
      lang: json['lang'] ?? 'en', // Default to 'en' if not specified
      theme: ThemeConfigModel.fromJson(json['theme']),
      mainIcons: (json['main_icons'] as List)
          .map((icon) => MainIconModel.fromJson(icon))
          .toList(),
      sheetIcons: (json['sheet_icons'] as List)
          .map((icon) => SheetIconModel.fromJson(icon))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lang': lang,
      'theme': theme.toJson(),
      'main_icons': mainIcons.map((icon) => icon.toJson()).toList(),
      'sheet_icons': sheetIcons.map((icon) => icon.toJson()).toList(),
    };
  }
}