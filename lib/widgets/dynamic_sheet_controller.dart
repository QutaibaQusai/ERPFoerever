// lib/widgets/dynamic_sheet_controller.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/services/refresh_state_manager.dart'; 
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
    // NOTIFY REFRESH MANAGER THAT SHEET IS OPENING
    final refreshManager = Provider.of<RefreshStateManager>(context, listen: false);
    refreshManager.setSheetOpen(true);
    debugPrint('📋 DynamicSheetController action sheet opening - background refresh/scroll DISABLED');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // ADD isDismissible to handle swipe-to-close
      isDismissible: true,
      // ADD enableDrag to handle drag-to-close
      enableDrag: true,
      builder: (context) => const SheetModal(),
    ).then((_) {
      // HANDLE SHEET CLOSING BY ANY METHOD (swipe, tap outside, back button)
      refreshManager.setSheetOpen(false);
      debugPrint('📋 DynamicSheetController action sheet closed - background refresh/scroll ENABLED');
    });
  }
}