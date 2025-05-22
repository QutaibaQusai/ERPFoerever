import 'package:ERPForever/main.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TestPage extends StatefulWidget {
  final String url;
  
  const TestPage({Key? key, this.url = 'https://www.erpforever.com/mobile/test'}) 
      : super(key: key);

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _mounted = true; // Track if the widget is mounted

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ThemeManager',
        onMessageReceived: (JavaScriptMessage message) {
          // Skip if not mounted
          if (!_mounted) return;
          
          // Handle theme change messages
          if (message.message == 'dark') {
            _updateAppTheme('dark');
          } else if (message.message == 'light') {
            _updateAppTheme('light');
          } else if (message.message == 'system') {
            _updateAppTheme('system');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (!_mounted) return; // Skip if not mounted
            setState(() {
              _isLoading = true;
            });
            print("Test page started loading: $url");
          },
          onNavigationRequest: (NavigationRequest request) {
            // Skip if not mounted
            if (!_mounted) return NavigationDecision.navigate;
            
            // Debug message
            print("Test page navigation to: ${request.url}");
            
            // Handle theme change URLs
            if (request.url.startsWith('dark-mode://')) {
              _updateAppTheme('dark');
              return NavigationDecision.prevent;
            } else if (request.url.startsWith('light-mode://')) {
              _updateAppTheme('light');
              return NavigationDecision.prevent;
            } else if (request.url.startsWith('system-mode://')) {
              _updateAppTheme('system');
              return NavigationDecision.prevent;
            } else if (request.url.startsWith('new-web://')) {
         
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Already in Test Page'),
                  duration: const Duration(seconds: 2),
                ),
              );
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) {
            if (!_mounted) return; 
            setState(() {
              _isLoading = false;
            });
            print("Test page finished loading: $url");
            
            _controller.runJavaScript('''
              // Add listener for theme change buttons
              document.addEventListener('click', function(e) {
                let element = e.target;
                for (let i = 0; i < 4 && element; i++) { // Check up to 3 levels up
                  // Check if element has href attribute that matches theme modes
                  const href = element.getAttribute('href');
                  if (href) {
                    if (href.startsWith('dark-mode://')) {
                      e.preventDefault();
                      console.log('Dark mode requested from test page');
                      window.ThemeManager.postMessage('dark');
                      return false;
                    } else if (href.startsWith('light-mode://')) {
                      e.preventDefault();
                      console.log('Light mode requested from test page');
                      window.ThemeManager.postMessage('light');
                      return false;
                    } else if (href.startsWith('system-mode://')) {
                      e.preventDefault();
                      console.log('System mode requested from test page');
                      window.ThemeManager.postMessage('system');
                      return false;
                    }
                  }
                  element = element.parentElement;
                }
              }, true);
              
              console.log("Theme handling JS initialized in test page");
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            if (!_mounted) return;
            print("Test page web resource error: ${error.description}");
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _mounted = false; 
    super.dispose();
  }

  void _updateAppTheme(String themeMode) {
    if (!_mounted) return; 
    
    print('Updating app theme to: $themeMode from test page');
    MyApp.of(context).updateThemeMode(themeMode);
    
    if (_mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Theme changed to ${_capitalize(themeMode)} mode'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return "${text[0].toUpperCase()}${text.substring(1)}";
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          "Test Page",
          style: GoogleFonts.rubik(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        iconTheme: IconThemeData(
          color: titleColor, 
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(), 
            child: SizedBox(
              height: MediaQuery.of(context).size.height - AppBar().preferredSize.height,
              child: WebViewWidget(controller: _controller),
            ),
          ),
          if (_isLoading) _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      color: isDarkMode ? const Color(0xFF121212) : Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkMode ? Colors.white : Colors.black
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Loading...",
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}