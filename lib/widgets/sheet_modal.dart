// lib/widgets/sheet_modal.dart
import 'package:flutter/material.dart';
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/widgets/sheet_action_item.dart';

class SheetModal extends StatelessWidget {
  const SheetModal({super.key});

  @override
  Widget build(BuildContext context) {
    final config = ConfigService().config;
    if (config == null || config.sheetIcons.isEmpty) {
      return _buildEmptySheet(context);
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          _buildSheetActions(context, config),
          const SizedBox(height: 30),
          _buildCloseButton(context, isDarkMode),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSheetActions(BuildContext context, config) {
    const chunkSize = 3;
    final chunks = <List>[];

    for (int i = 0; i < config.sheetIcons.length; i += chunkSize) {
      chunks.add(
        config.sheetIcons.skip(i).take(chunkSize).toList(),
      );
    }

    return Column(
      children: chunks.map((chunk) => 
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: chunk.map<Widget>((item) => 
              Expanded(
                child: SheetActionItem(
                  title: item.title,
                  iconLineUrl: item.iconLine,
                  iconSolidUrl: item.iconSolid,
                  onTap: () => _handleSheetItemTap(context, item),
                ),
              ),
            ).toList(),
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildCloseButton(BuildContext context, bool isDarkMode) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white : Colors.black,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close,
          color: isDarkMode ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  Widget _buildEmptySheet(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          const SizedBox(height: 16),
          Text(
            'No actions available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 30),
          _buildCloseButton(context, isDarkMode),
        ],
      ),
    );
  }

  void _handleSheetItemTap(BuildContext context, item) {
    Navigator.pop(context);
    
    WebViewService().navigate(
      context,
      url: item.link,
      linkType: item.linkType,
      title: item.title,
    );
  }
}
