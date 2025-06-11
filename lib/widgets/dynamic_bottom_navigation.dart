// lib/widgets/dynamic_bottom_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/services/refresh_state_manager.dart';
import 'package:ERPForever/widgets/dynamic_navigation_icon.dart';
import 'package:ERPForever/widgets/dynamic_icon.dart';
import 'dart:ui';

class DynamicBottomNavigation extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final bool isScrolling; // Add this to track scrolling state

  const DynamicBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.isScrolling = false,
  });

  @override
  State<DynamicBottomNavigation> createState() => _DynamicBottomNavigationState();
}

class _DynamicBottomNavigationState extends State<DynamicBottomNavigation>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _heightAnimation = Tween<double>(
      begin: 90.0,
      end: 60.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(DynamicBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScrolling != oldWidget.isScrolling) {
      if (widget.isScrolling) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigService().config;
    if (config == null) return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          height: _heightAnimation.value,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: widget.isScrolling ? 8 : 20,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.isScrolling ? 25 : 30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.isScrolling ? 25 : 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode
                      ? [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ]
                      : [
                          Colors.white.withOpacity(0.9),
                          Colors.white.withOpacity(0.7),
                        ],
                ),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.3),
                  width: 0,
                ),
                borderRadius: BorderRadius.circular(widget.isScrolling ? 25 : 30),
              ),
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _buildNavigationItems(context, config, isDarkMode),
                ),
              ),
            ),
          ),
        );
      },
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
    final isSelected = widget.selectedIndex == index;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? (isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.1))
              : Colors.transparent,
        ),
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            _onItemTapped(context, index, item);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: DynamicNavigationIcon(
                  iconLineUrl: item.iconLine,
                  iconSolidUrl: item.iconSolid,
                  isSelected: isSelected,
                  size: widget.isScrolling ? 20 : 24,
                  selectedColor: isDarkMode ? Colors.white : Colors.black,
                  unselectedColor: isDarkMode 
                      ? Colors.white.withOpacity(0.6) 
                      : Colors.black.withOpacity(0.6),
                ),
              ),
              if (!widget.isScrolling) ...[
                const SizedBox(height: 4),
                AnimatedOpacity(
                  opacity: widget.isScrolling ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? (isDarkMode ? Colors.white : Colors.black)
                          : (isDarkMode 
                              ? Colors.white.withOpacity(0.7) 
                              : Colors.black.withOpacity(0.7)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterAddButton(BuildContext context, bool isDarkMode) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: () => _showAddOptions(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: widget.isScrolling ? 40 : 50,
                height: widget.isScrolling ? 40 : 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDarkMode
                        ? [
                            Colors.white.withOpacity(0.9),
                            Colors.white.withOpacity(0.7),
                          ]
                        : [
                            Colors.black.withOpacity(0.9),
                            Colors.black.withOpacity(0.7),
                          ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: isDarkMode ? Colors.black : Colors.white,
                  size: widget.isScrolling ? 20 : 24,
                ),
              ),
              if (!widget.isScrolling) const SizedBox(height: 2),
            ],
          ),
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
      widget.onItemTapped(index);
    }
  }

  void _showAddOptions(BuildContext context) {
    final config = ConfigService().config;
    if (config == null || config.sheetIcons.isEmpty) return;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    HapticFeedback.mediumImpact();

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
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.95),
                  ]
                : [
                    Colors.white.withOpacity(0.95),
                    Colors.white.withOpacity(0.9),
                  ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.3) 
                    : Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildSheetActionsGrid(context, config, isDarkMode),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: () {
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDarkMode
                        ? [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.1),
                          ]
                        : [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.2),
                          ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : Colors.black.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ).then((_) {
      refreshManager.setSheetOpen(false);
      debugPrint(
        '📋 DynamicBottomNavigation sheet closed - background refresh/scroll ENABLED',
      );
    });
  }

  Widget _buildSheetActionsGrid(BuildContext context, config, bool isDarkMode) {
    final sheetIcons = config.sheetIcons;

    final List<Widget> rows = [];
    for (int i = 0; i < sheetIcons.length; i += 3) {
      final rowItems = sheetIcons.skip(i).take(3).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rowItems
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
            final refreshManager = Provider.of<RefreshStateManager>(
              context,
              listen: false,
            );
            refreshManager.setSheetOpen(false);
            debugPrint(
              '📋 DynamicBottomNavigation sheet closing via action button - background refresh/scroll ENABLED',
            );

            Navigator.pop(context);

            WebViewService().navigate(
              context,
              url: item.link,
              linkType: item.linkType,
              title: item.title,
            );
          },
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ]
                    : [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.1),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: DynamicIcon(
                iconUrl: item.iconSolid,
                size: 32,
                color: isDarkMode ? Colors.white : Colors.black,
                showLoading: false,
                fallbackIcon: Icon(
                  _getIconForTitle(item.title),
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          item.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
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