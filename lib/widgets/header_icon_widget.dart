// lib/widgets/header_icon_widget.dart
import 'package:flutter/material.dart';
import 'package:ERPForever/widgets/dynamic_icon.dart';

class HeaderIconWidget extends StatelessWidget {
  final String iconUrl;
  final String title;
  final VoidCallback onTap;
  final double size;

  const HeaderIconWidget({
    super.key,
    required this.iconUrl,
    required this.title,
    required this.onTap,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return IconButton(
      onPressed: onTap,
      tooltip: title,
      icon: DynamicIcon(
        iconUrl: iconUrl,
        size: size,
        color: isDarkMode ? Colors.white : Colors.black,
        showLoading: false,
        fallbackIcon: Icon(
          Icons.widgets_outlined,
          size: size,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}