// lib/widgets/dynamic_bottom_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart'; // Add this package
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
  State<DynamicBottomNavigation> createState() =>
      _DynamicBottomNavigationState();
}

class _DynamicBottomNavigationState extends State<DynamicBottomNavigation>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  late Animation<double> _opacityAnimation;

  // Add splash animation controllers
  Map<int, AnimationController> _splashControllers = {};
  Map<int, Animation<double>> _splashAnimations = {};

  // Tab transition animation
  late AnimationController _tabTransitionController;
  late Animation<double> _tabTransitionAnimation;
  int _previousSelectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousSelectedIndex = widget.selectedIndex;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _heightAnimation = Tween<double>(begin: 90.0, end: 60.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Tab transition animation
    _tabTransitionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _tabTransitionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _tabTransitionController,
        curve: Curves.easeInOutCubic,
      ),
    );
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

    // Trigger tab transition animation when selectedIndex changes
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _previousSelectedIndex = oldWidget.selectedIndex;
      _tabTransitionController.reset();
      _tabTransitionController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabTransitionController.dispose();
    // Dispose all splash controllers
    for (var controller in _splashControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Create splash animation for specific index
  void _createSplashAnimation(int index) {
    if (!_splashControllers.containsKey(index)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );

      final animation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCirc));

      _splashControllers[index] = controller;
      _splashAnimations[index] = animation;
    }
  }

  // Trigger splash animation
  void _triggerSplash(int index) {
    _createSplashAnimation(index);
    final controller = _splashControllers[index]!;
    controller.reset();
    controller.forward();
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.isScrolling ? 25 : 30),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 8, // Reduced blur for more transparency
                sigmaY: 8,
              ),
              child: GlassmorphicContainer(
                width: double.infinity,
                height: _heightAnimation.value,
                borderRadius: widget.isScrolling ? 25 : 30,
                blur: 0,
                alignment: Alignment.bottomCenter,
                border: 0.1, // Even more invisible border
                linearGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isDarkMode
                          ? [
                            Colors.white.withOpacity(0.005), // Almost invisible
                            Colors.white.withOpacity(0.003),
                            Colors.transparent,
                          ]
                          : [
                            Colors.white.withOpacity(0.01), // Barely visible
                            Colors.white.withOpacity(0.005),
                            Colors.transparent,
                          ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isDarkMode
                          ? [
                            Colors.white.withOpacity(0.02),
                            Colors.white.withOpacity(0.01),
                            Colors.transparent,
                          ]
                          : [
                            Colors.white.withOpacity(0.03),
                            Colors.white.withOpacity(0.015),
                            Colors.transparent,
                          ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      widget.isScrolling ? 25 : 30,
                    ),
                    // Remove shadow completely for maximum transparency
                    // boxShadow: [], // Commented out for full transparency
                  ),
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _buildNavigationItems(
                        context,
                        config,
                        isDarkMode,
                      ),
                    ),
                  ),
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

    // Create splash animation for this index
    _createSplashAnimation(index);

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.transparent, // Remove static selection background
        ),
        child: Stack(
          children: [
            // Custom splash animation
            AnimatedBuilder(
              animation: _splashAnimations[index]!,
              builder: (context, child) {
                return Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.transparent,
                    ),
                    child: CustomPaint(
                      painter: SplashPainter(
                        progress: _splashAnimations[index]!.value,
                        color:
                            isDarkMode
                                ? Colors.white.withOpacity(0.3)
                                : Colors.black.withOpacity(0.2),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Main content
            InkWell(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.lightImpact();
                _triggerSplash(index); // Trigger custom splash
                _onItemTapped(context, index, item);
              },
              child: Container(
                width: double.infinity,
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
                        unselectedColor:
                            isDarkMode
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
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color:
                                isSelected
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
          ],
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
                    colors:
                        isDarkMode
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
      builder:
          (context) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 20,
                sigmaY: 20,
              ), // Consistent blur
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.5,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  // Very transparent to show background content
                  color:
                      isDarkMode
                          ? Colors.black.withOpacity(0.2) // Very light
                          : Colors.white.withOpacity(0.3), // Very light
                  border: Border.all(
                    color:
                        isDarkMode
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                    width: 0.3,
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
                        color:
                            isDarkMode
                                ? Colors.white.withOpacity(0.5)
                                : Colors.black.withOpacity(0.5),
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color:
                                  isDarkMode
                                      ? Colors.white.withOpacity(0.15)
                                      : Colors.black.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    isDarkMode
                                        ? Colors.white.withOpacity(0.2)
                                        : Colors.black.withOpacity(0.15),
                                width: 0.3,
                              ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: isDarkMode ? Colors.white : Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color:
                      isDarkMode
                          ? Colors.white.withOpacity(0.15)
                          : Colors.black.withOpacity(0.1),
                  border: Border.all(
                    color:
                        isDarkMode
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.15),
                    width: 0.5,
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

// Custom painter for splash animation
class SplashPainter extends CustomPainter {
  final double progress;
  final Color color;

  SplashPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.6;
    final currentRadius = maxRadius * progress;

    // Create gradient for the ripple effect
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        color.withOpacity(0.4 * (1 - progress)),
        color.withOpacity(0.2 * (1 - progress)),
        color.withOpacity(0.05 * (1 - progress)),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 0.8, 1.0],
    );

    final paint =
        Paint()
          ..shader = gradient.createShader(
            Rect.fromCircle(center: center, radius: currentRadius),
          );

    canvas.drawCircle(center, currentRadius, paint);
  }

  @override
  bool shouldRepaint(covariant SplashPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// Custom painter for tab transition animation
class TabTransitionPainter extends CustomPainter {
  final double progress;
  final int previousIndex;
  final int currentIndex;
  final int itemCount;
  final Color color;
  final bool isScrolling;

  TabTransitionPainter({
    required this.progress,
    required this.previousIndex,
    required this.currentIndex,
    required this.itemCount,
    required this.color,
    required this.isScrolling,
  });

  void paint(Canvas canvas, Size size) {
    if (itemCount == 0) return;

    final itemWidth = size.width / itemCount;
    final indicatorWidth = itemWidth * 0.8;
    final indicatorHeight = isScrolling ? 35.0 : 45.0;

    // Calculate positions
    final previousX =
        (previousIndex * itemWidth) + (itemWidth - indicatorWidth) / 2;
    final currentX =
        (currentIndex * itemWidth) + (itemWidth - indicatorWidth) / 2;

    // Interpolate position
    final currentPosition = previousX + (currentX - previousX) * progress;

    // Interpolate width for stretch effect
    final stretchFactor =
        1.0 +
        (0.3 * (1 - (2 * progress - 1).abs())); // Creates stretch in middle
    final currentWidth = indicatorWidth * stretchFactor;

    // Center the stretched indicator
    final adjustedX = currentPosition - (currentWidth - indicatorWidth) / 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        adjustedX,
        (size.height - indicatorHeight) / 2,
        currentWidth,
        indicatorHeight,
      ),
      Radius.circular(isScrolling ? 17 : 22),
    );

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant TabTransitionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.previousIndex != previousIndex ||
        oldDelegate.currentIndex != currentIndex ||
        oldDelegate.itemCount != itemCount ||
        oldDelegate.isScrolling != isScrolling;
  }
}
