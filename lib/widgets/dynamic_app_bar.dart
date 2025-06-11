// lib/widgets/dynamic_app_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;
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

class _DynamicAppBarState extends State<DynamicAppBar>
    with TickerProviderStateMixin {
  late AnimationController _specularController;
  late Animation<double> _specularAnimation;

  @override
  void initState() {
    super.initState();
    // Real-time specular highlights animation
    _specularController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    _specularAnimation = Tween<double>(
      begin: 0.0,
      end: 2.0 * math.pi,
    ).animate(CurvedAnimation(
      parent: _specularController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _specularController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigService().config;
    if (config == null || widget.selectedIndex >= config.mainIcons.length) {
      return _buildDefaultAppBar(context);
    }

    final currentItem = config.mainIcons[widget.selectedIndex];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _specularAnimation,
      builder: (context, child) {
        return Container(
          decoration: _buildLiquidGlassDecoration(isDarkMode),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: AppBar(
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
                  statusBarColor: Colors.transparent,
                ),
                centerTitle: false,
                title: Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: widget.selectedIndex == 0
                      ? _buildLiquidGlassLogo(isDarkMode)
                      : _buildLiquidGlassTitle(context, currentItem.title, isDarkMode),
                ),
                actions: _buildLiquidGlassActions(context, currentItem, isDarkMode),
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                iconTheme: IconThemeData(
                  color: isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8),
                ),
                toolbarHeight: kToolbarHeight + 10,
                surfaceTintColor: Colors.transparent,
              ),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _buildLiquidGlassDecoration(bool isDarkMode) {
    // Apple's official Liquid Glass: translucent material that reflects surroundings
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDarkMode
            ? [
                Colors.black.withOpacity(0.15),
                Colors.black.withOpacity(0.05),
                Colors.white.withOpacity(0.02),
                Colors.white.withOpacity(0.08),
              ]
            : [
                Colors.white.withOpacity(0.85),
                Colors.white.withOpacity(0.75),
                Colors.white.withOpacity(0.65),
                Colors.white.withOpacity(0.70),
              ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ),
      // Real-time specular highlights
      boxShadow: [
        BoxShadow(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1 + 0.05 * math.sin(_specularAnimation.value))
              : Colors.white.withOpacity(0.3 + 0.2 * math.sin(_specularAnimation.value)),
          blurRadius: 25,
          offset: Offset(
            10 * math.cos(_specularAnimation.value),
            5 * math.sin(_specularAnimation.value),
          ),
        ),
        BoxShadow(
          color: isDarkMode
              ? Colors.black.withOpacity(0.4)
              : Colors.black.withOpacity(0.02),
          blurRadius: 15,
          offset: const Offset(0, 2),
        ),
      ],
      border: Border(
        top: BorderSide(
          color: isDarkMode
              ? Colors.white.withOpacity(0.15)
              : Colors.white.withOpacity(0.8),
          width: 0.5,
        ),
        bottom: BorderSide(
          color: isDarkMode
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
          width: 0.5,
        ),
      ),
    );
  }

  Widget _buildLiquidGlassLogo(bool isDarkMode) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        // Multiple layers of Liquid Glass as per Apple specs
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.02),
                  Colors.white.withOpacity(0.08),
                ]
              : [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                  Colors.white.withOpacity(0.5),
                  Colors.white.withOpacity(0.6),
                ],
        ),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.9),
          width: 0.5,
        ),
        boxShadow: [
          // Dynamic specular highlights
          BoxShadow(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1 + 0.05 * math.sin(_specularAnimation.value + 1))
                : Colors.white.withOpacity(0.8 + 0.1 * math.sin(_specularAnimation.value + 1)),
            blurRadius: 8,
            offset: Offset(
              3 * math.cos(_specularAnimation.value + 1),
              2 * math.sin(_specularAnimation.value + 1),
            ),
          ),
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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

  Widget _buildLiquidGlassTitle(BuildContext context, String title, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // Apple's translucent material specification
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                  Colors.white.withOpacity(0.01),
                  Colors.white.withOpacity(0.06),
                ]
              : [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                  Colors.white.withOpacity(0.75),
                  Colors.white.withOpacity(0.80),
                ],
        ),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.15)
              : Colors.white.withOpacity(0.95),
          width: 0.5,
        ),
        boxShadow: [
          // Real-time rendering specular highlights
          BoxShadow(
            color: isDarkMode
                ? Colors.white.withOpacity(0.08 + 0.04 * math.sin(_specularAnimation.value + 0.5))
                : Colors.white.withOpacity(0.6 + 0.2 * math.sin(_specularAnimation.value + 0.5)),
            blurRadius: 15,
            offset: Offset(
              5 * math.cos(_specularAnimation.value + 0.5),
              3 * math.sin(_specularAnimation.value + 0.5),
            ),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Text(
            title,
            style: GoogleFonts.rubik(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.95)
                  : Colors.black.withOpacity(0.85),
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLiquidGlassActions(BuildContext context, currentItem, bool isDarkMode) {
    final List<Widget> actions = [];

    if (currentItem.headerIcons != null && currentItem.headerIcons!.isNotEmpty) {
      for (int i = 0; i < currentItem.headerIcons!.length; i++) {
        final headerIcon = currentItem.headerIcons![i];
        actions.add(
          Padding(
            padding: EdgeInsets.only(
              left: 6,
              right: i == currentItem.headerIcons!.length - 1 ? 12 : 0,
            ),
            child: _buildLiquidGlassIconButton(
              context,
              headerIcon,
              isDarkMode,
              i,
            ),
          ),
        );
      }
    }

    return actions;
  }

  Widget _buildLiquidGlassIconButton(BuildContext context, headerIcon, bool isDarkMode, int index) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // Apple's official Liquid Glass with multiple layers
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                  Colors.white.withOpacity(0.10),
                ]
              : [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                  Colors.white.withOpacity(0.70),
                  Colors.white.withOpacity(0.80),
                ],
        ),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.25)
              : Colors.white.withOpacity(0.95),
          width: 0.5,
        ),
        boxShadow: [
          // Dynamic specular highlights that react to movement
          BoxShadow(
            color: isDarkMode
                ? Colors.white.withOpacity(0.12 + 0.08 * math.sin(_specularAnimation.value + index))
                : Colors.white.withOpacity(0.7 + 0.2 * math.sin(_specularAnimation.value + index)),
            blurRadius: 12,
            offset: Offset(
              4 * math.cos(_specularAnimation.value + index),
              2 * math.sin(_specularAnimation.value + index),
            ),
          ),
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              splashColor: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.03),
              highlightColor: isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.01),
              onTap: () => _handleHeaderIconTap(context, headerIcon),
              child: Container(
                padding: const EdgeInsets.all(8),
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
    // Premium haptic feedback
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
      flexibleSpace: AnimatedBuilder(
        animation: _specularAnimation,
        builder: (context, child) {
          return Container(
            decoration: _buildLiquidGlassDecoration(isDarkMode),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(color: Colors.transparent),
              ),
            ),
          );
        },
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDarkMode
                ? [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.04),
                  ]
                : [
                    Colors.white.withOpacity(0.95),
                    Colors.white.withOpacity(0.85),
                  ],
          ),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.95),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Text(
              'ERPForever',
              style: GoogleFonts.rubik(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode
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