// lib/services/image_saver_service.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as path;

class ImageSaverService {
  static final ImageSaverService _instance = ImageSaverService._internal();
  factory ImageSaverService() => _instance;
  ImageSaverService._internal();

  /// Save image from URL to device gallery
  Future<Map<String, dynamic>> saveImageFromUrl(String imageUrl) async {
    try {
      debugPrint('🖼️ Starting image save from URL: $imageUrl');

      // Validate URL
      if (imageUrl.isEmpty) {
        return {
          'success': false,
          'error': 'Image URL is empty',
          'errorCode': 'INVALID_URL',
        };
      }

      // Clean up URL (handle the double slash issue)
      String cleanUrl = imageUrl
          .replaceAll('save-image://', '')
          .replaceAll('https//', 'https://');
      debugPrint('🔗 Cleaned URL: $cleanUrl');

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

      // Download image
      debugPrint('⬇️ Downloading image...');
      final response = await http
          .get(
            Uri.parse(cleanUrl),
            headers: {'User-Agent': 'ERPForever-Flutter-App/1.0'},
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('❌ Failed to download image: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to download image (${response.statusCode})',
          'errorCode': 'DOWNLOAD_FAILED',
        };
      }

      final Uint8List imageBytes = response.bodyBytes;
      debugPrint(
        '✅ Image downloaded successfully (${imageBytes.length} bytes)',
      );

      // Get file extension from URL or content type
      String fileExtension = _getFileExtension(
        cleanUrl,
        response.headers['content-type'],
      );

      // Generate filename
      String fileName =
          'ERPForever_Image_${DateTime.now().millisecondsSinceEpoch}$fileExtension';

      // Save to temporary file first
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(imageBytes);

      // Save to gallery using Gal
      await Gal.putImage(tempFile.path);

      // Clean up temp file
      await tempFile.delete();

      debugPrint('✅ Image saved to gallery successfully');
      return {
        'success': true,
        'fileName': fileName,
        'fileSize': imageBytes.length,
        'message': 'Image saved to gallery',
        'url': cleanUrl,
      };
    } catch (e) {
      debugPrint('❌ Error saving image: $e');
      return {
        'success': false,
        'error': 'Failed to save image: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
      };
    }
  }

  /// Save image to app documents directory
  Future<Map<String, dynamic>> saveImageToDocuments(String imageUrl) async {
    try {
      debugPrint('📁 Saving image to documents...');

      // Clean URL
      String cleanUrl = imageUrl
          .replaceAll('save-image://', '')
          .replaceAll('https//', 'https://');

      // Download image
      final response = await http
          .get(Uri.parse(cleanUrl))
          .timeout(Duration(seconds: 30));

      if (response.statusCode != 200) {
        return {
          'success': false,
          'error': 'Failed to download image (${response.statusCode})',
          'errorCode': 'DOWNLOAD_FAILED',
        };
      }

      final Uint8List imageBytes = response.bodyBytes;

      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      String fileExtension = _getFileExtension(
        cleanUrl,
        response.headers['content-type'],
      );
      String fileName =
          'image_${DateTime.now().millisecondsSinceEpoch}$fileExtension';

      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      debugPrint('✅ Image saved to documents: ${file.path}');
      return {
        'success': true,
        'filePath': file.path,
        'fileName': fileName,
        'fileSize': imageBytes.length,
        'message': 'Image saved to app documents',
        'url': cleanUrl,
      };
    } catch (e) {
      debugPrint('❌ Error saving image to documents: $e');
      return {
        'success': false,
        'error': 'Failed to save image to documents: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
      };
    }
  }

  /// Get file extension from URL or content type
  String _getFileExtension(String url, String? contentType) {
    // Try to get extension from URL
    String urlExtension = path.extension(url).toLowerCase();
    if (urlExtension.isNotEmpty && _isValidImageExtension(urlExtension)) {
      return urlExtension;
    }

    // Try to get extension from content type
    if (contentType != null) {
      if (contentType.contains('jpeg') || contentType.contains('jpg')) {
        return '.jpg';
      } else if (contentType.contains('png')) {
        return '.png';
      } else if (contentType.contains('gif')) {
        return '.gif';
      } else if (contentType.contains('webp')) {
        return '.webp';
      }
    }

    // Default to .jpg
    return '.jpg';
  }

  /// Check if extension is a valid image extension
  bool _isValidImageExtension(String extension) {
    const validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
    return validExtensions.contains(extension.toLowerCase());
  }

  /// Get gallery permission status
  Future<Map<String, dynamic>> getGalleryPermissionStatus() async {
    try {
      bool hasAccess = await Gal.hasAccess();

      return {'hasAccess': hasAccess, 'canRequest': !hasAccess};
    } catch (e) {
      debugPrint('❌ Error checking gallery permission: $e');
      return {'hasAccess': false, 'canRequest': false, 'error': e.toString()};
    }
  }

  /// Request gallery permission
  Future<bool> requestGalleryPermission() async {
    try {
      return await Gal.requestAccess();
    } catch (e) {
      debugPrint('❌ Error requesting gallery permission: $e');
      return false;
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

  /// Extract image URL from save-image:// protocol
  String extractImageUrl(String saveImageUrl) {
    return saveImageUrl
        .replaceAll('save-image://', '')
        .replaceAll('https//', 'https://')
        .replaceAll('http//', 'http://');
  }

  /// Validate if URL is an image
  bool isValidImageUrl(String url) {
    const imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.svg',
    ];
    String lowerUrl = url.toLowerCase();

    return imageExtensions.any((ext) => lowerUrl.contains(ext)) ||
        lowerUrl.contains('image') ||
        lowerUrl.contains('photo') ||
        lowerUrl.contains('pic');
  }
}
