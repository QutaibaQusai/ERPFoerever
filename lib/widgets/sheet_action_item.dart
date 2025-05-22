// lib/widgets/sheet_action_item.dart
import 'package:flutter/material.dart';
import 'package:ERPForever/widgets/dynamic_icon.dart';

class SheetActionItem extends StatelessWidget {
  final String title;
  final String iconLineUrl;
  final String iconSolidUrl;
  final VoidCallback onTap;
  final bool showSolid;

  const SheetActionItem({
    super.key,
    required this.title,
    required this.iconLineUrl,
    required this.iconSolidUrl,
    required this.onTap,
    this.showSolid = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: DynamicIcon(
                  iconUrl: showSolid ? iconSolidUrl : iconLineUrl,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                  showLoading: false,
                  fallbackIcon: Icon(
                    Icons.apps,
                    size: 32,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}