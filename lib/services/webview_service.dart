// lib/services/webview_service.dart
import 'package:ERPForever/services/app_data_service.dart';
import 'package:ERPForever/services/config_service.dart';
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
import 'package:ERPForever/services/screenshot_service.dart';
import 'package:ERPForever/services/image_saver_service.dart';
import 'package:ERPForever/services/pdf_saver_service.dart';
import 'package:ERPForever/services/alert_service.dart';

class WebViewService {
  static final WebViewService _instance = WebViewService._internal();
  factory WebViewService() => _instance;
  WebViewService._internal();


  final List<Map<String, dynamic>> _controllerStack = [];

BuildContext? get _currentContext {
  if (_controllerStack.isEmpty) return null;
  return _controllerStack.last['context'] as BuildContext?;
}

WebViewController? get _currentController {
  if (_controllerStack.isEmpty) return null;
  return _controllerStack.last['controller'] as WebViewController?;
}

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

  void _navigateToRegularWebView(
    BuildContext context,
    String url,
    String title,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewPage(url: url, title: title),
      ),
    );
  }

  void _showWebViewSheet(BuildContext context, String url, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WebViewSheet(url: url, title: title),
    );
  }
WebViewController createController(String url, [BuildContext? context]) {
  debugPrint('🌐 Creating WebView controller for: $url');

  final controller = WebViewController();

  // Configure the controller
  controller
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0x00000000))
    ..enableZoom(false)
    ..setUserAgent('ERPForever-Flutter-App/1.0')
    
    // ADD: All your existing JavaScript channels (keep these as they are)
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
    ..addJavaScriptChannel(
      'ScreenshotManager',
      onMessageReceived: (JavaScriptMessage message) {
        debugPrint('📸 Screenshot message: ${message.message}');
        _handleScreenshotRequest(message.message);
      },
    )
    ..addJavaScriptChannel(
      'ImageSaver',
      onMessageReceived: (JavaScriptMessage message) {
        debugPrint('🖼️ Image saver message: ${message.message}');
        _handleImageSaveRequest(message.message);
      },
    )
    ..addJavaScriptChannel(
      'PdfSaver',
      onMessageReceived: (JavaScriptMessage message) {
        debugPrint('📄 PDF saver message: ${message.message}');
        _handlePdfSaveRequest(message.message);
      },
    )
    ..addJavaScriptChannel(
      'AlertManager',
      onMessageReceived: (JavaScriptMessage message) {
        debugPrint('🚨 Alert message: ${message.message}');
        _handleAlertRequest(message.message);
      },
    )..addJavaScriptChannel(
  'ToastManager',
  onMessageReceived: (JavaScriptMessage message) {
    debugPrint('🍞 Toast message: ${message.message}');
    _handleToastRequest(message.message);
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

          // Make WebView content screenshot-ready
          controller.runJavaScript('''
            document.body.style.webkitBackfaceVisibility = 'hidden';
            document.body.style.webkitPerspective = '1000px';
            document.body.style.webkitTransform = 'translate3d(0,0,0)';
            document.body.style.transform = 'translate3d(0,0,0)';
            
            document.documentElement.style.webkitTransform = 'translateZ(0)';
            document.documentElement.style.transform = 'translateZ(0)';
            
            console.log("✅ WebView optimized for screenshots");
          ''');
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

  // NEW: Load URL with app data
  _loadUrlWithAppData(controller, url, context);

  return controller;
}
void _handleToastRequest(String message) {
  if (_currentContext == null) {
    debugPrint('❌ No context available for toast request');
    return;
  }

  if (!_currentContext!.mounted) {
    debugPrint('❌ Context is no longer mounted for toast request');
    return;
  }

  debugPrint('🍞 Processing toast request: $message');

  try {
    // Extract toast message from URL
    String toastMessage = _extractToastMessage(message);
    
    if (toastMessage.isEmpty) {
      debugPrint('❌ Empty toast message');
      return;
    }

    // Show toast/snackbar
    ScaffoldMessenger.of(_currentContext!).showSnackBar(
      SnackBar(
        content: Text(toastMessage),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green, // You can make this configurable
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(_currentContext!).hideCurrentSnackBar();
          },
        ),
      ),
    );

    debugPrint('✅ Toast shown: $toastMessage');
  } catch (e) {
    debugPrint('❌ Error handling toast request: $e');
  }
}

String _extractToastMessage(String url) {
  try {
    // Remove protocol
    String cleanUrl = url.replaceAll('toast://', '');
    
    // URL decode
    return Uri.decodeComponent(cleanUrl);
  } catch (e) {
    debugPrint('❌ Error extracting toast message: $e');
    return '';
  }
}
Future<void> _loadUrlWithAppData(WebViewController controller, String originalUrl, [BuildContext? context]) async {
  try {
    debugPrint('📊 Collecting enhanced app data with language and theme...');
    
    // Collect app data with context for better theme detection
    final appData = await AppDataService().collectDataForServer(context);
    
    // Build enhanced URL with app data
    final enhancedUrl = _buildEnhancedUrl(originalUrl, appData);
    
    // Build custom headers with app data
    final headers = _buildAppDataHeaders(appData, context);
    
    // Load the enhanced URL with custom headers
    await controller.loadRequest(
      Uri.parse(enhancedUrl),
      headers: headers,
    );
    
    debugPrint('✅ Loaded URL with enhanced app data including language and theme');
    debugPrint('🌍 Language: ${appData['current_language']}, Theme: ${appData['current_theme_mode']}');
    
  } catch (e) {
    debugPrint('❌ Error loading URL with enhanced app data: $e');
    // Fallback to original URL
    controller.loadRequest(Uri.parse(originalUrl));
  }
}
String _buildEnhancedUrl(String baseUrl, Map<String, String> appData) {
  try {
    final uri = Uri.parse(baseUrl);
    final queryParams = Map<String, String>.from(uri.queryParameters);
    
    // Add essential app data to URL parameters
    queryParams.addAll({
      'app_source': 'flutter_app',
      'app_version': appData['app_version'] ?? 'unknown',
      'platform': appData['platform'] ?? 'unknown',
      'device_model': appData['device_model'] ?? 'unknown',
      'current_language': appData['current_language'] ?? 'en',
      'current_theme': appData['current_theme_mode'] ?? 'system',
      'text_direction': appData['text_direction'] ?? 'LTR',
      'notification_id': appData['notification_id'] ?? AppDataService.NOTIFICATION_ID, // ADD THIS LINE
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    });

    final newUri = uri.replace(queryParameters: queryParams);
    return newUri.toString();
    
  } catch (e) {
    debugPrint('❌ Error building enhanced URL: $e');
    return baseUrl;
  }
}
// ADD this new method to your WebViewService class:
Map<String, String> _buildAppDataHeaders(Map<String, String> appData, [BuildContext? context]) {
  final headers = <String, String>{
    'User-Agent': 'ERPForever-Flutter-App/1.0',
    'X-App-Source': 'flutter_mobile',
    'X-Client-Version': appData['app_version'] ?? 'unknown',
    'X-Platform': appData['platform'] ?? 'unknown',
    'X-Device-Model': appData['device_model'] ?? 'unknown',
    'X-App-Timestamp': DateTime.now().toIso8601String(),
    
    // Language and theme headers
    'X-Current-Language': appData['current_language'] ?? 'en',
    'X-Current-Theme': appData['current_theme_mode'] ?? 'system',
    'X-Text-Direction': appData['text_direction'] ?? 'LTR',
    'X-Theme-Setting': appData['theme_setting'] ?? 'system',
    
    // NOTIFICATION ID HEADER - ADD THIS LINE
    'X-Notification-ID': appData['notification_id'] ?? AppDataService.NOTIFICATION_ID,
  };

  // Add important data as custom headers
  if (appData['device_brand'] != null) {
    headers['X-Device-Brand'] = appData['device_brand']!;
  }
  if (appData['build_number'] != null) {
    headers['X-Build-Number'] = appData['build_number']!;
  }
  if (appData['timezone'] != null) {
    headers['X-Timezone'] = appData['timezone']!;
  }

  // Add compact headers using the helper method
  try {
    final compactHeaders = AppDataService().getCompactDataForHeaders(context);
    headers.addAll(compactHeaders);
  } catch (e) {
    debugPrint('❌ Error adding compact headers: $e');
  }

  return headers;
}
  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    debugPrint('🔍 Handling navigation request: ${request.url}');
