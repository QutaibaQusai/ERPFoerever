// lib/services/alert_service.dart
import 'package:flutter/material.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  /// Show alert dialog from URL-encoded message
  Future<Map<String, dynamic>> showAlertFromUrl(String alertUrl, BuildContext context) async {
    try {
      debugPrint('🚨 Processing alert request: $alertUrl');

      // Extract message from URL
      String message = extractAlertMessage(alertUrl);
      
      if (message.isEmpty) {
        return {
          'success': false,
          'error': 'Alert message is empty',
          'errorCode': 'EMPTY_MESSAGE'
        };
      }

      debugPrint('📝 Alert message: $message');

      // Show alert dialog
      bool? result = await _showAlertDialog(context, message);

      return {
        'success': true,
        'message': message,
        'userResponse': result == true ? 'OK' : 'Dismissed',
        'dismissed': result != true,
      };

    } catch (e) {
      debugPrint('❌ Error showing alert: $e');
      return {
        'success': false,
        'error': 'Failed to show alert: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR'
      };
    }
  }

  /// Show confirm dialog from URL-encoded message
  Future<Map<String, dynamic>> showConfirmFromUrl(String confirmUrl, BuildContext context) async {
    try {
      debugPrint('❓ Processing confirm request: $confirmUrl');

      // Extract message from URL
      String message = extractAlertMessage(confirmUrl);
      
      if (message.isEmpty) {
        return {
          'success': false,
          'error': 'Confirm message is empty',
          'errorCode': 'EMPTY_MESSAGE'
        };
      }

      debugPrint('📝 Confirm message: $message');

      // Show confirm dialog
      bool? result = await _showConfirmDialog(context, message);

      return {
        'success': true,
        'message': message,
        'userResponse': result == true ? 'OK' : (result == false ? 'Cancel' : 'Dismissed'),
        'confirmed': result == true,
        'cancelled': result == false,
        'dismissed': result == null,
      };

    } catch (e) {
      debugPrint('❌ Error showing confirm: $e');
      return {
        'success': false,
        'error': 'Failed to show confirm: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR'
      };
    }
  }

  /// Show prompt dialog from URL-encoded message
  Future<Map<String, dynamic>> showPromptFromUrl(String promptUrl, BuildContext context) async {
    try {
      debugPrint('✏️ Processing prompt request: $promptUrl');

      // Extract message and default value from URL
      Map<String, String> params = extractPromptParams(promptUrl);
      String message = params['message'] ?? '';
      String defaultValue = params['default'] ?? '';
      
      if (message.isEmpty) {
        return {
          'success': false,
          'error': 'Prompt message is empty',
          'errorCode': 'EMPTY_MESSAGE'
        };
      }

      debugPrint('📝 Prompt message: $message, default: $defaultValue');

      // Show prompt dialog
      String? result = await _showPromptDialog(context, message, defaultValue);

      return {
        'success': true,
        'message': message,
        'defaultValue': defaultValue,
        'userInput': result ?? '',
        'confirmed': result != null,
        'cancelled': result == null,
      };

    } catch (e) {
      debugPrint('❌ Error showing prompt: $e');
      return {
        'success': false,
        'error': 'Failed to show prompt: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR'
      };
    }
  }

  /// Extract alert message from URL
  String extractAlertMessage(String url) {
    try {
      // Remove protocol
      String cleanUrl = url.replaceAll(RegExp(r'^(alert|confirm|prompt)://'), '');
      
      // URL decode
      return Uri.decodeComponent(cleanUrl);
    } catch (e) {
      debugPrint('❌ Error extracting message from URL: $e');
      return '';
    }
  }

  /// Extract prompt parameters from URL
  Map<String, String> extractPromptParams(String url) {
    try {
      // Remove protocol
      String cleanUrl = url.replaceAll('prompt://', '');
      
      // Parse as URI to handle query parameters
      Uri uri = Uri.parse('dummy://?' + cleanUrl);
      
      Map<String, String> params = {};
      
      if (uri.queryParameters.containsKey('message')) {
        params['message'] = uri.queryParameters['message'] ?? '';
      } else if (uri.queryParameters.containsKey('msg')) {
        params['message'] = uri.queryParameters['msg'] ?? '';
      } else {
        // If no query params, treat entire string as message
        params['message'] = Uri.decodeComponent(cleanUrl.split('&')[0]);
      }
      
      params['default'] = uri.queryParameters['default'] ?? uri.queryParameters['value'] ?? '';
      
      return params;
    } catch (e) {
      debugPrint('❌ Error extracting prompt params: $e');
      return {'message': '', 'default': ''};
    }
  }

  /// Show basic alert dialog
  Future<bool?> _showAlertDialog(BuildContext context, String message) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Alert',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show confirm dialog with OK/Cancel
  Future<bool?> _showConfirmDialog(BuildContext context, String message) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: Row(
            children: [
              Icon(
                Icons.help_outline,
                color: Colors.orange,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Confirm',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show prompt dialog with text input
  Future<String?> _showPromptDialog(BuildContext context, String message, String defaultValue) async {
    final TextEditingController controller = TextEditingController(text: defaultValue);
    
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                color: Colors.green,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Input',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your input...',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Validate alert URL format
  bool isValidAlertUrl(String url) {
    return url.startsWith('alert://') || 
           url.startsWith('confirm://') || 
           url.startsWith('prompt://');
  }

  /// Get alert type from URL
  String getAlertType(String url) {
    if (url.startsWith('alert://')) return 'alert';
    if (url.startsWith('confirm://')) return 'confirm';
    if (url.startsWith('prompt://')) return 'prompt';
    return 'unknown';
  }
}