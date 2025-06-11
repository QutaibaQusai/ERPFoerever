// lib/services/internet_connection_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class InternetConnectionService extends ChangeNotifier with WidgetsBindingObserver {
  static final InternetConnectionService _instance = InternetConnectionService._internal();
  factory InternetConnectionService() => _instance;
  InternetConnectionService._internal();

  bool _isConnected = true;
  bool _hasEverBeenConnected = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _retryTimer;

  bool get isConnected => _isConnected;
  bool get hasEverBeenConnected => _hasEverBeenConnected;

  /// Initialize internet connection monitoring
  Future<void> initialize() async {
    try {
      // Add app lifecycle observer
      WidgetsBinding.instance.addObserver(this);
      
      // Check initial connectivity
      await _checkInitialConnectivity();
      
      // Start monitoring connectivity changes
      _startConnectivityMonitoring();
      
      debugPrint('🌐 InternetConnectionService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing InternetConnectionService: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed - checking internet connection');
      _checkConnectivityImmediately();
    }
  }

  /// Immediately check connectivity (for app resume)
  Future<void> _checkConnectivityImmediately() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult != ConnectivityResult.none) {
        final hasInternet = await _hasInternetAccess();
        _updateConnectionStatus(hasInternet);
      } else {
        _updateConnectionStatus(false);
      }
    } catch (e) {
      debugPrint('❌ Error in immediate connectivity check: $e');
      _updateConnectionStatus(false);
    }
  }

  /// Check initial connectivity status
  Future<void> _checkInitialConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult != ConnectivityResult.none) {
        // We have a connection type, but let's verify with actual internet access
        final hasInternet = await _hasInternetAccess();
        _updateConnectionStatus(hasInternet);
      } else {
        _updateConnectionStatus(false);
      }
    } catch (e) {
      debugPrint('❌ Error checking initial connectivity: $e');
      _updateConnectionStatus(false);
    }
  }

  /// Start monitoring connectivity changes
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) async {
        debugPrint('🔄 Connectivity changed: $result');
        
        if (result == ConnectivityResult.none) {
          _updateConnectionStatus(false);
        } else {
          // We have a connection type, verify actual internet access
          final hasInternet = await _hasInternetAccess();
          _updateConnectionStatus(hasInternet);
        }
      },
      onError: (error) {
        debugPrint('❌ Connectivity monitoring error: $error');
        _updateConnectionStatus(false);
      },
    );
  }

  /// Check if device has actual internet access (not just connected to WiFi/Mobile)
  Future<bool> _hasInternetAccess() async {
    try {
      // Try to reach Google's public DNS
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      final hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      debugPrint('🌐 Internet access check: $hasInternet');
      return hasInternet;
    } catch (e) {
      debugPrint('❌ Internet access check failed: $e');
      return false;
    }
  }

  /// Update connection status and notify listeners
  void _updateConnectionStatus(bool isConnected) {
    final wasConnected = _isConnected;
    _isConnected = isConnected;
    
    if (isConnected) {
      _hasEverBeenConnected = true;
      _retryTimer?.cancel(); // Cancel any retry attempts
    }

    if (wasConnected != isConnected) {
      debugPrint(isConnected ? '✅ Internet connected' : '❌ Internet disconnected');
      notifyListeners();
      
      // Start retry mechanism when disconnected
      if (!isConnected) {
        _startRetryMechanism();
      }
    }
  }

  /// Start automatic retry mechanism when disconnected
  void _startRetryMechanism() {
    _retryTimer?.cancel();
    
    _retryTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!_isConnected) {
        debugPrint('🔄 Retrying internet connection check...');
        final hasInternet = await _hasInternetAccess();
        _updateConnectionStatus(hasInternet);
        
        if (hasInternet) {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Manual retry method for user-triggered retries
  Future<bool> retryConnection() async {
    debugPrint('🔄 Manual retry initiated...');
    
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult != ConnectivityResult.none) {
        final hasInternet = await _hasInternetAccess();
        _updateConnectionStatus(hasInternet);
        return hasInternet;
      } else {
        _updateConnectionStatus(false);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Manual retry failed: $e');
      _updateConnectionStatus(false);
      return false;
    }
  }

  /// Get connection type string for display
  Future<String> getConnectionType() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      switch (connectivityResult) {
        case ConnectivityResult.wifi:
          return 'WiFi';
        case ConnectivityResult.mobile:
          return 'Mobile Data';
        case ConnectivityResult.ethernet:
          return 'Ethernet';
        case ConnectivityResult.bluetooth:
          return 'Bluetooth';
        case ConnectivityResult.vpn:
          return 'VPN';
        case ConnectivityResult.none:
        default:
          return 'No Connection';
      }
    } catch (e) {
      debugPrint('❌ Error getting connection type: $e');
      return 'Unknown';
    }
  }

  /// Check if we should show connection message
  bool shouldShowConnectionMessage() {
    return !_isConnected && _hasEverBeenConnected;
  }

  /// Get appropriate error message based on connection state
  String getConnectionMessage() {
    if (!_hasEverBeenConnected) {
      return 'Unable to connect to the internet. Please check your connection and try again.';
    } else {
      return 'Internet connection lost. Attempting to reconnect...';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}