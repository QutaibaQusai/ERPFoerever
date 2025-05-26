// lib/services/webview_service.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ERPForever/models/link_types.dart';
import 'package:ERPForever/pages/webview_page.dart';
import 'package:ERPForever/pages/barcode_scanner_page.dart';
import 'package:ERPForever/pages/login_page.dart';
import 'package:ERPForever/widgets/webview_sheet.dart';
import 'package:ERPForever/services/theme_service.dart';
import 'package:ERPForever/services/auth_service.dart';

class WebViewService {
  static final WebViewService _instance = WebViewService._internal();
  factory WebViewService() => _instance;
  WebViewService._internal();

  BuildContext? _currentContext;
  WebViewController? _currentController;

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

  WebViewController createController(String url, [BuildContext? context]) {
    // Store context for theme changes, scanner, and logout
    _currentContext = context;
    
    // Create the controller first
    final controller = WebViewController();
    _currentController = controller;
    
    // Configure the controller
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'BarcodeScanner',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('Barcode message: ${message.message}');
          _handleBarcodeRequest(message.message);
        },
      )
      ..addJavaScriptChannel(
        'ThemeManager',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('Theme message: ${message.message}');
          _handleThemeChange(message.message);
        },
      )
      ..addJavaScriptChannel(
        'AuthManager',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('Auth message: ${message.message}');
          _handleAuthRequest(message.message);
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
    // Handle theme change requests
    if (request.url.startsWith('dark-mode://')) {
      _handleThemeChange('dark');
      return NavigationDecision.prevent;
    } else if (request.url.startsWith('light-mode://')) {
      _handleThemeChange('light');
      return NavigationDecision.prevent;
    } else if (request.url.startsWith('system-mode://')) {
      _handleThemeChange('system');
      return NavigationDecision.prevent;
    } 
    // Handle logout requests
    else if (request.url.startsWith('logout://')) {
      _handleAuthRequest('logout');
      return NavigationDecision.prevent;
    }
    // Handle barcode scanning requests
    else if (request.url.contains('barcode') || request.url.contains('scan')) {
      bool isContinuous = request.url.contains('continuous');
      _handleBarcodeRequest(isContinuous ? 'scanContinuous' : 'scan');
      return NavigationDecision.prevent;
    }
    else if (request.url.startsWith('new-web://') ||
               request.url.startsWith('new-sheet://')) {
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _handleAuthRequest(String message) {
    if (_currentContext == null) {
      debugPrint('❌ No context available for auth request');
      return;
    }

    if (message == 'logout') {
      debugPrint('🚪 Logout requested from WebView');
      _performLogout();
    }
  }

  void _performLogout() async {
    if (_currentContext == null) {
      debugPrint('❌ No context available for logout');
      return;
    }

    try {
      // Get the AuthService and logout
      final authService = Provider.of<AuthService>(_currentContext!, listen: false);
      await authService.logout();

      debugPrint('✅ User logged out successfully');

      // Show feedback
      ScaffoldMessenger.of(_currentContext!).hideCurrentSnackBar();
      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate to login page and clear navigation stack
      Navigator.of(_currentContext!).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
        (route) => false, // Remove all previous routes
      );

    } catch (e) {
      debugPrint('❌ Error during logout: $e');
      
      // Show error message
      ScaffoldMessenger.of(_currentContext!).hideCurrentSnackBar();
      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        const SnackBar(
          content: Text('Error during logout'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleBarcodeRequest(String message) {
    if (_currentContext == null) {
      debugPrint('❌ No context available for barcode scanning');
      return;
    }

    bool isContinuous = message == 'scanContinuous';
    
    debugPrint('📸 Starting barcode scan - Continuous: $isContinuous');
    
    Navigator.push(
      _currentContext!,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => BarcodeScannerPage(
          isContinuous: isContinuous,
          onBarcodeScanned: (String barcode) {
            _sendBarcodeToWebView(barcode, isContinuous);
          },
        ),
      ),
    );
  }

  void _sendBarcodeToWebView(String barcode, bool isContinuous) {
    if (_currentController == null) {
      debugPrint('❌ No WebView controller available for barcode result');
      return;
    }

    debugPrint('📱 Sending barcode to WebView: $barcode (Continuous: $isContinuous)');

    if (isContinuous) {
      // For continuous scanning, call getBarcodeContinuous first
      _currentController!.runJavaScript('''
        try {
          if (typeof getBarcodeContinuous === 'function') {
            getBarcodeContinuous("$barcode");
            console.log("✅ Called getBarcodeContinuous() with: $barcode");
          } else if (typeof getBarcode === 'function') {
            getBarcode("$barcode");
            console.log("✅ getBarcodeContinuous() not found, called getBarcode() with: $barcode");
          } else if (typeof window.handleContinuousBarcodeResult === 'function') {
            window.handleContinuousBarcodeResult("$barcode");
            console.log("✅ Called window.handleContinuousBarcodeResult with: $barcode");
          } else {
            // Fallback: fill first text input
            var inputs = document.querySelectorAll('input[type="text"]');
            if(inputs.length > 0) {
              inputs[0].value = "$barcode";
              inputs[0].dispatchEvent(new Event('input'));
              inputs[0].dispatchEvent(new Event('change'));
              console.log("✅ Filled input field with: $barcode (continuous mode)");
            }
            
            // Trigger custom event for continuous
            var event = new CustomEvent('barcodeScanned', { 
              detail: { result: "$barcode", continuous: true } 
            });
            document.dispatchEvent(event);
            console.log("✅ Triggered continuous barcodeScanned event with: $barcode");
          }
        } catch (error) {
          console.error("❌ Error handling continuous barcode result:", error);
        }
      ''');
    } else {
      // For normal scanning, call getBarcode
      _currentController!.runJavaScript('''
        try {
          if (typeof getBarcode === 'function') {
            getBarcode("$barcode");
            console.log("✅ Called getBarcode() with: $barcode");
          } else if (typeof window.handleBarcodeResult === 'function') {
            window.handleBarcodeResult("$barcode");
            console.log("✅ Called window.handleBarcodeResult with: $barcode");
          } else {
            // Fallback: fill first text input
            var inputs = document.querySelectorAll('input[type="text"]');
            if(inputs.length > 0) {
              inputs[0].value = "$barcode";
              inputs[0].dispatchEvent(new Event('input'));
              inputs[0].dispatchEvent(new Event('change'));
              console.log("✅ Filled input field with: $barcode (normal mode)");
            }
            
            // Trigger custom event for normal
            var event = new CustomEvent('barcodeScanned', { 
              detail: { result: "$barcode", continuous: false } 
            });
            document.dispatchEvent(event);
            console.log("✅ Triggered normal barcodeScanned event with: $barcode");
          }
        } catch (error) {
          console.error("❌ Error handling normal barcode result:", error);
        }
      ''');
    }
  }

  void _handleThemeChange(String themeMode) {
    if (_currentContext != null) {
      final themeService = Provider.of<ThemeService>(_currentContext!, listen: false);
      themeService.updateThemeMode(themeMode);
      
      debugPrint('🎨 Theme changed to: $themeMode');
      
      // Show feedback to user
      ScaffoldMessenger.of(_currentContext!).hideCurrentSnackBar();
      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        SnackBar(
          content: Text('Theme changed to ${_capitalize(themeMode)} mode'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      debugPrint('❌ No context available for theme change');
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return "${text[0].toUpperCase()}${text.substring(1)}";
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
              console.log('Dark mode requested');
              window.ThemeManager.postMessage('dark');
              return false;
            } else if (href.startsWith('light-mode://')) {
              e.preventDefault();
              console.log('Light mode requested');
              window.ThemeManager.postMessage('light');
              return false;
            } else if (href.startsWith('system-mode://')) {
              e.preventDefault();
              console.log('System mode requested');
              window.ThemeManager.postMessage('system');
              return false;
            } else if (href.startsWith('logout://')) {
              e.preventDefault();
              console.log('Logout requested');
              window.AuthManager.postMessage('logout');
              return false;
            }
          }
          element = element.parentElement;
        }
      }, true);

      // Enhanced barcode handling
      document.addEventListener('click', function(e) {
        let element = e.target;
        for (let i = 0; i < 4 && element; i++) {
          if (element.getAttribute('href')?.includes('barcode') || 
              element.getAttribute('href')?.includes('scan') ||
              element.id?.includes('barcode') ||
              element.id?.includes('scan') ||
              element.className?.includes('barcode') ||
              element.className?.includes('scan')) {
            e.preventDefault();
            
            // Check if continuous scanning is requested
            if (element.getAttribute('href')?.includes('continuous') || 
                element.id?.includes('continuous') ||
                element.className?.includes('continuous')) {
              console.log('📸 Continuous barcode scan requested');
              window.BarcodeScanner.postMessage('scanContinuous');
            } else {
              console.log('📸 Normal barcode scan requested');
              window.BarcodeScanner.postMessage('scan');
            }
            return false;
          }
          element = element.parentElement;
        }
      }, true);

      // Enhanced logout handling
      document.addEventListener('click', function(e) {
        let element = e.target;
        for (let i = 0; i < 4 && element; i++) {
          // Check for logout button/link
          if (element.getAttribute('href')?.includes('logout') ||
              element.id?.includes('logout') ||
              element.className?.includes('logout') ||
              element.textContent?.toLowerCase().includes('logout') ||
              element.textContent?.toLowerCase().includes('log out') ||
              element.textContent?.toLowerCase().includes('sign out')) {
            e.preventDefault();
            console.log('🚪 Logout button clicked');
            window.AuthManager.postMessage('logout');
            return false;
          }
          element = element.parentElement;
        }
      }, true);

      // Barcode result handlers (for reference - these are called from Flutter)
      window.handleBarcodeResult = function(result) {
        console.log("📱 Normal barcode result received: " + result);
        
        if (typeof getBarcode === 'function') {
          console.log("Calling getBarcode() with result: " + result);
          getBarcode(result);
        } else {
          console.log("getBarcode() function not found, using fallback");
          var barcodeInputs = document.querySelectorAll('input[type="text"]');
          if(barcodeInputs.length > 0) {
            barcodeInputs[0].value = result;
            barcodeInputs[0].dispatchEvent(new Event('input'));
            barcodeInputs[0].dispatchEvent(new Event('change'));
          }
          
          var event = new CustomEvent('barcodeScanned', { detail: { result: result, continuous: false } });
          document.dispatchEvent(event);
        }
      };
      
      window.handleContinuousBarcodeResult = function(result) {
        console.log("📱 Continuous barcode result received: " + result);
        
        if (typeof getBarcodeContinuous === 'function') {
          console.log("Calling getBarcodeContinuous() with result: " + result);
          getBarcodeContinuous(result);
        } else if (typeof getBarcode === 'function') {
          console.log("getBarcodeContinuous() not found, falling back to getBarcode");
          getBarcode(result);
        } else {
          console.log("No barcode functions found, using fallback");
          var barcodeInputs = document.querySelectorAll('input[type="text"]');
          if(barcodeInputs.length > 0) {
            barcodeInputs[0].value = result;
            barcodeInputs[0].dispatchEvent(new Event('input'));
            barcodeInputs[0].dispatchEvent(new Event('change'));
          }
          
          var event = new CustomEvent('barcodeScanned', { detail: { result: result, continuous: true } });
          document.dispatchEvent(event);
        }
      };

      console.log("✅ Dynamic WebView JavaScript initialized with logout, barcode, and theme support");
    ''');
  }

  // Update context when creating controllers
  void updateContext(BuildContext context) {
    _currentContext = context;
  }
}