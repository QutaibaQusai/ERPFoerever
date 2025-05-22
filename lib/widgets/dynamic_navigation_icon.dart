// lib/widgets/dynamic_navigation_icon.dart
import 'package:flutter/material.dart';
import 'package:ERPForever/widgets/dynamic_icon.dart';

class DynamicNavigationIcon extends StatelessWidget {
  final String iconLineUrl;
  final String iconSolidUrl;
  final bool isSelected;
  final double size;
  final Color? selectedColor;
  final Color? unselectedColor;

  const DynamicNavigationIcon({
    super.key,
    required this.iconLineUrl,
    required this.iconSolidUrl,
    required this.isSelected,
    this.size = 24.0,
    this.selectedColor,
    this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconUrl = isSelected ? iconSolidUrl : iconLineUrl;
    final iconColor = isSelected 
        ? (selectedColor ?? Theme.of(context).primaryColor)
        : (unselectedColor ?? Colors.grey);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: DynamicIcon(
        key: ValueKey('${iconUrl}_$isSelected'),
        iconUrl: iconUrl,
        size: size,
        color: iconColor,
        showLoading: false,
        fallbackIcon: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          size: size,
          color: iconColor,
        ),
      ),
    );
  }
}