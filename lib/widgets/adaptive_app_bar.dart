// lib/widgets/adaptive_app_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/widgets/header_icon_widget.dart';

class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedIndex;
  final bool showLogo;
  final String? customTitle;
  
  const AdaptiveAppBar({
    super.key,
    required this.selectedIndex,
    this.showLogo = false,
    this.customTitle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final config = ConfigService().config;
    if (config == null) return _buildFallbackAppBar(context);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      centerTitle: false,
      title: _buildAdaptiveTitle(context, isDarkMode),
      actions: _buildAdaptiveActions(context, selectedIndex),
      backgroundColor: isDarkMode ? _hexToColor(config.theme.darkSurface) : Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildAdaptiveTitle(BuildContext context, bool isDarkMode) {
    if (showLogo) {
      return Container(
        height: 20,
        child: Image.asset(
          isDarkMode ? "assets/erpforever-white.png" : "assets/header_icon.png",
          errorBuilder: (context, error, stackTrace) => Text(
            customTitle ?? 'ERPForever',
            style: GoogleFonts.rubik(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
      );
    }

    return Text(
      customTitle ?? 'ERPForever',
      style: GoogleFonts.rubik(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }

  List<Widget> _buildAdaptiveActions(BuildContext context, int selectedIndex) {
    final config = ConfigService().config;
    if (config == null || selectedIndex >= config.mainIcons.length) {
      return [];
    }

    final currentItem = config.mainIcons[selectedIndex];
    final List<Widget> actions = [];

    if (currentItem.headerIcons != null) {
      for (final headerIcon in currentItem.headerIcons!) {
        actions.add(
          HeaderIconWidget(
            iconUrl: headerIcon.icon,
            title: headerIcon.title,
            size: 24,
            onTap: () {
              WebViewService().navigate(
                context,
                url: headerIcon.link,
                linkType: headerIcon.linkType,
                title: headerIcon.title,
              );
            },
          ),
        );
      }
    }

    return actions;
  }

  AppBar _buildFallbackAppBar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      title: Text(
        'ERPForever',
        style: GoogleFonts.rubik(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
    );
  }

  Color _hexToColor(String hexColor) {
    return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  }
}