// NEW: Handle loggedin:// protocol for config updates
  if (request.url.startsWith('loggedin://')) {
    _handleLoginConfigRequest(request.url);
    return NavigationDecision.prevent;
  }
  if (request.url.startsWith('toast://')) {
  _handleToastRequest(request.url);
  return NavigationDecision.prevent;
}
  // Handle theme requests
  if (request.url.startsWith('dark-mode://')) {
    _handleThemeChange('dark');
    return NavigationDecision.prevent;
  } 
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
    // Handle screenshot requests
    else if (request.url.startsWith('take-screenshot://')) {
      _handleScreenshotRequest('takeScreenshot');
      return NavigationDecision.prevent;
    }
    // Handle image save requests
    else if (request.url.startsWith('save-image://')) {
      _handleImageSaveRequest(request.url);
      return NavigationDecision.prevent;
    } else if (request.url.startsWith('save-pdf://')) {
      _handlePdfSaveRequest(request.url);
      return NavigationDecision.prevent;
    }
    // Handle alert requests - ADD THIS SECTION
    if (request.url.startsWith('alert://')) {
      _handleAlertRequest(request.url);
      return NavigationDecision.prevent;
    } else if (request.url.startsWith('confirm://')) {
      _handleAlertRequest(request.url);
      return NavigationDecision.prevent;
    } else if (request.url.startsWith('prompt://')) {
      _handleAlertRequest(request.url);
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

 void _handleAlertRequest(String message) async {
  if (_currentContext == null) {
    debugPrint('❌ No context available for alert request');
    return;
  }

  // ADD THIS CONTEXT VALIDATION
  if (!_currentContext!.mounted) {
    debugPrint('❌ Context is no longer mounted for alert request');
    return;
  }

  debugPrint('🚨 Processing alert request: $message');

  try {
    Map<String, dynamic> result;
    String alertType = AlertService().getAlertType(message);

    switch (alertType) {
      case 'alert':
        result = await AlertService().showAlertFromUrl(
          message,
          _currentContext!,
        );
        break;
      case 'confirm':
        result = await AlertService().showConfirmFromUrl(
          message,
          _currentContext!,
        );
        break;
      case 'prompt':
        result = await AlertService().showPromptFromUrl(
          message,
          _currentContext!,
        );
        break;
      default:
        result = await AlertService().showAlertFromUrl(
          message,
          _currentContext!,
        );
        break;
    }

    // Send result back to WebView
    _sendAlertResultToWebView(result, alertType);
  } catch (e) {
    debugPrint('❌ Error handling alert request: $e');

    _sendAlertResultToWebView({
      'success': false,
      'error': 'Failed to handle alert: ${e.toString()}',
      'errorCode': 'UNKNOWN_ERROR',
    }, 'alert');
  }
}


void _sendAlertResultToWebView(Map<String, dynamic> result, String alertType) {
  if (_currentController == null) {
    debugPrint('❌ No WebView controller available for alert result');
    return;
  }

  if (!isControllerValid()) {
    debugPrint('❌ WebView controller is no longer valid');
    return;
  }

  debugPrint('📱 Sending alert result to WebView: $alertType');

  // Rest of the method stays the same...
  final success = result['success'] ?? false;
  final error = (result['error'] ?? '').replaceAll('"', '\\"');
  final errorCode = result['errorCode'] ?? '';
  final message = (result['message'] ?? '').replaceAll('"', '\\"');
  final userResponse = (result['userResponse'] ?? '').replaceAll('"', '\\"');
  final userInput = (result['userInput'] ?? '').replaceAll('"', '\\"');
  final confirmed = result['confirmed'] ?? false;
  final cancelled = result['cancelled'] ?? false;
  final dismissed = result['dismissed'] ?? false;

  _currentController!.runJavaScript('''
    try {
      console.log("🚨 Alert result received: Type=$alertType, Success=$success");
      
      var alertResult = {
        success: $success,
        type: "$alertType",
        message: "$message",
        userResponse: "$userResponse",
        userInput: "$userInput",
        confirmed: $confirmed,
        cancelled: $cancelled,
        dismissed: $dismissed,
        error: "$error",
        errorCode: "$errorCode"
      };
      
      // Try specific callback functions for each alert type
      if ("$alertType" === "alert") {
        if (typeof getAlertCallback === 'function') {
          console.log("✅ Calling getAlertCallback()");
          getAlertCallback($success, "$message", "$userResponse", "$error");
        } else if (typeof window.handleAlertResult === 'function') {
          console.log("✅ Calling window.handleAlertResult()");
          window.handleAlertResult(alertResult);
        }
      } else if ("$alertType" === "confirm") {
        if (typeof getConfirmCallback === 'function') {
          console.log("✅ Calling getConfirmCallback()");
          getConfirmCallback($success, "$message", $confirmed, $cancelled, "$error");
        } else if (typeof window.handleConfirmResult === 'function') {
          console.log("✅ Calling window.handleConfirmResult()");
          window.handleConfirmResult(alertResult);
        }
      } else if ("$alertType" === "prompt") {
        if (typeof getPromptCallback === 'function') {
          console.log("✅ Calling getPromptCallback()");
          getPromptCallback($success, "$message", "$userInput", $confirmed, "$error");
        } else if (typeof window.handlePromptResult === 'function') {
          console.log("✅ Calling window.handlePromptResult()");
          window.handlePromptResult(alertResult);
        }
      }
      
      // Generic callback
      if (typeof handleAlertResult === 'function') {
        console.log("✅ Calling generic handleAlertResult()");
        handleAlertResult(alertResult);
      }
      
      // Fallback: trigger custom event
      var event = new CustomEvent('alertResult', { detail: alertResult });
      document.dispatchEvent(event);
      
    } catch (error) {
      console.error("❌ Error handling alert result:", error);
    }
  ''');
}

  void _handlePdfSaveRequest(String message) async {
    if (_currentContext == null) {
      debugPrint('❌ No context available for PDF save request');
      return;
    }

    debugPrint('📄 Processing PDF save request: $message');

    // Extract PDF URL from the message
    String pdfUrl = PdfSaverService().extractPdfUrl(message);

    if (!PdfSaverService().isValidPdfUrl(pdfUrl)) {
      _sendPdfSaveToWebView({
        'success': false,
        'error': 'Invalid PDF URL',
        'errorCode': 'INVALID_URL',
        'url': pdfUrl,
      });
      return;
    }

    // Show loading dialog
    _showPdfSaveLoadingDialog(pdfUrl);

    try {
      // Save PDF to device
      Map<String, dynamic> result = await PdfSaverService().savePdfFromUrl(
        message,
      );

      // Hide loading dialog
      if (_currentContext != null && Navigator.canPop(_currentContext!)) {
        Navigator.of(_currentContext!).pop();
      }

      // Send result to WebView
      _sendPdfSaveToWebView(result);

      // Show option to open PDF if successful
      if (result['success'] && result['filePath'] != null) {
        _showPdfSavedDialog(result['filePath'], result['fileName']);
      }
    } catch (e) {
      debugPrint('❌ Error handling PDF save request: $e');

      // Hide loading dialog
      if (_currentContext != null && Navigator.canPop(_currentContext!)) {
        Navigator.of(_currentContext!).pop();
      }

      _sendPdfSaveToWebView({
        'success': false,
        'error': 'Failed to save PDF: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
        'url': pdfUrl,
      });
    }
  }

  void _showPdfSaveLoadingDialog(String pdfUrl) {
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
                'Downloading PDF...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                Uri.parse(pdfUrl).pathSegments.last.replaceAll('.pdf', '') +
                    '.pdf',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPdfSavedDialog(String filePath, String fileName) {
    if (_currentContext == null) return;

    showDialog(
      context: _currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red),
              SizedBox(width: 8),
              Text('PDF Saved'),
            ],
          ),
          content: Text(
            '$fileName has been saved successfully. Would you like to open it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Later'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                final result = await PdfSaverService().openPdf(filePath);

                if (!result['success']) {
                  ScaffoldMessenger.of(_currentContext!).showSnackBar(
                    SnackBar(
                      content: Text(result['error'] ?? 'Could not open PDF'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: Text('Open PDF'),
            ),
          ],
        );
      },
    );
  }

  void _sendPdfSaveToWebView(Map<String, dynamic> result) {
    if (_currentController == null) {
      debugPrint('❌ No WebView controller available for PDF save result');
      return;
    }

    debugPrint('📱 Sending PDF save result to WebView');

    final success = result['success'] ?? false;
    final error = (result['error'] ?? '').replaceAll('"', '\\"');
    final errorCode = result['errorCode'] ?? '';
    final message = (result['message'] ?? '').replaceAll('"', '\\"');
    final fileName = (result['fileName'] ?? '').replaceAll('"', '\\"');
    final fileSize = result['fileSize'] ?? 0;
    final url = (result['url'] ?? '').replaceAll('"', '\\"');
    final filePath = (result['filePath'] ?? '').replaceAll('"', '\\"');

    _currentController!.runJavaScript('''
    try {
      console.log("📄 PDF save result: Success=$success");
      
      var pdfSaveResult = {
        success: $success,
        fileName: "$fileName",
        fileSize: $fileSize,
        filePath: "$filePath",
        message: "$message",
        error: "$error",
        errorCode: "$errorCode",
        url: "$url"
      };
      
      // Try callback functions
      if (typeof getPdfSaveCallback === 'function') {
        console.log("✅ Calling getPdfSaveCallback()");
        getPdfSaveCallback($success, "$fileName", "$message", "$error", "$errorCode");
      } else if (typeof window.handlePdfSaveResult === 'function') {
        console.log("✅ Calling window.handlePdfSaveResult()");
        window.handlePdfSaveResult(pdfSaveResult);
      } else if (typeof handlePdfSaveResult === 'function') {
        console.log("✅ Calling handlePdfSaveResult()");
        handlePdfSaveResult(pdfSaveResult);
      } else {
        console.log("✅ Using fallback - triggering event");
        
        var event = new CustomEvent('pdfSaved', { detail: pdfSaveResult });
        document.dispatchEvent(event);
      }
      
    } catch (error) {
      console.error("❌ Error handling PDF save result:", error);
    }
  ''');

    // Show feedback to user
    if (_currentContext != null) {
      String feedbackMessage;
      Color backgroundColor;

      if (result['success']) {
        final sizeFormatted = PdfSaverService().formatFileSize(
          result['fileSize'] ?? 0,
        );
        feedbackMessage =
            '${result['message'] ?? 'PDF saved successfully'} ($sizeFormatted)';
        backgroundColor = Colors.green;
      } else {
        feedbackMessage = result['error'] ?? 'Failed to save PDF';
        backgroundColor = Colors.red;
      }

      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        SnackBar(
          content: Text(feedbackMessage),
          duration: Duration(seconds: 4),
          backgroundColor: backgroundColor,
          action:
              !result['success'] &&
                      result['errorCode'] == 'PERMISSION_DENIED_FOREVER'
                  ? SnackBarAction(
                    label: 'Settings',
                    textColor: Colors.white,
                    onPressed: () async {
                      bool opened = await PdfSaverService().openAppSettings();
                      if (!opened) {
                        ScaffoldMessenger.of(_currentContext!).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please enable storage permission in Settings',
                            ),
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

  /// Handle image save requests
  void _handleImageSaveRequest(String message) async {
    if (_currentContext == null) {
      debugPrint('❌ No context available for image save request');
      return;
    }

    debugPrint('🖼️ Processing image save request: $message');

    // Extract image URL from the message
    String imageUrl = ImageSaverService().extractImageUrl(message);

    if (!ImageSaverService().isValidImageUrl(imageUrl)) {
      _sendImageSaveToWebView({
        'success': false,
        'error': 'Invalid image URL',
        'errorCode': 'INVALID_URL',
        'url': imageUrl,
      });
      return;
    }

    // Show loading dialog
    _showImageSaveLoadingDialog(imageUrl);

    try {
      // Save image to gallery
      Map<String, dynamic> result = await ImageSaverService().saveImageFromUrl(
        message,
      );

      // Hide loading dialog
      if (_currentContext != null && Navigator.canPop(_currentContext!)) {
        Navigator.of(_currentContext!).pop();
      }

      // Send result to WebView
      _sendImageSaveToWebView(result);
    } catch (e) {
      debugPrint('❌ Error handling image save request: $e');

      // Hide loading dialog
      if (_currentContext != null && Navigator.canPop(_currentContext!)) {
        Navigator.of(_currentContext!).pop();
      }

      _sendImageSaveToWebView({
        'success': false,
        'error': 'Failed to save image: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
        'url': imageUrl,
      });
    }
  }

  void _showImageSaveLoadingDialog(String imageUrl) {
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
                'Saving image...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                Uri.parse(imageUrl).pathSegments.last,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendImageSaveToWebView(Map<String, dynamic> result) {
    if (_currentController == null) {
      debugPrint('❌ No WebView controller available for image save result');
      return;
    }

    debugPrint('📱 Sending image save result to WebView');

    final success = result['success'] ?? false;
    final error = (result['error'] ?? '').replaceAll('"', '\\"');
    final errorCode = result['errorCode'] ?? '';
    final message = (result['message'] ?? '').replaceAll('"', '\\"');
    final fileName = (result['fileName'] ?? '').replaceAll('"', '\\"');
    final fileSize = result['fileSize'] ?? 0;
    final url = (result['url'] ?? '').replaceAll('"', '\\"');

    _currentController!.runJavaScript('''
      try {
        console.log("🖼️ Image save result: Success=$success");
        
        var imageSaveResult = {
          success: $success,
          fileName: "$fileName",
          fileSize: $fileSize,
          message: "$message",
          error: "$error",
          errorCode: "$errorCode",
          url: "$url"
        };
        
        // Try callback functions
        if (typeof getImageSaveCallback === 'function') {
          console.log("✅ Calling getImageSaveCallback()");
          getImageSaveCallback($success, "$fileName", "$message", "$error", "$errorCode");
        } else if (typeof window.handleImageSaveResult === 'function') {
          console.log("✅ Calling window.handleImageSaveResult()");
          window.handleImageSaveResult(imageSaveResult);
        } else if (typeof handleImageSaveResult === 'function') {
          console.log("✅ Calling handleImageSaveResult()");
          handleImageSaveResult(imageSaveResult);
        } else {
          console.log("✅ Using fallback - triggering event");
          
          var event = new CustomEvent('imageSaved', { detail: imageSaveResult });
          document.dispatchEvent(event);
        }
        
      } catch (error) {
        console.error("❌ Error handling image save result:", error);
      }
    ''');

    // Show feedback to user
    if (_currentContext != null) {
      String feedbackMessage;
      Color backgroundColor;

      if (result['success']) {
        feedbackMessage = result['message'] ?? 'Image saved successfully';
        backgroundColor = Colors.green;
      } else {
        feedbackMessage = result['error'] ?? 'Failed to save image';
        backgroundColor = Colors.red;
      }

      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        SnackBar(
          content: Text(feedbackMessage),
          duration: Duration(seconds: 3),
          backgroundColor: backgroundColor,
          action:
              !result['success'] &&
                      result['errorCode'] == 'PERMISSION_DENIED_FOREVER'
                  ? SnackBarAction(
                    label: 'Settings',
                    textColor: Colors.white,
                    onPressed: () async {
                      bool opened = await ImageSaverService().openAppSettings();
                      if (!opened) {
                        ScaffoldMessenger.of(_currentContext!).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please enable storage permission in Settings',
                            ),
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

  /// Handle screenshot requests - SIMPLIFIED VERSION
  void _handleScreenshotRequest(String message) async {
    if (_currentContext == null) {
      debugPrint('❌ No context available for screenshot request');
      return;
    }

    debugPrint('📸 Processing screenshot request...');

    // Show loading dialog
    _showScreenshotLoadingDialog();

    // Add a small delay to ensure WebView is fully rendered
    await Future.delayed(Duration(milliseconds: 800));

    try {
      // Use the existing ScreenshotService which should now capture WebView
      Map<String, dynamic> screenshotResult = await ScreenshotService()
          .takeScreenshotWithOptions(
            saveToGallery: true,
            delay: Duration(milliseconds: 200),
          );

      // Hide loading dialog
      if (_currentContext != null && Navigator.canPop(_currentContext!)) {
        Navigator.of(_currentContext!).pop();
      }

      // Send result to WebView
      _sendScreenshotToWebView(screenshotResult);
    } catch (e) {
      debugPrint('❌ Error taking screenshot: $e');

      // Hide loading dialog
      if (_currentContext != null && Navigator.canPop(_currentContext!)) {
        Navigator.of(_currentContext!).pop();
      }

      _sendScreenshotToWebView({
        'success': false,
        'error': 'Failed to take screenshot: ${e.toString()}',
        'errorCode': 'CAPTURE_FAILED',
      });
    }
  }

  void _showScreenshotLoadingDialog() {
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
                'Taking screenshot...',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendScreenshotToWebView(Map<String, dynamic> screenshotData) {
    if (_currentController == null) {
      debugPrint('❌ No WebView controller available for screenshot result');
      return;
    }

    debugPrint('📱 Sending screenshot data to WebView');

    final success = screenshotData['success'] ?? false;
    final error = (screenshotData['error'] ?? '').replaceAll('"', '\\"');
    final errorCode = screenshotData['errorCode'] ?? '';
    final message = (screenshotData['message'] ?? '').replaceAll('"', '\\"');
    final size = screenshotData['size'] ?? 0;

    _currentController!.runJavaScript('''
      try {
        console.log("📸 Screenshot received: Success=$success");
        
        var screenshotResult = {
          success: $success,
          size: $size,
          message: "$message",
          error: "$error",
          errorCode: "$errorCode"
        };
        
        // Try callback functions
        if (typeof getScreenshotCallback === 'function') {
          console.log("✅ Calling getScreenshotCallback()");
          getScreenshotCallback($success, "$message", "$error", "$errorCode");
        } else if (typeof window.handleScreenshotResult === 'function') {
          console.log("✅ Calling window.handleScreenshotResult()");
          window.handleScreenshotResult(screenshotResult);
        } else if (typeof handleScreenshotResult === 'function') {
          console.log("✅ Calling handleScreenshotResult()");
          handleScreenshotResult(screenshotResult);
        } else {
          console.log("✅ Using fallback - triggering event");
          
          var event = new CustomEvent('screenshotTaken', { detail: screenshotResult });
          document.dispatchEvent(event);
        }
        
      } catch (error) {
        console.error("❌ Error handling screenshot result:", error);
      }
    ''');

    // Show simple feedback to user
    if (_currentContext != null) {
      String feedbackMessage;
      Color backgroundColor;

      if (screenshotData['success']) {
        // Check if it was actually saved to gallery
        if (screenshotData['actions'] != null &&
            screenshotData['actions']['gallery'] != null &&
            screenshotData['actions']['gallery']['success'] == true) {
          feedbackMessage = 'Screenshot saved to gallery';
        } else {
          feedbackMessage = 'Screenshot taken successfully';
        }
        backgroundColor = Colors.green;
      } else {
        feedbackMessage =
            screenshotData['error'] ?? 'Failed to take screenshot';
        backgroundColor = Colors.red;
      }

      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        SnackBar(
          content: Text(feedbackMessage),
          duration: Duration(seconds: 2),
          backgroundColor: backgroundColor,
          action:
              !screenshotData['success'] &&
                      screenshotData['errorCode'] == 'PERMISSION_DENIED_FOREVER'
                  ? SnackBarAction(
                    label: 'Settings',
                    textColor: Colors.white,
                    onPressed: () async {
                      bool opened = await ScreenshotService().openAppSettings();
                      if (!opened) {
                        ScaffoldMessenger.of(_currentContext!).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please enable storage permission in Settings',
                            ),
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
      Map<String, dynamic> contactsResult =
          await AppContactsService().getAllContacts();

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
        'contacts': [],
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

    debugPrint(
      '📱 Sending contacts data to WebView: ${contactsData['totalCount'] ?? 0} contacts',
    );

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
          duration: Duration(
            seconds: 5,
          ), // Longer duration for permission messages
          backgroundColor: backgroundColor,
          action:
              !contactsData['success'] &&
                      contactsData['errorCode'] == 'PERMISSION_DENIED_FOREVER'
                  ? SnackBarAction(
                    label: 'Settings',
                    textColor: Colors.white,
                    onPressed: () async {
                      bool opened = await AppContactsService().openSettings();
                      if (!opened) {
                        ScaffoldMessenger.of(_currentContext!).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please manually open Settings > Apps > ERPForever > Permissions',
                            ),
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

void _handleLocationRequest(String message) async {
  if (_currentContext == null || _currentController == null) {
    debugPrint('❌ No context or controller available for location request');
    return;
  }

  // ADD THIS CONTEXT VALIDATION
  if (!_currentContext!.mounted) {
    debugPrint('❌ Context is no longer mounted for location request');
    return;
  }

  debugPrint('🌍 Processing location request...');

  try {
    // Show loading dialog
    _showLocationLoadingDialog();

    Map<String, dynamic> locationResult =
        await LocationService().getCurrentLocation();

    // VALIDATE CONTEXT AGAIN before hiding dialog
    if (_currentContext != null && _currentContext!.mounted && Navigator.canPop(_currentContext!)) {
      Navigator.of(_currentContext!).pop();
    }

    // Send result to WebView
    _sendLocationToWebView(locationResult);
  } catch (e) {
    debugPrint('❌ Error handling location request: $e');

    // VALIDATE CONTEXT before hiding dialog
    if (_currentContext != null && _currentContext!.mounted && Navigator.canPop(_currentContext!)) {
      Navigator.of(_currentContext!).pop();
    }

    _sendLocationToWebView({
      'success': false,
      'error': 'Failed to get location: ${e.toString()}',
      'errorCode': 'UNKNOWN_ERROR',
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
  debugPrint('🚪 Auth request received: $message');
  
  if (_currentContext == null) {
    debugPrint('❌ No context available for auth request');
    return;
  }

  if (message == 'logout') {
    debugPrint('🔄 Processing logout request...');
    _performLogout();
  } else {
    debugPrint('⚠️ Unknown auth request: $message');
  }
}


void _performLogout() async {
  debugPrint('🚪 Starting logout process...');
  
  if (_currentContext == null) {
    debugPrint('❌ No context available for logout');
    return;
  }

  try {
    final authService = Provider.of<AuthService>(
      _currentContext!,
      listen: false,
    );
    
    debugPrint('🔄 Calling authService.logout()...');
    await authService.logout();

    debugPrint('✅ Logout successful, showing feedback...');
    
    ScaffoldMessenger.of(_currentContext!).showSnackBar(
      const SnackBar(
        content: Text('Logged out successfully'),
        backgroundColor: Colors.green,
      ),
    );

    debugPrint('🔄 Navigating to login page...');
    
    Navigator.of(_currentContext!).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
    
    debugPrint('✅ Navigation to login page completed');
    
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
        builder:
            (context) => BarcodeScannerPage(
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
      final themeService = Provider.of<ThemeService>(
        _currentContext!,
        listen: false,
      );
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
    
    // Enhanced click handler with full protocol support
    document.addEventListener('click', function(e) {
      let element = e.target;
      
      for (let i = 0; i < 4 && element; i++) {
        const href = element.getAttribute('href');
        const textContent = element.textContent?.toLowerCase() || '';
        
        // Handle all URL protocols
        if (href) {
          // Alert requests
          if (href.startsWith('alert://')) {
            e.preventDefault();
            if (window.AlertManager) {
              window.AlertManager.postMessage(href);
              console.log("🚨 Alert triggered via URL:", href);
            } else {
              console.error("❌ AlertManager not available");
            }
            return false;
          } 
          // Confirm requests
          else if (href.startsWith('confirm://')) {
            e.preventDefault();
            if (window.AlertManager) {
              window.AlertManager.postMessage(href);
              console.log("❓ Confirm triggered via URL:", href);
            } else {
              console.error("❌ AlertManager not available");
            }
            return false;
          } 
          // Prompt requests
          else if (href.startsWith('prompt://')) {
            e.preventDefault();
            if (window.AlertManager) {
              window.AlertManager.postMessage(href);
              console.log("✏️ Prompt triggered via URL:", href);
            } else {
              console.error("❌ AlertManager not available");
            }
            return false;
          }
          // Toast requests
          else if (href.startsWith('toast://')) {
            e.preventDefault();
            if (window.ToastManager) {
              window.ToastManager.postMessage(href);
              console.log("🍞 Toast triggered via URL:", href);
            } else {
              console.error("❌ ToastManager not available");
            }
            return false;
          }
          // Theme requests
          else if (href.startsWith('dark-mode://')) {
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
          } 
          // Auth requests
          else if (href.startsWith('logout://')) {
            e.preventDefault();
            if (window.AuthManager) window.AuthManager.postMessage('logout');
            return false;
          } 
          // Location requests
          else if (href.startsWith('get-location://')) {
            e.preventDefault();
            if (window.LocationManager) window.LocationManager.postMessage('getCurrentLocation');
            return false;
          } 
          // Contacts requests
          else if (href.startsWith('get-contacts://')) {
            e.preventDefault();
            if (window.ContactsManager) window.ContactsManager.postMessage('getAllContacts');
            return false;
          } 
          // Screenshot requests
          else if (href.startsWith('take-screenshot://')) {
            e.preventDefault();
            if (window.ScreenshotManager) window.ScreenshotManager.postMessage('takeScreenshot');
            return false;
          } 
          // Image save requests
          else if (href.startsWith('save-image://')) {
            e.preventDefault();
            if (window.ImageSaver) window.ImageSaver.postMessage(href);
            return false;
          } 
          // PDF save requests
          else if (href.startsWith('save-pdf://')) {
            e.preventDefault();
            if (window.PdfSaver) {
              window.PdfSaver.postMessage(href);
              console.log("📄 PDF save triggered via URL:", href);
            } else {
              console.error("❌ PdfSaver not available");
            }
            return false;
          }
        }
        
        // Text-based detection (enhanced with alerts)
        
        // Alert detection
        if (textContent.includes('show alert') || textContent.includes('alert message') || textContent.includes('display alert')) {
          let alertMsg = element.getAttribute('data-alert') || 
                        element.getAttribute('data-message') ||
                        element.closest('[data-alert]')?.getAttribute('data-alert') ||
                        element.closest('[data-message]')?.getAttribute('data-message');
          
          if (alertMsg) {
            e.preventDefault();
            if (window.AlertManager) {
              window.AlertManager.postMessage('alert://' + encodeURIComponent(alertMsg));
              console.log("🚨 Alert triggered via text for:", alertMsg);
            }
            return false;
          }
        }
        
        // Confirm detection
        if (textContent.includes('confirm') || textContent.includes('are you sure') || textContent.includes('delete')) {
          let confirmMsg = element.getAttribute('data-confirm') || 
                          element.getAttribute('data-message') ||
                          element.closest('[data-confirm]')?.getAttribute('data-confirm');
          
          if (confirmMsg) {
            e.preventDefault();
            if (window.AlertManager) {
              window.AlertManager.postMessage('confirm://' + encodeURIComponent(confirmMsg));
              console.log("❓ Confirm triggered via text for:", confirmMsg);
            }
            return false;
          }
        }
        
        // Prompt detection
        if (textContent.includes('input') || textContent.includes('enter') || textContent.includes('prompt')) {
          let promptMsg = element.getAttribute('data-prompt') || 
                         element.getAttribute('data-message') ||
                         element.closest('[data-prompt]')?.getAttribute('data-prompt');
          let defaultValue = element.getAttribute('data-default') || 
                           element.closest('[data-default]')?.getAttribute('data-default') || '';
          
          if (promptMsg) {
            e.preventDefault();
            if (window.AlertManager) {
              let promptUrl = 'prompt://message=' + encodeURIComponent(promptMsg);
              if (defaultValue) {
                promptUrl += '&default=' + encodeURIComponent(defaultValue);
              }
              window.AlertManager.postMessage(promptUrl);
              console.log("✏️ Prompt triggered via text for:", promptMsg);
            }
            return false;
          }
        }
        
        // Toast detection
        if (textContent.includes('toast') || textContent.includes('notification') || textContent.includes('message')) {
          let toastMsg = element.getAttribute('data-toast') || 
                        element.getAttribute('data-message') ||
                        element.closest('[data-toast]')?.getAttribute('data-toast');
          
          if (toastMsg) {
            e.preventDefault();
            if (window.ToastManager) {
              window.ToastManager.postMessage('toast://' + encodeURIComponent(toastMsg));
              console.log("🍞 Toast triggered via text for:", toastMsg);
            }
            return false;
          }
        }
        
        // Barcode detection
        if (href?.includes('barcode') || href?.includes('scan') || textContent.includes('scan barcode') || textContent.includes('qr code')) {
          e.preventDefault();
          if (window.BarcodeScanner) {
            window.BarcodeScanner.postMessage('scan');
            console.log("📱 Barcode scan triggered via text");
          }
          return false;
        }
        
        // Logout detection
        if (textContent.includes('logout') || textContent.includes('log out') || textContent.includes('sign out')) {
          e.preventDefault();
          if (window.AuthManager) {
            window.AuthManager.postMessage('logout');
            console.log("🚪 Logout triggered via text");
          }
          return false;
        }
        
        // Location detection
        if (textContent.includes('get location') || textContent.includes('current location') || textContent.includes('my location')) {
          e.preventDefault();
          if (window.LocationManager) {
            window.LocationManager.postMessage('getCurrentLocation');
            console.log("🌍 Location request triggered via text");
          }
          return false;
        }
        
        // Contacts detection
        if (textContent.includes('get contacts') || textContent.includes('load contacts') || textContent.includes('contact list')) {
          e.preventDefault();
          if (window.ContactsManager) {
            window.ContactsManager.postMessage('getAllContacts');
            console.log("📞 Contacts request triggered via text");
          }
          return false;
        }
        
        // Screenshot detection
        if (textContent.includes('screenshot') || textContent.includes('capture screen') || textContent.includes('take screenshot')) {
          e.preventDefault();
          if (window.ScreenshotManager) {
            window.ScreenshotManager.postMessage('takeScreenshot');
            console.log("📸 Screenshot triggered via text");
          }
          return false;
        }
        
        // Image save detection by text
        if (textContent.includes('save image') || textContent.includes('download image') || textContent.includes('save photo')) {
          let imgElement = element.querySelector('img') || element.closest('img') || element.previousElementSibling?.querySelector('img') || element.nextElementSibling?.querySelector('img');
          if (imgElement && imgElement.src) {
            e.preventDefault();
            if (window.ImageSaver) {
              window.ImageSaver.postMessage('save-image://' + imgElement.src);
              console.log("🖼️ Image save triggered via text for:", imgElement.src);
            }
            return false;
          }
        }
        
        // PDF save detection by text
        if (textContent.includes('save pdf') || textContent.includes('download pdf') || textContent.includes('save document') || textContent.includes('download document')) {
          let linkElement = element.querySelector('a[href*=".pdf"]') || 
                           element.closest('a[href*=".pdf"]') || 
                           element.previousElementSibling?.querySelector('a[href*=".pdf"]') ||
                           element.nextElementSibling?.querySelector('a[href*=".pdf"]');
          
          if (linkElement && linkElement.href) {
            e.preventDefault();
            if (window.PdfSaver) {
              window.PdfSaver.postMessage('save-pdf://' + linkElement.href);
              console.log("📄 PDF save triggered via text for:", linkElement.href);
            } else {
              console.error("❌ PdfSaver not available");
            }
            return false;
          }
          
          let pdfUrl = element.getAttribute('data-pdf-url') || 
                      element.getAttribute('data-document-url') ||
                      element.closest('[data-pdf-url]')?.getAttribute('data-pdf-url');
          
          if (pdfUrl) {
            e.preventDefault();
            if (window.PdfSaver) {
              window.PdfSaver.postMessage('save-pdf://' + pdfUrl);
              console.log("📄 PDF save triggered via data attribute:", pdfUrl);
            }
            return false;
          }
        }
        
        // Auto-detect PDF links on any click
        if (href && (href.toLowerCase().includes('.pdf') || href.toLowerCase().includes('pdf'))) {
          if (textContent.includes('save') || textContent.includes('download') || element.classList.contains('save-pdf') || element.classList.contains('download-pdf')) {
            e.preventDefault();
            if (window.PdfSaver) {
              window.PdfSaver.postMessage('save-pdf://' + href);
              console.log("📄 PDF save auto-detected for:", href); 
            }
            return false;
          }
        }
        
        element = element.parentElement;
      }
    }, true);

    // Enhanced utility object with complete feature set
    window.ERPForever = {
      // Alert System
      showAlert: function(message) {
        console.log('🚨 Showing alert:', message);
        if (window.AlertManager) {
          if (typeof message === 'string' && message.trim()) {
            window.AlertManager.postMessage('alert://' + encodeURIComponent(message));
          } else {
            console.error('❌ Invalid alert message');
          }
        } else {
          console.error('❌ AlertManager not available');
        }
      },
      
      showConfirm: function(message) {
        console.log('❓ Showing confirm:', message);
        if (window.AlertManager) {
          if (typeof message === 'string' && message.trim()) {
            window.AlertManager.postMessage('confirm://' + encodeURIComponent(message));
          } else {
            console.error('❌ Invalid confirm message');
          }
        } else {
          console.error('❌ AlertManager not available');
        }
      },
      
      showPrompt: function(message, defaultValue = '') {
        console.log('✏️ Showing prompt:', message, 'default:', defaultValue);
        if (window.AlertManager) {
          if (typeof message === 'string' && message.trim()) {
            let promptUrl = 'prompt://message=' + encodeURIComponent(message);
            if (defaultValue) {
              promptUrl += '&default=' + encodeURIComponent(defaultValue);
            }
            window.AlertManager.postMessage(promptUrl);
          } else {
            console.error('❌ Invalid prompt message');
          }
        } else {
          console.error('❌ AlertManager not available');
        }
      },
      
      // Toast System
      showToast: function(message) {
        console.log('🍞 Showing toast:', message);
        if (window.ToastManager) {
          if (typeof message === 'string' && message.trim()) {
            window.ToastManager.postMessage('toast://' + encodeURIComponent(message));
          } else {
            console.error('❌ Invalid toast message');
          }
        } else {
          console.error('❌ ToastManager not available');
        }
      },
      
      // Contact System
      getAllContacts: function() {
        console.log('📞 Getting all contacts...');
        if (window.ContactsManager) {
          window.ContactsManager.postMessage('getAllContacts');
        } else {
          console.error('❌ ContactsManager not available');
        }
      },
      
      // Screenshot System
      takeScreenshot: function() {
        console.log('📸 Taking screenshot...');
        if (window.ScreenshotManager) {
          window.ScreenshotManager.postMessage('takeScreenshot');
        } else {
          console.error('❌ ScreenshotManager not available');
        }
      },
      
      // Image Save System
      saveImage: function(imageUrl) {
        console.log('🖼️ Saving image:', imageUrl);
        if (window.ImageSaver) {
          if (!imageUrl.startsWith('save-image://')) {
            imageUrl = 'save-image://' + imageUrl;
          }
          window.ImageSaver.postMessage(imageUrl);
        } else {
          console.error('❌ ImageSaver not available');
        }
      },
      
      // PDF Save System
      savePdf: function(pdfUrl) {
        console.log('📄 Saving PDF:', pdfUrl);
        if (window.PdfSaver) {
          if (!pdfUrl || typeof pdfUrl !== 'string') {
            console.error('❌ Invalid PDF URL provided');
            return false;
          }
          
          if (!pdfUrl.startsWith('save-pdf://')) {
            pdfUrl = 'save-pdf://' + pdfUrl;
          }
          
          window.PdfSaver.postMessage(pdfUrl);
          return true;
        } else {
          console.error('❌ PdfSaver not available');
          return false;
        }
      },
      
      // Location System
      getCurrentLocation: function() {
        console.log('🌍 Getting current location...');
        if (window.LocationManager) {
          window.LocationManager.postMessage('getCurrentLocation');
        } else {
          console.error('❌ LocationManager not available');
        }
      },
      
      // Barcode System
      scanBarcode: function() {
        console.log('📸 Scanning barcode...');
        if (window.BarcodeScanner) {
          window.BarcodeScanner.postMessage('scan');
        } else {
          console.error('❌ BarcodeScanner not available');
        }
      },
      
      scanBarcodeContinuous: function() {
        console.log('📸 Scanning barcode (continuous)...');
        if (window.BarcodeScanner) {
          window.BarcodeScanner.postMessage('scanContinuous');
        } else {
          console.error('❌ BarcodeScanner not available');
        }
      },
      
      // Theme System
      setTheme: function(theme) {
        console.log('🎨 Setting theme to:', theme);
        if (window.ThemeManager) {
          if (['dark', 'light', 'system'].includes(theme)) {
            window.ThemeManager.postMessage(theme);
          } else {
            console.error('❌ Invalid theme. Use: dark, light, or system');
          }
        } else {
          console.error('❌ ThemeManager not available');
        }
      },
      
      // Auth System
      logout: function() {
        console.log('🚪 Logging out...');
        if (window.AuthManager) {
          window.AuthManager.postMessage('logout');
        } else {
          console.error('❌ AuthManager not available');
        }
      },
      
      // Utility functions
      savePdfFromPage: function() {
        var pdfLinks = document.querySelectorAll('a[href*=".pdf"], a[href*="pdf"]');
        if (pdfLinks.length > 0) {
          this.savePdf(pdfLinks[0].href);
          return true;
        } else {
          console.log('📄 No PDF links found on current page');
          return false;
        }
      },
      
      saveAllPdfs: function() {
        var pdfLinks = document.querySelectorAll('a[href*=".pdf"], a[href*="pdf"]');
        console.log('📄 Found', pdfLinks.length, 'PDF links');
        
        pdfLinks.forEach((link, index) => {
          setTimeout(() => {
            this.savePdf(link.href);
          }, index * 1000);
        });
        
        return pdfLinks.length;
      },
      
      saveAllImages: function() {
        var images = document.querySelectorAll('img[src]');
        console.log('🖼️ Found', images.length, 'images');
        
        images.forEach((img, index) => {
          setTimeout(() => {
            this.saveImage(img.src);
          }, index * 500);
        });
        
        return images.length;
      },
      
      showMultipleAlerts: function(messages) {
        if (Array.isArray(messages)) {
          messages.forEach((msg, index) => {
            setTimeout(() => {
              this.showAlert(msg);
            }, index * 1000);
          });
        } else {
          console.error('❌ Messages must be an array');
        }
      },
      
      // Check availability functions
      isAlertAvailable: function() {
        return !!window.AlertManager;
      },
      
      isToastAvailable: function() {
        return !!window.ToastManager;
      },
      
      isContactsAvailable: function() {
        return !!window.ContactsManager;
      },
      
      isLocationAvailable: function() {
        return !!window.LocationManager;
      },
      
      isBarcodeAvailable: function() {
        return !!window.BarcodeScanner;
      },
      
      isScreenshotAvailable: function() {
        return !!window.ScreenshotManager;
      },
      
      isImageSaverAvailable: function() {
        return !!window.ImageSaver;
      },
      
      isPdfSaverAvailable: function() {
        return !!window.PdfSaver;
      },
      
      isThemeAvailable: function() {
        return !!window.ThemeManager;
      },
      
      isAuthAvailable: function() {
        return !!window.AuthManager;
      },
      
      // Get all available features
      getAvailableFeatures: function() {
        return {
          alerts: this.isAlertAvailable(),
          toasts: this.isToastAvailable(),
          contacts: this.isContactsAvailable(),
          location: this.isLocationAvailable(),
          barcode: this.isBarcodeAvailable(),
          screenshot: this.isScreenshotAvailable(),
          imageSaver: this.isImageSaverAvailable(),
          pdfSaver: this.isPdfSaverAvailable(),
          theme: this.isThemeAvailable(),
          auth: this.isAuthAvailable()
        };
      },
      
      // Debug info
      getDebugInfo: function() {
        return {
          version: this.version,
          userAgent: navigator.userAgent,
          features: this.getAvailableFeatures(),
          url: window.location.href,
          timestamp: new Date().toISOString()
        };
      },
      
      version: '1.2.0'
    };

    console.log("✅ ERPForever WebView JavaScript ready!");
    console.log("📚 Usage examples:");
    console.log("  🚨 Alerts:");
    console.log("    - window.ERPForever.showAlert('Hello World!')");
    console.log("    - window.ERPForever.showConfirm('Are you sure?')");
    console.log("    - window.ERPForever.showPrompt('Enter name:', 'Default')");
    console.log("  🍞 Toast:");
    console.log("    - window.ERPForever.showToast('Message sent!')");
    console.log("    - <a href='toast://Hello%20World!'>Show Toast</a>");
    console.log("  📞 Contacts:");
    console.log("    - window.ERPForever.getAllContacts()");
    console.log("  🌍 Location:");
    console.log("    - window.ERPForever.getCurrentLocation()");
    console.log("  📸 Media:");
    console.log("    - window.ERPForever.takeScreenshot()");
    console.log("    - window.ERPForever.saveImage('https://example.com/image.jpg')");
    console.log("    - window.ERPForever.savePdf('https://example.com/document.pdf')");
    console.log("  🎨 Theme:");
    console.log("    - window.ERPForever.setTheme('dark')");
    console.log("  📱 Barcode:");
    console.log("    - window.ERPForever.scanBarcode()");
    console.log("  🚪 Auth:");
    console.log("    - window.ERPForever.logout()");
    
    window.addEventListener('error', function(e) {
      console.error('JavaScript error:', e.error);
    });
    
    var readyEvent = new CustomEvent('ERPForeverReady', { 
      detail: { 
        version: window.ERPForever.version,
        features: window.ERPForever.getAvailableFeatures()
      } 
    });
    document.dispatchEvent(readyEvent);
    
    setTimeout(function() {
      var pdfLinks = document.querySelectorAll('a[href*=".pdf"], a[href*="pdf"]');
      console.log('📄 Found', pdfLinks.length, 'PDF links on page');
      
      pdfLinks.forEach(function(link) {
        if (!link.classList.contains('pdf-detected')) {
          link.classList.add('pdf-detected');
          link.title = (link.title || '') + ' (Click to save PDF)';
          
          if (!link.querySelector('.pdf-icon')) {
            var icon = document.createElement('span');
            icon.className = 'pdf-icon';
            icon.innerHTML = '📄 ';
            icon.style.marginRight = '4px';
            link.insertBefore(icon, link.firstChild);
          }
        }
      });
      
      var images = document.querySelectorAll('img[src]');
      console.log('🖼️ Found', images.length, 'images on page');
      
      var alertElements = document.querySelectorAll('[data-alert], [data-confirm], [data-prompt], [data-toast]');
      console.log('🚨 Found', alertElements.length, 'elements with alert/toast attributes');
      
      alertElements.forEach(function(element) {
        if (!element.classList.contains('alert-detected')) {
          element.classList.add('alert-detected');
          element.style.cursor = 'pointer';
          element.title = element.title || 'Click to show message';
        }
      });
    }, 1000);
    
    console.log("🎉 ERPForever WebView fully initialized with complete feature set!");
    console.log("🔧 Debug info:", window.ERPForever.getDebugInfo());
  ''');
}

  // Update context
void updateContext(BuildContext context) {
  if (_controllerStack.isNotEmpty) {
    _controllerStack.last['context'] = context;
  }
}
  // Clean up
void dispose() {
  _controllerStack.clear();
}

void pushController(WebViewController controller, BuildContext context, String identifier) {
  debugPrint('📚 Pushing controller to stack: $identifier (Stack size will be: ${_controllerStack.length + 1})');
  
  // PREVENT DUPLICATE IDENTIFIERS
  _controllerStack.removeWhere((item) => item['identifier'] == identifier);
  
  _controllerStack.add({
    'controller': controller,
    'context': context,
    'identifier': identifier,
    'timestamp': DateTime.now(),
  });
  
  debugPrint('✅ Controller stack updated. Current: $identifier (Final size: ${_controllerStack.length})');
}

void popController(String identifier) {
  debugPrint('📚 Attempting to pop controller: $identifier (Current stack size: ${_controllerStack.length})');
  
  if (_controllerStack.isEmpty) {
    debugPrint('⚠️ Controller stack is empty, nothing to pop');
    return;
  }
  
  // Find and remove the controller with matching identifier
  _controllerStack.removeWhere((item) => item['identifier'] == identifier);
  
  debugPrint('✅ Controller popped. New stack size: ${_controllerStack.length}');
  
  if (_controllerStack.isNotEmpty) {
    final current = _controllerStack.last;
    debugPrint('🔄 Restored controller: ${current['identifier']}');
  } else {
    debugPrint('📭 Controller stack is now empty');
  }
}
int getStackSize() {
  return _controllerStack.length;
}


void _handleLoginConfigRequest(String loginUrl) async {
  if (_currentContext == null) {
    debugPrint('❌ No context available for login config request');
    return;
  }

  debugPrint('🔗 WebView login config request: $loginUrl');
  
  try {
    // Parse the config URL
    final parsedData = ConfigService.parseLoginConfigUrl(loginUrl);
    
    if (parsedData.isNotEmpty && parsedData.containsKey('configUrl')) {
      final configUrl = parsedData['configUrl']!;
      final userRole = parsedData['role'];
      
      // Show loading dialog
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
                Text('Updating configuration...'),
                if (userRole != null) ...[
                  SizedBox(height: 8),
                  Text('Role: $userRole', style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
          );
        },
      );
      
      // Set the dynamic config URL
      await ConfigService().setDynamicConfigUrl(configUrl, role: userRole);
      
      // Hide loading dialog
      if (_currentContext != null && Navigator.canPop(_currentContext!)) {
        Navigator.of(_currentContext!).pop();
      }
      
      // Show success feedback
      if (_currentContext != null) {
        ScaffoldMessenger.of(_currentContext!).showSnackBar(
          SnackBar(
            content: Text('Configuration updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } else {
      if (_currentContext != null) {
        ScaffoldMessenger.of(_currentContext!).showSnackBar(
          SnackBar(
            content: Text('Invalid configuration URL'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('❌ Error in WebView config request: $e');
    
    if (_currentContext != null) {
      // Hide loading dialog if open
      if (Navigator.canPop(_currentContext!)) {
        Navigator.of(_currentContext!).pop();
      }
      
      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


void clearCurrentController() {
  debugPrint('🧹 Clearing all controller references');
  _controllerStack.clear();
}
bool isControllerValid() {
  return _currentController != null && _currentContext != null;
}
void updateController(WebViewController controller, BuildContext context) {
  // This method is now used for MainScreen only
  final identifier = 'MainScreen_${DateTime.now().millisecondsSinceEpoch}';
  pushController(controller, context, identifier);
}

}
