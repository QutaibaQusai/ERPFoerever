// lib/models/link_types.dart
enum LinkType {
  regularWebview('regular_webview'),
  sheetWebview('sheet_webview');

  const LinkType(this.value);
  final String value;

  static LinkType fromString(String value) {
    return LinkType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => LinkType.regularWebview,
    );
  }

  @override
  String toString() => value;
}