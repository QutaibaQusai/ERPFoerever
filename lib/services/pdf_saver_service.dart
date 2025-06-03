// lib/services/pdf_saver_service.dart - FIXED: No native dialogs
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;

class PdfSaverService {
  static final PdfSaverService _instance = PdfSaverService._internal();
  factory PdfSaverService() => _instance;
  PdfSaverService._internal();

  /// Save PDF from URL to device downloads/documents - NO NATIVE DIALOGS
  Future<Map<String, dynamic>> savePdfFromUrl(String pdfUrl) async {
    try {
      debugPrint('📄 Starting PDF save from URL: $pdfUrl');

      // Validate URL
      if (pdfUrl.isEmpty) {
        return {
          'success': false,
          'error': 'PDF URL is empty',
          'errorCode': 'INVALID_URL'
        };
      }

      // Clean up URL (handle the double slash issue)
      String cleanUrl = pdfUrl.replaceAll('save-pdf://', '').replaceAll('http//', 'http://').replaceAll('https//', 'https://');
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

      // Download PDF - NO LOADING DIALOG
      debugPrint('⬇️ Downloading PDF silently...');
      final response = await http.get(
        Uri.parse(cleanUrl),
        headers: {
          'User-Agent': 'ERPForever-Flutter-App/1.0',
          'Accept': 'application/pdf,*/*',
        },
      ).timeout(Duration(seconds: 60));

      if (response.statusCode != 200) {
        debugPrint('❌ Failed to download PDF: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to download PDF (${response.statusCode})',
          'errorCode': 'DOWNLOAD_FAILED'
        };
      }

      final Uint8List pdfBytes = response.bodyBytes;
      debugPrint('✅ PDF downloaded successfully (${pdfBytes.length} bytes)');

      // Validate PDF content
      if (!_isPdfContent(pdfBytes)) {
        debugPrint('❌ Downloaded content is not a valid PDF');
        return {
          'success': false,
          'error': 'Downloaded content is not a valid PDF file',
          'errorCode': 'INVALID_PDF'
        };
      }

      // Generate filename
      String fileName = _generatePdfFileName(cleanUrl);

      // Save to downloads/documents directory
      final result = await _savePdfToStorage(pdfBytes, fileName);

      if (result['success']) {
        debugPrint('✅ PDF saved successfully: ${result['filePath']}');
        return {
          'success': true,
          'filePath': result['filePath'],
          'fileName': fileName,
          'fileSize': pdfBytes.length,
          'message': 'PDF saved successfully',
          'url': cleanUrl,
        };
      } else {
        return result;
      }

    } catch (e) {
      debugPrint('❌ Error saving PDF: $e');
      return {
        'success': false,
        'error': 'Failed to save PDF: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR'
      };
    }
  }

  /// Save PDF bytes to storage
  Future<Map<String, dynamic>> _savePdfToStorage(Uint8List pdfBytes, String fileName) async {
    try {
      Directory? directory;

      // Try to get Downloads directory first
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          // Fallback to external storage
          directory = await getExternalStorageDirectory();
          if (directory != null) {
            directory = Directory('${directory.path}/Downloads');
          }
        }
      }

      // Fallback to documents directory
      if (directory == null || !await directory.exists()) {
        directory = await getApplicationDocumentsDirectory();
      }

      // Create directory if it doesn't exist
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      debugPrint('✅ PDF saved to: ${file.path}');
      return {
        'success': true,
        'filePath': file.path,
        'directory': directory.path,
      };

    } catch (e) {
      debugPrint('❌ Error saving PDF to storage: $e');
      return {
        'success': false,
        'error': 'Failed to save PDF to storage: ${e.toString()}',
        'errorCode': 'SAVE_FAILED'
      };
    }
  }

  // Keep all existing helper methods unchanged...
  bool _isPdfContent(Uint8List bytes) {
    if (bytes.length < 4) return false;
    
    // Check PDF magic number: %PDF
    return bytes[0] == 0x25 && // %
           bytes[1] == 0x50 && // P
           bytes[2] == 0x44 && // D
           bytes[3] == 0x46;   // F
  }

  String _generatePdfFileName(String url) {
    try {
      // Try to get filename from URL
      String urlFileName = path.basename(Uri.parse(url).path);
      
      if (urlFileName.isNotEmpty && urlFileName.contains('.pdf')) {
        // Clean the filename
        urlFileName = urlFileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        return urlFileName;
      }
    } catch (e) {
      debugPrint('Error parsing URL for filename: $e');
    }

    // Generate default filename
    return 'ERPForever_PDF_${DateTime.now().millisecondsSinceEpoch}.pdf';
  }

  /// Open saved PDF file - NO NATIVE DIALOG
  Future<Map<String, dynamic>> openPdf(String filePath) async {
    try {
      debugPrint('📖 Opening PDF: $filePath');
      
      final result = await OpenFile.open(filePath);
      
      if (result.type == ResultType.done) {
        debugPrint('✅ PDF opened successfully');
        return {
          'success': true,
          'message': 'PDF opened successfully'
        };
      } else {
        debugPrint('❌ Failed to open PDF: ${result.message}');
        return {
          'success': false,
          'error': result.message ?? 'Failed to open PDF',
          'errorCode': 'OPEN_FAILED'
        };
      }
      
    } catch (e) {
      debugPrint('❌ Error opening PDF: $e');
      return {
        'success': false,
        'error': 'Failed to open PDF: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR'
      };
    }
  }

  // Keep all remaining methods unchanged...
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

  Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('❌ Error opening app settings: $e');
      return false;
    }
  }

  String extractPdfUrl(String savePdfUrl) {
    return savePdfUrl
        .replaceAll('save-pdf://', '')
        .replaceAll('https//', 'https://')
        .replaceAll('http//', 'http://');
  }

  bool isValidPdfUrl(String url) {
    String lowerUrl = url.toLowerCase();
    
    return lowerUrl.contains('.pdf') ||
           lowerUrl.contains('pdf') ||
           lowerUrl.contains('application/pdf') ||
           lowerUrl.contains('document');
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<List<Map<String, dynamic>>> getSavedPdfs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> files = directory.listSync();
      
      List<Map<String, dynamic>> pdfFiles = [];
      
      for (FileSystemEntity file in files) {
        if (file is File && file.path.toLowerCase().endsWith('.pdf')) {
          final stat = await file.stat();
          pdfFiles.add({
            'path': file.path,
            'name': path.basename(file.path),
            'size': stat.size,
            'sizeFormatted': formatFileSize(stat.size),
            'modified': stat.modified.toIso8601String(),
          });
        }
      }
      
      // Sort by modification date (newest first)
      pdfFiles.sort((a, b) => DateTime.parse(b['modified']).compareTo(DateTime.parse(a['modified'])));
      
      return pdfFiles;
    } catch (e) {
      debugPrint('❌ Error listing saved PDFs: $e');
      return [];
    }
  }
}