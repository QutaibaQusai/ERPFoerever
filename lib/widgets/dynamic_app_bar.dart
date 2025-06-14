// lib/widgets/dynamic_app_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/widgets/header_icon_widget.dart';

class DynamicAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedIndex;
  const DynamicAppBar({super.key, required this.selectedIndex});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final config = ConfigService().config;
    if (config == null || selectedIndex >= config.mainIcons.length) {
      return _buildDefaultAppBar(context);
    }

    final currentItem = config.mainIcons[selectedIndex];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? Colors.white : Colors.black;

    return AppBar(
  centerTitle: false,
  title: Padding(
    padding: const EdgeInsets.only(right: 10.0), 
    child: selectedIndex == 0
        ? SizedBox(
            height: 20,
            child: Image.asset(
              isDarkMode
                  ? "assets/erpforever-white.png"
                  : "assets/header_icon.png",
            ),
          )
        : _buildTitle(context, currentItem.title, titleColor),
  ),
  actions: _buildActions(context, currentItem),
  backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
  elevation: 0,
  iconTheme: IconThemeData(color: titleColor),
);

  }

  Widget _buildTitle(BuildContext context, String title, Color titleColor) {
    return Text(
      title,
      style: GoogleFonts.rubik(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: titleColor,
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, currentItem) {
    final List<Widget> actions = [];

    if (currentItem.headerIcons != null &&
        currentItem.headerIcons!.isNotEmpty) {
      for (final headerIcon in currentItem.headerIcons!) {
        actions.add(
          HeaderIconWidget(
            iconUrl: headerIcon.icon,
            title: headerIcon.title,
            size: 24,
            onTap: () => _handleHeaderIconTap(context, headerIcon),
          ),
        );
      }
    }

    if (actions.isNotEmpty) {
      actions.add(const SizedBox(width: 8));
    }

    return actions;
  }

  void _handleHeaderIconTap(BuildContext context, headerIcon) {
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
}