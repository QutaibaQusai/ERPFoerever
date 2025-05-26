// lib/widgets/screenshot_wrapper.dart
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:ERPForever/services/screenshot_service.dart';

class ScreenshotWrapper extends StatelessWidget {
  final Widget child;
  
  const ScreenshotWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: ScreenshotService().controller,
      child: child,
    );
  }
}