// lib/services/screenshot_service.dart - FIXED: No native dialogs
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

class ScreenshotService {
  static final ScreenshotService _instance = ScreenshotService._internal();
  factory ScreenshotService() => _instance;
  ScreenshotService._internal();

  final ScreenshotController _screenshotController = ScreenshotController();

  ScreenshotController get controller => _screenshotController;

  /// Take screenshot and return options for the user - NO NATIVE DIALOGS
  Future<Map<String, dynamic>> takeScreenshot({
    double? pixelRatio,
    Duration? delay,
  }) async {
    try {
      debugPrint('📸 Taking screenshot silently...');

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
          'errorCode': 'CAPTURE_FAILED',
        };
      }

      debugPrint(
        '✅ Screenshot captured successfully (${imageBytes.length} bytes)',
      );

      return {
        'success': true,
        'imageBytes': imageBytes,
        'size': imageBytes.length,
        'message': 'Screenshot captured successfully',
      };
    } catch (e) {
      debugPrint('❌ Error taking screenshot: $e');
      return {
        'success': false,
        'error': 'Failed to take screenshot: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
      };
    }
  }

  /// Save screenshot to gallery - NO NATIVE DIALOGS
  Future<Map<String, dynamic>> saveToGallery(Uint8List imageBytes) async {
    try {
      debugPrint('💾 Saving screenshot to gallery silently...');

      // Check if we have permission to save to gallery
      if (!await Gal.hasAccess()) {
        debugPrint('🔐 Requesting gallery permission...');
        bool granted = await Gal.requestAccess();

        if (!granted) {
          debugPrint('❌ Gallery permission denied');
          return {
            'success': false,
            'error': 'Gallery permission denied',
            'errorCode': 'PERMISSION_DENIED',
          };
        }
      }

      // Save to temporary file first
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'ERPForever_Screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(imageBytes);

      // Save to gallery using Gal
      await Gal.putImage(tempFile.path);

      // Clean up temp file
      await tempFile.delete();

      debugPrint('✅ Screenshot saved to gallery successfully');
      return {
        'success': true,
        'fileName': fileName,
        'message': 'Screenshot saved to gallery',
      };
    } catch (e) {
      debugPrint('❌ Error saving screenshot: $e');
      return {
        'success': false,
        'error': 'Failed to save screenshot: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
      };
    }
  }

  /// Share screenshot - NO NATIVE DIALOGS
  Future<Map<String, dynamic>> shareScreenshot(Uint8List imageBytes) async {
    try {
      debugPrint('📤 Sharing screenshot...');

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Screenshot from ERPForever App',
        subject: 'Screenshot',
      );

      debugPrint('✅ Screenshot shared successfully');
      return {'success': true, 'message': 'Screenshot shared successfully'};
    } catch (e) {
      debugPrint('❌ Error sharing screenshot: $e');
      return {
        'success': false,
        'error': 'Failed to share screenshot: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
      };
    }
  }

  /// Save screenshot to app documents directory - NO NATIVE DIALOGS
  Future<Map<String, dynamic>> saveToDocuments(Uint8List imageBytes) async {
    try {
      debugPrint('📁 Saving screenshot to documents silently...');

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(imageBytes);

      debugPrint('✅ Screenshot saved to documents: ${file.path}');
      return {
        'success': true,
        'filePath': file.path,
        'fileName': fileName,
        'message': 'Screenshot saved to documents',
      };
    } catch (e) {
      debugPrint('❌ Error saving screenshot to documents: $e');
      return {
        'success': false,
        'error': 'Failed to save to documents: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
      };
    }
  }

  // Keep all remaining helper methods unchanged...
  Future<Map<String, dynamic>> getGalleryPermissionStatus() async {
    try {
      bool hasAccess = await Gal.hasAccess();

      return {'hasAccess': hasAccess, 'canRequest': !hasAccess};
    } catch (e) {
      debugPrint('❌ Error checking gallery permission: $e');
      return {'hasAccess': false, 'canRequest': false, 'error': e.toString()};
    }
  }

  Future<bool> requestGalleryPermission() async {
    try {
      return await Gal.requestAccess();
    } catch (e) {
      debugPrint('❌ Error requesting gallery permission: $e');
      return false;
    }
  }

  Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('❌ Error opening app settings: $e');
      return false;
    }
  }

  /// Take screenshot with custom options and handle user choice - NO NATIVE DIALOGS
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
      'actions': <String, dynamic>{},
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