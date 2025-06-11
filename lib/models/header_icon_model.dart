// lib/models/header_icon_model.dart - UPDATED: Added copyWith method
class HeaderIconModel {
  final String title;
  final String icon;
  final String link;
  final String linkType;

  HeaderIconModel({
    required this.title,
    required this.icon,
    required this.link,
    required this.linkType,
  });

  factory HeaderIconModel.fromJson(Map<String, dynamic> json) {
    return HeaderIconModel(
      title: json['title'],
      icon: json['icon'],
      link: json['link'],
      linkType: json['link_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'icon': icon,
      'link': link,
      'link_type': linkType,
    };
  }

  // 🆕 NEW: Add copyWith method
  HeaderIconModel copyWith({
    String? title,
    String? icon,
    String? link,
    String? linkType,
  }) {
    return HeaderIconModel(
      title: title ?? this.title,
      icon: icon ?? this.icon,
      link: link ?? this.link,
      linkType: linkType ?? this.linkType,
    );
  }
}