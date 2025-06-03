// lib/pages/login_page.dart - Updated with config URL support
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
            
            // NEW: Remove splash when login page is fully loaded
            _tryRemoveSplash();
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('Login Navigation request: ${request.url}');
            
            // NEW: Check for loggedin:// protocol with config URL
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
            
            // NEW: Even on error, remove splash after minimum time
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
  /// UPDATED: Handle login success with config URL support
  void _handleLoginSuccess(String loginUrl) async {
    debugPrint('✅ User logged in successfully with URL: $loginUrl');
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Parse the login URL to extract config information
      String? configUrl;
      
      if (loginUrl.startsWith('loggedin://')) {
        // Extract everything after loggedin:// as the config URL
        configUrl = loginUrl;
        debugPrint('🔗 Config URL detected: $configUrl');
        
        // Show loading indicator for config processing
        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }
        
        _showConfigProcessingDialog();
      }
      
      // Login with config URL
      await authService.login(configUrl: configUrl);
      
      // Hide any loading dialogs
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              configUrl != null 
                ? 'Logged in successfully! Loading your configuration...'
                : 'Logged in successfully!'
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Navigate to main screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainScreen(),
          ),
        );
      }
      
    } catch (e) {
      debugPrint('❌ Error during login process: $e');
      
      // Hide any loading dialogs
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// NEW: Show dialog while processing config URL
  void _showConfigProcessingDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Processing your configuration...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Setting up your personalized experience',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
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
  }
}