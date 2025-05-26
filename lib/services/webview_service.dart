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
import 'package:ERPForever/services/location_service.dart';
import 'package:ERPForever/services/contacts_service.dart';

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
    debugPrint('🌐 Creating WebView controller for: $url');
    
    // Store context for interactions
    _currentContext = context;
    
    // Create the controller
    final controller = WebViewController();
    _currentController = controller;
    
    // Configure the controller
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'BarcodeScanner',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('📸 Barcode message: ${message.message}');
          _handleBarcodeRequest(message.message);
        },
      )
      ..addJavaScriptChannel(
        'ThemeManager',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('🎨 Theme message: ${message.message}');
          _handleThemeChange(message.message);
        },
      )
      ..addJavaScriptChannel(
        'AuthManager',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('🚪 Auth message: ${message.message}');
          _handleAuthRequest(message.message);
        },
      )
      ..addJavaScriptChannel(
        'LocationManager',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('🌍 Location message: ${message.message}');
          _handleLocationRequest(message.message);
        },
      )
      ..addJavaScriptChannel(
        'ContactsManager',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('📞 Contacts message: ${message.message}');
          _handleContactsRequest(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('⏳ Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('✅ Page finished loading: $url');
            _injectJavaScript(controller);
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('🔄 Navigation request: ${request.url}');
            return _handleNavigationRequest(request);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ Web resource error: ${error.description}');
          },
        ),
      )
      ..setUserAgent('ERPForever-Flutter-App');

    // Load the URL
    controller.loadRequest(Uri.parse(url));
    
    return controller;
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    debugPrint('🔍 Handling navigation request: ${request.url}');
    
    // Handle theme requests
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
    // Handle auth requests
    else if (request.url.startsWith('logout://')) {
      _handleAuthRequest('logout');
      return NavigationDecision.prevent;
    }
    // Handle location requests
    else if (request.url.startsWith('get-location://')) {
      _handleLocationRequest('getCurrentLocation');
      return NavigationDecision.prevent;
    }
    // Handle contacts requests
    else if (request.url.startsWith('get-contacts://')) {
      _handleContactsRequest('getAllContacts');
      return NavigationDecision.prevent;
    }
    // Handle barcode requests
    else if (request.url.contains('barcode') || request.url.contains('scan')) {
      bool isContinuous = request.url.contains('continuous');
      _handleBarcodeRequest(isContinuous ? 'scanContinuous' : 'scan');
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  /// Handle contacts requests
  void _handleContactsRequest(String message) async {
    if (_currentContext == null || _currentController == null) {
      debugPrint('❌ No context or controller available for contacts request');
      return;
    }

    debugPrint('📞 Processing contacts request...');
    
    try {
      // Show loading dialog
      _showContactsLoadingDialog();

      // Get all contacts
      Map<String, dynamic> contactsResult = await AppContactsService().getAllContacts();

      // Hide loading dialog
      if (_currentContext != null && Navigator.canPop(_currentContext!)) {
        Navigator.of(_currentContext!).pop();
      }

      // Send result to WebView
      _sendContactsToWebView(contactsResult);

    } catch (e) {
      debugPrint('❌ Error handling contacts request: $e');
      
      // Hide loading dialog
      if (_currentContext != null && Navigator.canPop(_currentContext!)) {
        Navigator.of(_currentContext!).pop();
      }
      
      // Send error to WebView
      _sendContactsToWebView({
        'success': false,
        'error': 'Failed to get contacts: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
        'contacts': []
      });
    }
  }

  void _showContactsLoadingDialog() {
    if (_currentContext == null) return;

    showDialog(
      context: _currentContext!,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading contacts...',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendContactsToWebView(Map<String, dynamic> contactsData) {
    if (_currentController == null) {
      debugPrint('❌ No WebView controller available for contacts result');
      return;
    }

    debugPrint('📱 Sending contacts data to WebView: ${contactsData['totalCount'] ?? 0} contacts');

    final success = contactsData['success'] ?? false;
    final error = (contactsData['error'] ?? '').replaceAll('"', '\\"');
    final errorCode = contactsData['errorCode'] ?? '';
    final totalCount = contactsData['totalCount'] ?? 0;

    // Convert contacts to JSON string safely
    String contactsJson = '[]';
    if (contactsData['contacts'] != null) {
      try {
        contactsJson = contactsData['contacts'].toString().replaceAll("'", '"');
      } catch (e) {
        debugPrint('❌ Error converting contacts to JSON: $e');
      }
    }

    _currentController!.runJavaScript('''
      try {
        console.log("📞 Contacts received: Success=$success, Count=$totalCount");
        
        var contactsResult = {
          success: $success,
          contacts: $contactsJson,
          totalCount: $totalCount,
          error: "$error",
          errorCode: "$errorCode"
        };
        
        // Try callback functions
        if (typeof getContactsCallback === 'function') {
          console.log("✅ Calling getContactsCallback()");
          getContactsCallback($success, contactsResult.contacts, $totalCount, "$error", "$errorCode");
        } else if (typeof window.handleContactsResult === 'function') {
          console.log("✅ Calling window.handleContactsResult()");
          window.handleContactsResult(contactsResult);
        } else if (typeof handleContactsResult === 'function') {
          console.log("✅ Calling handleContactsResult()");
          handleContactsResult(contactsResult);
        } else {
          console.log("✅ Using fallback - triggering event");
          
          var event = new CustomEvent('contactsReceived', { detail: contactsResult });
          document.dispatchEvent(event);
        }
        
      } catch (error) {
        console.error("❌ Error handling contacts result:", error);
      }
    ''');

    // Show feedback to user
    if (_currentContext != null) {
      String message;
      Color backgroundColor;
      
      if (contactsData['success']) {
        message = 'Loaded ${contactsData['totalCount']} contacts';
        backgroundColor = Colors.green;
      } else {
        message = contactsData['error'] ?? 'Failed to load contacts';
        backgroundColor = Colors.red;
      }

      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 5), // Longer duration for permission messages
          backgroundColor: backgroundColor,
          action: !contactsData['success'] && contactsData['errorCode'] == 'PERMISSION_DENIED_FOREVER'
            ? SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () async {
                  bool opened = await AppContactsService().openSettings();
                  if (!opened) {
                    ScaffoldMessenger.of(_currentContext!).showSnackBar(
                      SnackBar(
                        content: Text('Please manually open Settings > Apps > ERPForever > Permissions'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
              )
            : null,
        ),
      );
    }
  }

  /// Handle location requests
  void _handleLocationRequest(String message) async {
    if (_currentContext == null || _currentController == null) {
      debugPrint('❌ No context or controller available for location request');
      return;
    }

    debugPrint('🌍 Processing location request...');
    
    try {
      // Show loading dialog
      _showLocationLoadingDialog();

      Map<String, dynamic> locationResult = await LocationService().getCurrentLocation();

      // Hide loading dialog
      if (_currentContext != null && Navigator.canPop(_currentContext!)) {
        Navigator.of(_currentContext!).pop();
      }

      // Send result to WebView
      _sendLocationToWebView(locationResult);

    } catch (e) {
      debugPrint('❌ Error handling location request: $e');
      
      // Hide loading dialog
      if (_currentContext != null && Navigator.canPop(_currentContext!)) {
        Navigator.of(_currentContext!).pop();
      }
      
      _sendLocationToWebView({
        'success': false,
        'error': 'Failed to get location: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR'
      });
    }
  }

  void _showLocationLoadingDialog() {
    if (_currentContext == null) return;

    showDialog(
      context: _currentContext!,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Getting your location...',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendLocationToWebView(Map<String, dynamic> locationData) {
    if (_currentController == null) {
      debugPrint('❌ No WebView controller available for location result');
      return;
    }

    debugPrint('📱 Sending location data to WebView');

    final success = locationData['success'] ?? false;
    final latitude = locationData['latitude'];
    final longitude = locationData['longitude'];
    final error = (locationData['error'] ?? '').replaceAll('"', '\\"');
    final errorCode = locationData['errorCode'] ?? '';

    _currentController!.runJavaScript('''
      try {
        console.log("📍 Location received: Success=$success");
        
        var locationResult = {
          success: $success,
          latitude: ${latitude ?? 'null'},
          longitude: ${longitude ?? 'null'},
          error: "$error",
          errorCode: "$errorCode"
        };
        
        // Try callback functions
        if (typeof getLocationCallback === 'function') {
          console.log("✅ Calling getLocationCallback()");
          getLocationCallback($success, ${latitude ?? 'null'}, ${longitude ?? 'null'}, "$error", "$errorCode");
        } else if (typeof window.handleLocationResult === 'function') {
          console.log("✅ Calling window.handleLocationResult()");
          window.handleLocationResult(locationResult);
        } else if (typeof handleLocationResult === 'function') {
          console.log("✅ Calling handleLocationResult()");
          handleLocationResult(locationResult);
        } else {
          console.log("✅ Using fallback - triggering event");
          
          var event = new CustomEvent('locationReceived', { detail: locationResult });
          document.dispatchEvent(event);
        }
        
      } catch (error) {
        console.error("❌ Error handling location result:", error);
      }
    ''');

    // Show feedback
    if (_currentContext != null) {
      String message;
      Color backgroundColor;
      
      if (locationData['success']) {
        final lat = locationData['latitude']?.toStringAsFixed(6) ?? 'Unknown';
        final lng = locationData['longitude']?.toStringAsFixed(6) ?? 'Unknown';
        message = 'Location: $lat, $lng';
        backgroundColor = Colors.green;
      } else {
        message = locationData['error'] ?? 'Failed to get location';
        backgroundColor = Colors.red;
      }

      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 3),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }

  void _handleAuthRequest(String message) {
    if (_currentContext == null) {
      debugPrint('❌ No context available for auth request');
      return;
    }

    if (message == 'logout') {
      _performLogout();
    }
  }

  void _performLogout() async {
    if (_currentContext == null) return;

    try {
      final authService = Provider.of<AuthService>(_currentContext!, listen: false);
      await authService.logout();

      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(_currentContext!).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );

    } catch (e) {
      debugPrint('❌ Error during logout: $e');
      
      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        const SnackBar(
          content: Text('Error during logout'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleBarcodeRequest(String message) {
    if (_currentContext == null) return;

    bool isContinuous = message == 'scanContinuous';
    
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
    if (_currentController == null) return;

    final escapedBarcode = barcode.replaceAll('"', '\\"');

    _currentController!.runJavaScript('''
      try {
        console.log("📸 Barcode received: $escapedBarcode");
        
        if (typeof getBarcode === 'function') {
          getBarcode("$escapedBarcode");
        } else {
          var inputs = document.querySelectorAll('input[type="text"]');
          if(inputs.length > 0) {
            inputs[0].value = "$escapedBarcode";
            inputs[0].dispatchEvent(new Event('input'));
          }
          
          var event = new CustomEvent('barcodeScanned', { 
            detail: { result: "$escapedBarcode", continuous: $isContinuous } 
          });
          document.dispatchEvent(event);
        }
        
      } catch (error) {
        console.error("❌ Error handling barcode:", error);
      }
    ''');

    if (_currentContext != null) {
      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        SnackBar(
          content: Text('Barcode scanned: $barcode'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleThemeChange(String themeMode) {
    if (_currentContext != null) {
      final themeService = Provider.of<ThemeService>(_currentContext!, listen: false);
      themeService.updateThemeMode(themeMode);
      
      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        SnackBar(
          content: Text('Theme changed to ${themeMode.toUpperCase()} mode'),
        ),
      );
    }
  }

  void _injectJavaScript(WebViewController controller) {
    debugPrint('💉 Injecting JavaScript...');
    
    controller.runJavaScript('''
      console.log("🚀 ERPForever WebView JavaScript loading...");
      
      // Enhanced click handler
      document.addEventListener('click', function(e) {
        let element = e.target;
        
        for (let i = 0; i < 4 && element; i++) {
          const href = element.getAttribute('href');
          const textContent = element.textContent?.toLowerCase() || '';
          
          // Theme requests
          if (href) {
            if (href.startsWith('dark-mode://')) {
              e.preventDefault();
              if (window.ThemeManager) window.ThemeManager.postMessage('dark');
              return false;
            } else if (href.startsWith('light-mode://')) {
              e.preventDefault();
              if (window.ThemeManager) window.ThemeManager.postMessage('light');
              return false;
            } else if (href.startsWith('system-mode://')) {
              e.preventDefault();
              if (window.ThemeManager) window.ThemeManager.postMessage('system');
              return false;
            } else if (href.startsWith('logout://')) {
              e.preventDefault();
              if (window.AuthManager) window.AuthManager.postMessage('logout');
              return false;
            } else if (href.startsWith('get-location://')) {
              e.preventDefault();
              if (window.LocationManager) window.LocationManager.postMessage('getCurrentLocation');
              return false;
            } else if (href.startsWith('get-contacts://')) {
              e.preventDefault();
              if (window.ContactsManager) window.ContactsManager.postMessage('getAllContacts');
              return false;
            }
          }
          
          // Barcode detection
          if (href?.includes('barcode') || href?.includes('scan') || textContent.includes('scan')) {
            e.preventDefault();
            if (window.BarcodeScanner) window.BarcodeScanner.postMessage('scan');
            return false;
          }
          
          // Logout detection
          if (textContent.includes('logout') || textContent.includes('log out')) {
            e.preventDefault();
            if (window.AuthManager) window.AuthManager.postMessage('logout');
            return false;
          }
          
          // Location detection
          if (textContent.includes('get location') || textContent.includes('current location')) {
            e.preventDefault();
            if (window.LocationManager) window.LocationManager.postMessage('getCurrentLocation');
            return false;
          }
          
          // Contacts detection
          if (textContent.includes('get contacts') || textContent.includes('contacts')) {
            e.preventDefault();
            if (window.ContactsManager) window.ContactsManager.postMessage('getAllContacts');
            return false;
          }
          
          element = element.parentElement;
        }
      }, true);

      // Utility object
      window.ERPForever = {
        // Get all contacts
        getAllContacts: function() {
          console.log('📞 Getting all contacts...');
          if (window.ContactsManager) {
            window.ContactsManager.postMessage('getAllContacts');
          } else {
            console.error('❌ ContactsManager not available');
          }
        },
        
        // Get current location
        getCurrentLocation: function() {
          console.log('🌍 Getting current location...');
          if (window.LocationManager) {
            window.LocationManager.postMessage('getCurrentLocation');
          } else {
            console.error('❌ LocationManager not available');
          }
        },
        
        // Scan barcode
        scanBarcode: function() {
          console.log('📸 Scanning barcode...');
          if (window.BarcodeScanner) {
            window.BarcodeScanner.postMessage('scan');
          } else {
            console.error('❌ BarcodeScanner not available');
          }
        },
        
        // Change theme
        setTheme: function(theme) {
          console.log('🎨 Setting theme to:', theme);
          if (window.ThemeManager) {
            window.ThemeManager.postMessage(theme);
          } else {
            console.error('❌ ThemeManager not available');
          }
        },
        
        // Logout
        logout: function() {
          console.log('🚪 Logging out...');
          if (window.AuthManager) {
            window.AuthManager.postMessage('logout');
          } else {
            console.error('❌ AuthManager not available');
          }
        },
        
        // Check availability
        isContactsAvailable: function() {
          return !!window.ContactsManager;
        },
        
        isLocationAvailable: function() {
          return !!window.LocationManager;
        },
        
        isBarcodeAvailable: function() {
          return !!window.BarcodeScanner;
        },
        
        version: '1.0.0'
      };

      console.log("✅ ERPForever WebView JavaScript ready!");
      console.log("📚 Usage: window.ERPForever.getAllContacts()");
    ''');
  }

  // Update context
  void updateContext(BuildContext context) {
    _currentContext = context;
  }

  // Clean up
  void dispose() {
    _currentContext = null;
    _currentController = null;
  }
}