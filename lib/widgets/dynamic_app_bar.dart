// lib/widgets/dynamic_app_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/widgets/header_icon_widget.dart';

class DynamicAppBar extends StatefulWidget implements PreferredSizeWidget {
  final int selectedIndex;
  const DynamicAppBar({super.key, required this.selectedIndex});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);

  @override
  State<DynamicAppBar> createState() => _DynamicAppBarState();
}

class _DynamicAppBarState extends State<DynamicAppBar> {
  @override
  Widget build(BuildContext context) {
    final config = ConfigService().config;
    if (config == null || widget.selectedIndex >= config.mainIcons.length) {
      return _buildDefaultAppBar(context);
    }

    final currentItem = config.mainIcons[widget.selectedIndex];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ), // Matching navigation bar blur
        child: Container(
          decoration: BoxDecoration(
            // Pure transparency like navigation bar - no background color at all
            color: Colors.transparent,
            // Remove border completely for maximum transparency
            border: null,
            boxShadow: [], // No shadow for liquid glass effect
          ),
          child: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarBrightness:
                  isDarkMode ? Brightness.dark : Brightness.light,
              statusBarColor: Colors.transparent,
            ),
            centerTitle: false,
            title: Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child:
                  widget.selectedIndex == 0
                      ? _buildPureLiquidGlassLogo(isDarkMode)
                      : _buildPureLiquidGlassTitle(
                        context,
                        currentItem.title,
                        isDarkMode,
                      ),
            ),
            actions: _buildPureLiquidGlassActions(
              context,
              currentItem,
              isDarkMode,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(
              color:
                  isDarkMode
                      ? Colors.white.withOpacity(0.9)
                      : Colors.black.withOpacity(0.8),
            ),
            toolbarHeight: kToolbarHeight + 10,
            surfaceTintColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildPureLiquidGlassLogo(bool isDarkMode) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ), // Consistent with navigation
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            // Exact same transparency gradient as navigation bar
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  isDarkMode
                      ? [
                        Colors.white.withOpacity(
                          0.02,
                        ), // Almost completely transparent
                        Colors.white.withOpacity(0.01),
                        Colors.transparent,
                      ]
                      : [
                        Colors.white.withOpacity(
                          0.05,
                        ), // Barely there white tint
                        Colors.white.withOpacity(0.02),
                        Colors.transparent,
                      ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color:
                  isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.08),
              width: 0.2, // Almost invisible border like navigation
            ),
          ),
          child: Image.asset(
            isDarkMode
                ? "assets/erpforever-white.png"
                : "assets/header_icon.png",
            height: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildPureLiquidGlassTitle(
    BuildContext context,
    String title,
    bool isDarkMode,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ), // Consistent with navigation
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // Exact same liquid glass gradient as navigation bar
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  isDarkMode
                      ? [
                        Colors.white.withOpacity(
                          0.02,
                        ), // Almost completely transparent
                        Colors.white.withOpacity(0.01),
                        Colors.transparent,
                      ]
                      : [
                        Colors.white.withOpacity(
                          0.05,
                        ), // Barely there white tint
                        Colors.white.withOpacity(0.02),
                        Colors.transparent,
                      ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color:
                  isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.08),
              width: 0.2, // Almost invisible border
            ),
          ),
          child: Text(
            title,
            style: GoogleFonts.rubik(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color:
                  isDarkMode
                      ? Colors.white.withOpacity(0.95)
                      : Colors.black.withOpacity(0.85),
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPureLiquidGlassActions(
    BuildContext context,
    currentItem,
    bool isDarkMode,
  ) {
    final List<Widget> actions = [];

    if (currentItem.headerIcons != null &&
        currentItem.headerIcons!.isNotEmpty) {
      for (int i = 0; i < currentItem.headerIcons!.length; i++) {
        final headerIcon = currentItem.headerIcons![i];
        actions.add(
          Padding(
            padding: EdgeInsets.only(
              left: 6,
              right: i == currentItem.headerIcons!.length - 1 ? 12 : 0,
            ),
            child: _buildPureLiquidGlassIconButton(
              context,
              headerIcon,
              isDarkMode,
            ),
          ),
        );
      }
    }

    return actions;
  }

  Widget _buildPureLiquidGlassIconButton(
    BuildContext context,
    headerIcon,
    bool isDarkMode,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ), // Consistent with navigation
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // Pure liquid glass gradient matching navigation exactly
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  isDarkMode
                      ? [
                        Colors.white.withOpacity(
                          0.02,
                        ), // Almost completely transparent
                        Colors.white.withOpacity(0.01),
                        Colors.transparent,
                      ]
                      : [
                        Colors.white.withOpacity(
                          0.05,
                        ), // Barely there white tint
                        Colors.white.withOpacity(0.02),
                        Colors.transparent,
                      ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color:
                  isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.08),
              width: 0.2, // Almost invisible borders
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () => _handleHeaderIconTap(context, headerIcon),
              child: Container(
                padding: const EdgeInsets.all(2),
                child: HeaderIconWidget(
                  iconUrl: headerIcon.icon,
                  title: headerIcon.title,
                  size: 20,
                  onTap: () => _handleHeaderIconTap(context, headerIcon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleHeaderIconTap(BuildContext context, headerIcon) {
    // Same haptic feedback as navigation
    HapticFeedback.lightImpact();

    WebViewService().navigate(
      context,
      url: headerIcon.link,
      linkType: headerIcon.linkType,
      title: headerIcon.title,
    );
  }

  AppBar _buildDefaultAppBar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Consistent blur
          child: Container(
            decoration: BoxDecoration(
              // Pure transparency for liquid glass effect - no background at all
              color: Colors.transparent,
              border: null, // Remove border completely
            ),
          ),
        ),
      ),
      title: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              // Same liquid glass gradient as navigation
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors:
                    isDarkMode
                        ? [
                          Colors.white.withOpacity(
                            0.02,
                          ), // Almost completely transparent
                          Colors.white.withOpacity(0.01),
                          Colors.transparent,
                        ]
                        : [
                          Colors.white.withOpacity(
                            0.05,
                          ), // Barely there white tint
                          Colors.white.withOpacity(0.02),
                          Colors.transparent,
                        ],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(
                color:
                    isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.08),
                width: 0.2,
              ),
            ),
            child: Text(
              'ERPForever',
              style: GoogleFonts.rubik(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color:
                    isDarkMode
                        ? Colors.white.withOpacity(0.95)
                        : Colors.black.withOpacity(0.85),
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: kToolbarHeight + 10,
      surfaceTintColor: Colors.transparent,
    );
  }
}
