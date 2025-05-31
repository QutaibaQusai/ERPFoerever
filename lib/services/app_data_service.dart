// lib/services/app_data_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppDataService {
  static final AppDataService _instance = AppDataService._internal();
  factory AppDataService() => _instance;
  AppDataService._internal();

  /// Collect app and device data to send to server
  Future<Map<String, String>> collectDataForServer() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      Map<String, String> data = {
        // App Information
        'app_name': packageInfo.appName,
        'app_version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'package_name': packageInfo.packageName,
        
        // Platform Information
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        
        // Timestamps
        'timestamp': DateTime.now().toIso8601String(),
        'timezone': DateTime.now().timeZoneName,
        
        // Source identifier
        'source': 'flutter_app',
        'user_agent': 'ERPForever-Flutter-App/1.0',
      };

      // Add platform-specific data
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        data.addAll({
          'device_brand': androidInfo.brand,
          'device_model': androidInfo.model,
          'device_manufacturer': androidInfo.manufacturer,
          'android_version': androidInfo.version.release,
          'sdk_int': androidInfo.version.sdkInt.toString(),
          'is_physical_device': androidInfo.isPhysicalDevice.toString(),
        });
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        data.addAll({
          'device_name': iosInfo.name,
          'device_model': iosInfo.model,
          'system_name': iosInfo.systemName,
          'system_version': iosInfo.systemVersion,
          'is_physical_device': iosInfo.isPhysicalDevice.toString(),
        });
      }

      debugPrint('📊 Collected ${data.length} data fields for server');
      return data;
      
    } catch (e) {
      debugPrint('❌ Error collecting app data: $e');
      return {
        'error': 'Failed to collect app data',
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'flutter_app',
      };
    }
  }

  /// Convert data to URL query string
  String dataToQueryString(Map<String, String> data) {
    return data.entries
        .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
        .join('&');
  }
}