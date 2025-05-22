import 'package:flutter/material.dart';
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/widgets/sheet_modal.dart';

class DynamicSheetController {
  static void showSheetFromConfig(
    BuildContext context, {
    int? sheetIndex,
    String? customUrl,
    String? customTitle,
  }) {
    final config = ConfigService().config;
    if (config == null) return;

    if (sheetIndex != null && sheetIndex < config.sheetIcons.length) {
      final sheetItem = config.sheetIcons[sheetIndex];
      WebViewService().navigate(
        context,
        url: sheetItem.link,
        linkType: sheetItem.linkType,
        title: sheetItem.title,
      );
    } else if (customUrl != null) {
      WebViewService().navigate(
        context,
        url: customUrl,
        linkType: 'sheet_webview',
        title: customTitle ?? 'Web View',
      );
    }
  }

  static void showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const SheetModal(),
    );
  }
}