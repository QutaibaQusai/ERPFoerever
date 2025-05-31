// lib/services/refresh_state_manager.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RefreshStateManager extends ChangeNotifier {
  static final RefreshStateManager _instance = RefreshStateManager._internal();
  factory RefreshStateManager() => _instance;
  RefreshStateManager._internal();

  bool _isSheetOpen = false;
  bool _isRefreshEnabled = true;
  final List<WebViewController> _activeControllers = [];

  bool get isSheetOpen => _isSheetOpen;
  bool get isRefreshEnabled => _isRefreshEnabled && !_isSheetOpen;

  /// Register a WebView controller to receive refresh state updates
  void registerController(WebViewController controller) {
    if (!_activeControllers.contains(controller)) {
      _activeControllers.add(controller);
      // Delay the state update to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateControllerRefreshState(controller);
      });
    }
  }

  /// Unregister a WebView controller
  void unregisterController(WebViewController controller) {
    _activeControllers.remove(controller);
  }

  /// Call this when opening a WebViewSheet
  void setSheetOpen(bool isOpen) {
    if (_isSheetOpen != isOpen) {
      _isSheetOpen = isOpen;
      debugPrint('📋 Sheet state changed: ${isOpen ? "OPEN" : "CLOSED"}');
      debugPrint('🔄 Refresh enabled: ${isRefreshEnabled && !_isSheetOpen}');
      
      // Delay the state updates to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateAllControllersRefreshState();
        notifyListeners();
      });
    }
  }

  /// Check if refresh should be allowed
  bool shouldAllowRefresh() {
    final allowed = _isRefreshEnabled && !_isSheetOpen;
    debugPrint('🔄 Refresh check: $allowed (enabled: $_isRefreshEnabled, sheet: $_isSheetOpen)');
    return allowed;
  }

  /// Update refresh state in JavaScript for a specific controller
  void _updateControllerRefreshState(WebViewController controller) {
    try {
      final blocked = !shouldAllowRefresh();
      controller.runJavaScript('''
        if (typeof window.setRefreshBlocked === 'function') {
          window.setRefreshBlocked($blocked);
          console.log('🔄 JavaScript refresh state updated: ${blocked ? "BLOCKED" : "ALLOWED"}');
        }
      ''');
    } catch (e) {
      debugPrint('❌ Error updating controller refresh state: $e');
    }
  }

  /// Update refresh state in JavaScript for all controllers
  void _updateAllControllersRefreshState() {
    for (final controller in _activeControllers) {
      _updateControllerRefreshState(controller);
    }
  }
}