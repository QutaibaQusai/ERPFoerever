import 'package:ERPForever/models/header_icon_model.dart';

class MainIconModel {
  final String title;
  final String iconLine;
  final String iconSolid;
  final String link;
  final String linkType;
  final List<HeaderIconModel>? headerIcons;

  MainIconModel({
    required this.title,
    required this.iconLine,
    required this.iconSolid,
    required this.link,
    required this.linkType,
    this.headerIcons,
  });

  factory MainIconModel.fromJson(Map<String, dynamic> json) {
    return MainIconModel(
      title: json['title'],
      iconLine: json['icon-line'],
      iconSolid: json['icon-solid'],
      link: json['link'],
      linkType: json['link_type'],
      headerIcons: json['header_icons'] != null
          ? (json['header_icons'] as List)
              .map((icon) => HeaderIconModel.fromJson(icon))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'icon-line': iconLine,
      'icon-solid': iconSolid,
      'link': link,
      'link_type': linkType,
      'header_icons': headerIcons?.map((icon) => icon.toJson()).toList(),
    };
  }

  // 🆕 NEW: Add copyWith method
  MainIconModel copyWith({
    String? title,
    String? iconLine,
    String? iconSolid,
    String? link,
    String? linkType,
    List<HeaderIconModel>? headerIcons,
  }) {
    return MainIconModel(
      title: title ?? this.title,
      iconLine: iconLine ?? this.iconLine,
      iconSolid: iconSolid ?? this.iconSolid,
      link: link ?? this.link,
      linkType: linkType ?? this.linkType,
      headerIcons: headerIcons ?? this.headerIcons,
    );
  }
}
