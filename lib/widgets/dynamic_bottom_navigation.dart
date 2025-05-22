// lib/widgets/dynamic_bottom_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/widgets/dynamic_navigation_icon.dart';

class DynamicBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const DynamicBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final config = ConfigService().config;
    if (config == null) return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return BottomAppBar(
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 8,
      height: 60,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _buildNavigationItems(context, config, isDarkMode),
      ),
    );
  }

  List<Widget> _buildNavigationItems(BuildContext context, config, bool isDarkMode) {
    List<Widget> items = [];
    
    for (int i = 0; i < config.mainIcons.length; i++) {
      // Insert FAB in the middle (index 2) if we have sheet icons
      if (i == 2 && config.sheetIcons.isNotEmpty) {
        items.add(_buildCenterAddButton(context, isDarkMode));
      }
      
      items.add(_buildNavItem(context, i, config.mainIcons[i], isDarkMode));
    }

    return items;
  }

  Widget _buildNavItem(BuildContext context, int index, item, bool isDarkMode) {
    final isSelected = selectedIndex == index;
    final Color iconColor = isSelected 
        ? Colors.blue
        : (isDarkMode ? Colors.grey[400]! : Colors.grey);
    
    return Expanded(
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () {
          HapticFeedback.lightImpact();
          _onItemTapped(context, index, item);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DynamicNavigationIcon(
              iconLineUrl: item.iconLine,
              iconSolidUrl: item.iconSolid,
              isSelected: isSelected,
              size: 24,
              selectedColor: Colors.blue,
              unselectedColor: isDarkMode ? Colors.grey[400] : Colors.grey,
            ),
            const SizedBox(height: 2),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAddButton(BuildContext context, bool isDarkMode) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _showAddOptions(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white : Colors.black,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                color: isDarkMode ? Colors.black : Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(BuildContext context, int index, item) {
    if (item.linkType == 'sheet_webview') {
      WebViewService().navigate(
        context,
        url: item.link,
        linkType: item.linkType,
        title: item.title,
      );
    } else {
      onItemTapped(index);
    }
  }

  void _showAddOptions(BuildContext context) {
    final config = ConfigService().config;
    if (config == null || config.sheetIcons.isEmpty) return;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _buildActionButtons(context, config),
            ),
            const SizedBox(height: 30),
            GestureDetector(
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
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context, config) {
    // Take first 3 sheet icons to match original 3-button design
    final itemsToShow = config.sheetIcons.take(3).toList();
    
    return itemsToShow.map<Widget>((item) => 
      _buildActionButton(
        item.title,
        _getIconForTitle(item.title),
        _getColorForTitle(item.title),
        () {
          Navigator.pop(context);
          WebViewService().navigate(
            context,
            url: item.link,
            linkType: item.linkType,
            title: item.title,
          );
        },
      ),
    ).toList();
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  IconData _getIconForTitle(String title) {
    switch (title.toLowerCase()) {
      case 'status':
      case 'sheet first':
        return FluentIcons.document_16_regular;
      case 'time log':
      case 'timelog':
      case 'sheet second':
        return FluentIcons.clock_16_regular;
      case 'leave':
      case 'sheet third':
        return FluentIcons.weather_partly_cloudy_day_16_regular;
      default:
        return FluentIcons.apps_16_regular;
    }
  }

  Color _getColorForTitle(String title) {
    switch (title.toLowerCase()) {
      case 'status':
      case 'sheet first':
        return Colors.green;
      case 'time log':
      case 'timelog':
      case 'sheet second':
        return Colors.blue;
      case 'leave':
      case 'sheet third':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }
}