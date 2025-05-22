// lib/services/webview_service.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ERPForever/models/link_types.dart';
import 'package:ERPForever/pages/webview_page.dart';
import 'package:ERPForever/widgets/webview_sheet.dart';

class WebViewService {
  static final WebViewService _instance = WebViewService._internal();
  factory WebViewService() => _instance;
  WebViewService._internal();

  void navigate(
    BuildContext context, {
    required String url,
    required String linkType,
    String? title,
  }) {
    final type = LinkType.fromString(linkType);
    
    switch (type) {
      case LinkType.regularWebview:
        _navigateToRegularWebView(context, url, title ?? 'Web View');
        break;
      case LinkType.sheetWebview:
        _showWebViewSheet(context, url, title ?? 'Web View');
        break;
    }
  }

  void _navigateToRegularWebView(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewPage(
          url: url,
          title: title,
        ),
      ),
    );
  }

  void _showWebViewSheet(BuildContext context, String url, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WebViewSheet(
        url: url,
        title: title,
      ),
    );
  }

  WebViewController createController(String url) {
    // Create the controller first
    final controller = WebViewController();
    
    // Configure the controller
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'BarcodeScanner',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('Barcode message: ${message.message}');
        },
      )
      ..addJavaScriptChannel(
        'ThemeManager',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('Theme message: ${message.message}');
        },
      )
      ..addJavaScriptChannel(
        'AlertManager',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('Alert message: ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            _injectJavaScript(controller);
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('Navigation request: ${request.url}');
            return _handleNavigationRequest(request);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Web resource error: ${error.description}');
          },
        ),
      );

    // Load the URL
    controller.loadRequest(Uri.parse(url));
    
    return controller;
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    if (request.url.startsWith('dark-mode://') ||
        request.url.startsWith('light-mode://') ||
        request.url.startsWith('system-mode://') ||
        request.url.startsWith('new-web://') ||
        request.url.startsWith('new-sheet://') ||
        request.url.contains('barcode') ||
        request.url.contains('scan')) {
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _injectJavaScript(WebViewController controller) {
    controller.runJavaScript('''
      document.addEventListener('click', function(e) {
        let element = e.target;
        for (let i = 0; i < 4 && element; i++) {
          const href = element.getAttribute('href');
          if (href) {
            if (href.startsWith('dark-mode://')) {
              e.preventDefault();
              window.ThemeManager.postMessage('dark');
              return false;
            } else if (href.startsWith('light-mode://')) {
              e.preventDefault();
              window.ThemeManager.postMessage('light');
              return false;
            } else if (href.startsWith('system-mode://')) {
              e.preventDefault();
              window.ThemeManager.postMessage('system');
              return false;
            }
          }
          element = element.parentElement;
        }
      }, true);

      window.handleBarcodeResult = function(result) {
        if (typeof getBarcode === 'function') {
          getBarcode(result);
        } else {
          var inputs = document.querySelectorAll('input[type="text"]');
          if(inputs.length > 0) {
            inputs[0].value = result;
            inputs[0].dispatchEvent(new Event('input'));
          }
        }
      };

      console.log("Dynamic WebView JavaScript initialized");
    ''');
  }
}