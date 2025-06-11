// lib/pages/login_page.dart - Updated with config URL support
import 'package:ERPForever/pages/no_internet_page.dart';
import 'package:ERPForever/services/internet_connection_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ERPForever/widgets/loading_widget.dart';
import 'package:ERPForever/pages/main_screen.dart';
import 'package:ERPForever/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late WebViewController _controller;
  bool _isLoading = true;
    bool _splashRemoved = false; // NEW: Track splash removal


  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }
void _initializeWebView() {
  // NEW: Check internet connection before initializing WebView
  final internetService = Provider.of<InternetConnectionService>(context, listen: false);
  if (!internetService.isConnected) {
    debugPrint('🚫 No internet connection - skipping WebView initialization');
    _tryRemoveSplash();
    return;
  }

  _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          debugPrint('🔄 Login page started loading: $url');
          if (mounted) {
            setState(() {
              _isLoading = true;
            });
          }
        },
        onPageFinished: (String url) {
          debugPrint('✅ Login page finished loading: $url');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          
          // Remove splash when login page is fully loaded
          _tryRemoveSplash();
        },
        onNavigationRequest: (NavigationRequest request) {
          debugPrint('Login Navigation request: ${request.url}');
          
          // Check for loggedin:// protocol with config URL
          if (request.url.startsWith('loggedin://')) {
            _handleLoginSuccess(request.url);
            return NavigationDecision.prevent;
          }
          
          return NavigationDecision.navigate;
        },
        onWebResourceError: (WebResourceError error) {
          debugPrint('Login WebView error: ${error.description}');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          
          // Even on error, remove splash after minimum time
          _tryRemoveSplash();
        },
      ),
    )
    ..loadRequest(Uri.parse('https://mobile.erpforever.com/login'));
}

  
   void _tryRemoveSplash() {
    if (_splashRemoved) return;
    
    debugPrint('🎬 LoginPage: Attempting to remove splash screen...');
    
    // Add a small delay to ensure WebView is fully rendered
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_splashRemoved) {
        try {
          FlutterNativeSplash.remove();
          _splashRemoved = true;
          debugPrint('✅ LoginPage: Splash screen removed - login page is ready!');
        } catch (e) {
          debugPrint('❌ LoginPage: Error removing splash screen: $e');
        }
      }
    });
  }
  void _handleLoginSuccess(String loginUrl) async {
  debugPrint('✅ User logged in successfully with URL: $loginUrl');
  
  try {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    String? configUrl;
    
    if (loginUrl.startsWith('loggedin://')) {
      configUrl = loginUrl;
      debugPrint('🔗 Config URL detected: $configUrl');
      debugPrint('🔄 Processing configuration with login context...');
    }
    
    // 🆕 ENHANCED: Login with config URL and pass context for better app data
    await authService.login(
      configUrl: configUrl,
      context: mounted ? context : null, // Pass context if still mounted
    );
    
    debugPrint('✅ Login successful - navigating to main screen');
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainScreen(),
        ),
      );
    }
    
  } catch (e) {
    debugPrint('❌ Error during login process: $e');
    
    if (mounted) {
      _controller.runJavaScript('''
        const errorMessage = 'Login error: ${e.toString()}';
        if (window.AlertManager) {
          window.AlertManager.postMessage('alert://' + encodeURIComponent(errorMessage));
        } else {
          window.location.href = 'alert://' + encodeURIComponent(errorMessage);
        }
      ''');
      
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  @override
 @override
Widget build(BuildContext context) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  
  return Consumer<InternetConnectionService>(
    builder: (context, internetService, _) {
      // NEW: If no internet, show no internet page
      if (!internetService.isConnected) {
        return const NoInternetPage();
      }
      
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
       
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading) 
              const LoadingWidget(message: "Loading login page..."),
          ],
        ),
      );
    },
  );
}}