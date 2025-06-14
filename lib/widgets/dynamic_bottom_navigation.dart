// lib/widgets/dynamic_bottom_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart'; // ADD THIS IMPORT
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/services/refresh_state_manager.dart'; // ADD THIS IMPORT
import 'package:ERPForever/widgets/dynamic_navigation_icon.dart';
import 'package:ERPForever/widgets/dynamic_icon.dart';

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
      height: 75,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _buildNavigationItems(context, config, isDarkMode),
      ),
    );
  }

  List<Widget> _buildNavigationItems(
    BuildContext context,
    config,
    bool isDarkMode,
  ) {
    List<Widget> items = [];

    for (int i = 0; i < config.mainIcons.length; i++) {
      if (i == 2 && config.sheetIcons.isNotEmpty) {
        items.add(_buildCenterAddButton(context, isDarkMode));
      }

      items.add(_buildNavItem(context, i, config.mainIcons[i], isDarkMode));
    }

    return items;
  }

  Widget _buildNavItem(BuildContext context, int index, item, bool isDarkMode) {
    final isSelected = selectedIndex == index;
    final Color iconColor =
        isSelected
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

    // NOTIFY REFRESH MANAGER THAT SHEET IS OPENING
    final refreshManager = Provider.of<RefreshStateManager>(
      context,
      listen: false,
    );
    refreshManager.setSheetOpen(true);
    debugPrint(
      '📋 DynamicBottomNavigation sheet opening - background refresh/scroll DISABLED',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // ADD isDismissible to handle swipe-to-close
      isDismissible: true,
      // ADD enableDrag to handle drag-to-close
      enableDrag: true,
      builder:
          (context) => Container(
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
                _buildSheetActionsGrid(context, config, isDarkMode),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: () {
                    // NOTIFY REFRESH MANAGER THAT SHEET IS CLOSING
                    refreshManager.setSheetOpen(false);
                    debugPrint(
                      '📋 DynamicBottomNavigation sheet closing via close button - background refresh/scroll ENABLED',
                    );
                    Navigator.pop(context);
                  },
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
    ).then((_) {
      // HANDLE SHEET CLOSING BY ANY METHOD (swipe, tap outside, back button)
      refreshManager.setSheetOpen(false);
      debugPrint(
        '📋 DynamicBottomNavigation sheet closed - background refresh/scroll ENABLED',
      );
    });
  }

  Widget _buildSheetActionsGrid(BuildContext context, config, bool isDarkMode) {
    final sheetIcons = config.sheetIcons;

    // Create rows with maximum 3 items each
    final List<Widget> rows = [];
    for (int i = 0; i < sheetIcons.length; i += 3) {
      final rowItems = sheetIcons.skip(i).take(3).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children:
                rowItems
                    .map<Widget>(
                      (item) => Expanded(
                        child: _buildDynamicActionButton(
                          context,
                          item,
                          isDarkMode,
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildDynamicActionButton(
    BuildContext context,
    item,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            // NOTIFY REFRESH MANAGER THAT SHEET IS CLOSING
            final refreshManager = Provider.of<RefreshStateManager>(
              context,
              listen: false,
            );
            refreshManager.setSheetOpen(false);
            debugPrint(
              '📋 DynamicBottomNavigation sheet closing via action button - background refresh/scroll ENABLED',
            );

            Navigator.pop(context);

            // Navigate to the selected item
            WebViewService().navigate(
              context,
              url: item.link,
              linkType: item.linkType,
              title: item.title,
            );
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: DynamicIcon(
                iconUrl: item.iconSolid,
                size: 28,
                color: Colors.grey,
                showLoading: false,
                fallbackIcon: Icon(
                  _getIconForTitle(item.title),
                  color: Colors.grey,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
      case 'sheet fourth':
        return FluentIcons.apps_16_regular;
      default:
        return FluentIcons.circle_16_regular;
    }
  }
}