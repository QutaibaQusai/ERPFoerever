// lib/widgets/loading_widget.dart
import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final String message;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final Color? textColor;
  
  const LoadingWidget({
    super.key,
    this.message = "Loading...",
    this.backgroundColor,
    this.indicatorColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      color: backgroundColor ?? (isDarkMode ? Colors.black : Colors.white),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                indicatorColor ?? (isDarkMode ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: textColor ?? (isDarkMode ? Colors.white : Colors.black),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}