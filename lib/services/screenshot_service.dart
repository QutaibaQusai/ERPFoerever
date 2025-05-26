// lib/services/screenshot_service.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:share_plus/share_plus.dart';

class ScreenshotService {
  static final ScreenshotService _instance = ScreenshotService._internal();
  factory ScreenshotService() => _instance;
  ScreenshotService._internal();

  final ScreenshotController _screenshotController = ScreenshotController();
  
  ScreenshotController get controller => _screenshotController;

  /// Take screenshot and return options for the user
  Future<Map<String, dynamic>> takeScreenshot({
    double? pixelRatio,
    Duration? delay,
  }) async {
    try {
      debugPrint('📸 Taking screenshot...');

      // Add delay if specified
      if (delay != null) {
        await Future.delayed(delay);
      }

      // Capture screenshot
      Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: pixelRatio ?? 2.0,
      );

      if (imageBytes == null) {
        debugPrint('❌ Failed to capture screenshot - no image data');
        return {
          'success': false,
          'error': 'Failed to capture screenshot',
          'errorCode': 'CAPTURE_FAILED'
        };
      }

      debugPrint('✅ Screenshot captured successfully (${imageBytes.length} bytes)');

      return {
        'success': true,
        'imageBytes': imageBytes,
        'size': imageBytes.length,
        'message': 'Screenshot captured successfully'
      };

    } catch (e) {
      debugPrint('❌ Error taking screenshot: $e');
      return {
        'success': false,
        'error': 'Failed to take screenshot: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR'
      };
    }
  }

  /// Save screenshot to gallery
  Future<Map<String, dynamic>> saveToGallery(Uint8List imageBytes) async {
    try {
      debugPrint('💾 Saving screenshot to gallery...');

      // Check storage permission
      PermissionStatus permission = await Permission.storage.status;
      
      if (permission.isDenied) {
        debugPrint('🔐 Requesting storage permission...');
        permission = await Permission.storage.request();
        
        if (permission.isDenied) {
          debugPrint('❌ Storage permission denied');
          return {
            'success': false,
            'error': 'Storage permission denied',
            'errorCode': 'PERMISSION_DENIED'
          };
        }
      }

      if (permission.isPermanentlyDenied) {
        debugPrint('❌ Storage permission permanently denied');
        return {
          'success': false,
          'error': 'Storage permission permanently denied. Please enable in settings.',
          'errorCode': 'PERMISSION_DENIED_FOREVER'
        };
      }

      // Save to gallery
      final result = await ImageGallerySaver.saveImage(
        imageBytes,
        quality: 100,
        name: 'ERPForever_Screenshot_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (result['isSuccess'] == true) {
        debugPrint('✅ Screenshot saved to gallery: ${result['filePath']}');
        return {
          'success': true,
          'filePath': result['filePath'],
          'message': 'Screenshot saved to gallery'
        };
      } else {
        debugPrint('❌ Failed to save screenshot to gallery');
        return {
          'success': false,
          'error': 'Failed to save to gallery',
          'errorCode': 'SAVE_FAILED'
        };
      }

    } catch (e) {
      debugPrint('❌ Error saving screenshot: $e');
      return {
        'success': false,
        'error': 'Failed to save screenshot: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR'
      };
    }
  }

  /// Share screenshot
  Future<Map<String, dynamic>> shareScreenshot(Uint8List imageBytes) async {
    try {
      debugPrint('📤 Sharing screenshot...');

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Screenshot from ERPForever App',
        subject: 'Screenshot',
      );

      debugPrint('✅ Screenshot shared successfully');
      return {
        'success': true,
        'message': 'Screenshot shared successfully'
      };

    } catch (e) {
      debugPrint('❌ Error sharing screenshot: $e');
      return {
        'success': false,
        'error': 'Failed to share screenshot: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR'
      };
    }
  }

  /// Save screenshot to app documents directory
  Future<Map<String, dynamic>> saveToDocuments(Uint8List imageBytes) async {
    try {
      debugPrint('📁 Saving screenshot to documents...');

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(imageBytes);
      
      debugPrint('✅ Screenshot saved to documents: ${file.path}');
      return {
        'success': true,
        'filePath': file.path,
        'fileName': fileName,
        'message': 'Screenshot saved to documents'
      };

    } catch (e) {
      debugPrint('❌ Error saving screenshot to documents: $e');
      return {
        'success': false,
        'error': 'Failed to save to documents: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR'
      };
    }
  }

  /// Get storage permission status
  Future<Map<String, dynamic>> getStoragePermissionStatus() async {
    try {
      PermissionStatus permission = await Permission.storage.status;

      return {
        'permission': permission.toString(),
        'canRequest': permission == PermissionStatus.denied,
        'isPermanentlyDenied': permission == PermissionStatus.permanentlyDenied,
        'isGranted': permission == PermissionStatus.granted,
      };
    } catch (e) {
      debugPrint('❌ Error checking storage permission: $e');
      return {
        'permission': 'unknown',
        'canRequest': false,
        'isPermanentlyDenied': false,
        'isGranted': false,
        'error': e.toString(),
      };
    }
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('❌ Error opening app settings: $e');
      return false;
    }
  }

  /// Take screenshot with custom options and handle user choice
  Future<Map<String, dynamic>> takeScreenshotWithOptions({
    double? pixelRatio,
    Duration? delay,
    bool saveToGallery = false,
    bool shareScreenshot = false,
    bool saveToDocuments = false,
  }) async {
    // First take the screenshot
    final screenshotResult = await takeScreenshot(
      pixelRatio: pixelRatio,
      delay: delay,
    );

    if (!screenshotResult['success']) {
      return screenshotResult;
    }

    final imageBytes = screenshotResult['imageBytes'] as Uint8List;
    final Map<String, dynamic> results = {
      'success': true,
      'screenshot': screenshotResult,
      'actions': <String, dynamic>{}
    };

    // Handle additional actions
    if (saveToGallery) {
      final galleryResult = await this.saveToGallery(imageBytes);
      results['actions']['gallery'] = galleryResult;
    }

    if (shareScreenshot) {
      final shareResult = await this.shareScreenshot(imageBytes);
      results['actions']['share'] = shareResult;
    }

    if (saveToDocuments) {
      final documentsResult = await this.saveToDocuments(imageBytes);
      results['actions']['documents'] = documentsResult;
    }

    return results;
  }
}