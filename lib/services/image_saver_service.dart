// lib/services/image_saver_service.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
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
          'errorCode': 'INVALID_URL'
        };
      }

      // Clean up URL (handle the double slash issue)
      String cleanUrl = imageUrl.replaceAll('save-image://', '').replaceAll('https//', 'https://');
      debugPrint('🔗 Cleaned URL: $cleanUrl');

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

      // Download image
      debugPrint('⬇️ Downloading image...');
      final response = await http.get(
        Uri.parse(cleanUrl),
        headers: {
          'User-Agent': 'ERPForever-Flutter-App/1.0',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('❌ Failed to download image: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to download image (${response.statusCode})',
          'errorCode': 'DOWNLOAD_FAILED'
        };
      }

      final Uint8List imageBytes = response.bodyBytes;
      debugPrint('✅ Image downloaded successfully (${imageBytes.length} bytes)');

      // Get file extension from URL or content type
      String fileExtension = _getFileExtension(cleanUrl, response.headers['content-type']);
      
      // Generate filename
      String fileName = 'ERPForever_Image_${DateTime.now().millisecondsSinceEpoch}$fileExtension';

      // Save to gallery
      final result = await ImageGallerySaver.saveImage(
        imageBytes,
        quality: 100,
        name: fileName.replaceAll('.', '_'), // Remove extension for name
      );

      if (result['isSuccess'] == true) {
        debugPrint('✅ Image saved to gallery: ${result['filePath']}');
        return {
          'success': true,
          'filePath': result['filePath'],
          'fileName': fileName,
          'fileSize': imageBytes.length,
          'message': 'Image saved to gallery',
          'url': cleanUrl,
        };
      } else {
        debugPrint('❌ Failed to save image to gallery');
        return {
          'success': false,
          'error': 'Failed to save image to gallery',
          'errorCode': 'SAVE_FAILED'
        };
      }

    } catch (e) {
      debugPrint('❌ Error saving image: $e');
      return {
        'success': false,
        'error': 'Failed to save image: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR'
      };
    }
  }

  /// Save image to app documents directory
  Future<Map<String, dynamic>> saveImageToDocuments(String imageUrl) async {
    try {
      debugPrint('📁 Saving image to documents...');

      // Clean URL
      String cleanUrl = imageUrl.replaceAll('save-image://', '').replaceAll('https//', 'https://');

      // Download image
      final response = await http.get(Uri.parse(cleanUrl)).timeout(Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        return {
          'success': false,
          'error': 'Failed to download image (${response.statusCode})',
          'errorCode': 'DOWNLOAD_FAILED'
        };
      }

      final Uint8List imageBytes = response.bodyBytes;
      
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      String fileExtension = _getFileExtension(cleanUrl, response.headers['content-type']);
      String fileName = 'image_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      
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
        'errorCode': 'UNKNOWN_ERROR'
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

  /// Extract image URL from save-image:// protocol
  String extractImageUrl(String saveImageUrl) {
    return saveImageUrl
        .replaceAll('save-image://', '')
        .replaceAll('https//', 'https://')
        .replaceAll('http//', 'http://');
  }

  /// Validate if URL is an image
  bool isValidImageUrl(String url) {
    const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'];
    String lowerUrl = url.toLowerCase();
    
    return imageExtensions.any((ext) => lowerUrl.contains(ext)) ||
           lowerUrl.contains('image') ||
           lowerUrl.contains('photo') ||
           lowerUrl.contains('pic');
  }
}