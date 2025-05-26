// lib/services/location_service.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Get current location with proper permission handling
  Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      debugPrint('🌍 Location service: Starting location request...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled');
        return {
          'success': false,
          'error': 'Location services are disabled. Please enable location services.',
          'errorCode': 'SERVICE_DISABLED'
        };
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        debugPrint('🔐 Location permission denied, requesting permission...');
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          debugPrint('❌ Location permission denied by user');
          return {
            'success': false,
            'error': 'Location permission denied. Please grant location access.',
            'errorCode': 'PERMISSION_DENIED'
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission permanently denied');
        return {
          'success': false,
          'error': 'Location permission permanently denied. Please enable in settings.',
          'errorCode': 'PERMISSION_DENIED_FOREVER'
        };
      }

      debugPrint('✅ Location permission granted, getting position...');

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      debugPrint('📍 Location obtained: ${position.latitude}, ${position.longitude}');
      debugPrint('📍 Accuracy: ${position.accuracy}m');

      return {
        'success': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': position.timestamp?.toIso8601String(),
      };

    } on LocationServiceDisabledException {
      debugPrint('❌ Location services are disabled');
      return {
        'success': false,
        'error': 'Location services are disabled. Please enable location services.',
        'errorCode': 'SERVICE_DISABLED'
      };
    } on PermissionDeniedException {
      debugPrint('❌ Location permission denied');
      return {
        'success': false,
        'error': 'Location permission denied. Please grant location access.',
        'errorCode': 'PERMISSION_DENIED'
      };
    } }
  /// Get last known location (faster but might be outdated)
  Future<Map<String, dynamic>> getLastKnownLocation() async {
    try {
      debugPrint('🌍 Getting last known location...');

      Position? position = await Geolocator.getLastKnownPosition();
      
      if (position != null) {
        debugPrint('📍 Last known location: ${position.latitude}, ${position.longitude}');
        return {
          'success': true,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'altitude': position.altitude,
          'heading': position.heading,
          'speed': position.speed,
          'timestamp': position.timestamp?.toIso8601String(),
          'isLastKnown': true,
        };
      } else {
        debugPrint('❌ No last known location available');
        return {
          'success': false,
          'error': 'No last known location available',
          'errorCode': 'NO_LAST_KNOWN_LOCATION'
        };
      }
    } catch (e) {
      debugPrint('❌ Error getting last known location: $e');
      return {
        'success': false,
        'error': 'Failed to get last known location: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR'
      };
    }
  }

  /// Check current location permission status
  Future<Map<String, dynamic>> getLocationPermissionStatus() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      return {
        'serviceEnabled': serviceEnabled,
        'permission': permission.toString(),
        'canRequest': permission == LocationPermission.denied,
        'isPermanentlyDenied': permission == LocationPermission.deniedForever,
      };
    } catch (e) {
      debugPrint('❌ Error checking location permission: $e');
      return {
        'serviceEnabled': false,
        'permission': 'unknown',
        'canRequest': false,
        'isPermanentlyDenied': false,
        'error': e.toString(),
      };
    }
  }

  /// Open app settings (useful when permission is permanently denied)
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('❌ Error opening app settings: $e');
      return false;
    }
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('❌ Error opening location settings: $e');
      return false;
    }
  }
}