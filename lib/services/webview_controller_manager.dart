// lib/services/webview_controller_manager.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ERPForever/services/webview_service.dart';

class WebViewControllerManager {
  static final WebViewControllerManager _instance = WebViewControllerManager._internal();
  factory WebViewControllerManager() => _instance;
  WebViewControllerManager._internal();

  final Map<int, WebViewController> _controllers = {};
  final Map<int, bool> _loadingStates = {};

  WebViewController getController(int index, String url, [BuildContext? context]) {
    if (!_controllers.containsKey(index)) {
      // Pass context to the WebViewService for theme handling
      _controllers[index] = WebViewService().createController(url, context);
      _loadingStates[index] = true;
    } else if (context != null) {
      // Update context if controller already exists
      WebViewService().updateContext(context);
    }
    return _controllers[index]!;
  }

  void setLoadingState(int index, bool isLoading) {
    _loadingStates[index] = isLoading;
  }

  bool getLoadingState(int index) {
    return _loadingStates[index] ?? true;
  }

  void updateController(int index, String newUrl) {
    if (_controllers.containsKey(index)) {
      _controllers[index]!.loadRequest(Uri.parse(newUrl));
    }
  }

  void clearControllers() {
    _controllers.clear();
    _loadingStates.clear();
  }

  void clearController(int index) {
    _controllers.remove(index);
    _loadingStates.remove(index);
  }
}