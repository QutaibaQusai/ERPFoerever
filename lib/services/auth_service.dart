// lib/services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const String _isLoggedInKey = 'isLoggedIn';
  
  bool _isLoggedIn = false;
  bool _isLoading = false;
  
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  AuthService() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      
      debugPrint('📱 Auth state loaded: isLoggedIn = $_isLoggedIn');
    } catch (e) {
      debugPrint('❌ Error loading auth state: $e');
      _isLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login() async {
    try {
      debugPrint('🔄 Attempting to save login state...');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      
      _isLoggedIn = true;
      notifyListeners();
      
      debugPrint('✅ User logged in and state saved to SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error saving login state: $e');
      // Even if SharedPreferences fails, we can still proceed with the session
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      debugPrint('🔄 Attempting to clear login state...');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, false);
      
      _isLoggedIn = false;
      notifyListeners();
      
      debugPrint('✅ User logged out and state cleared from SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error clearing login state: $e');
      // Even if SharedPreferences fails, we still logout the session
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  Future<bool> checkAuthState() async {
    await _loadAuthState();
    return _isLoggedIn;
  }
}