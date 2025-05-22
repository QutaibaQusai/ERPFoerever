import 'package:ERPForever/main.dart'; 
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ApprovalDetailsPage extends StatefulWidget {
  const ApprovalDetailsPage({Key? key}) : super(key: key);

  @override
  State<ApprovalDetailsPage> createState() => _ApprovalDetailsPageState();
}

class _ApprovalDetailsPageState extends State<ApprovalDetailsPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _mounted = true; 

  @override
  void initState() {
    super.initState();

    _controller =
        WebViewController()
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
                print("Approval page started loading: $url");
              },
              onNavigationRequest: (NavigationRequest request) {
                // Skip if not mounted
                if (!_mounted) return NavigationDecision.navigate;

                // Debug message
                print("Approval navigation to: ${request.url}");

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
                }
                // Allow all other navigation, keeping the WebView open
                return NavigationDecision.navigate;
              },
              onPageFinished: (String url) {
                if (!_mounted) return; // Skip if not mounted
                setState(() {
                  _isLoading = false;
                });
                print("Approval page finished loading: $url");

                // Inject JavaScript for theme management
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
                      console.log('Dark mode requested from approval page');
                      window.ThemeManager.postMessage('dark');
                      return false;
                    } else if (href.startsWith('light-mode://')) {
                      e.preventDefault();
                      console.log('Light mode requested from approval page');
                      window.ThemeManager.postMessage('light');
                      return false;
                    } else if (href.startsWith('system-mode://')) {
                      e.preventDefault();
                      console.log('System mode requested from approval page');
                      window.ThemeManager.postMessage('system');
                      return false;
                    }
                  }
                  element = element.parentElement;
                }
              }, true);
              
              console.log("Theme handling JS initialized in approval page");
            ''');

                // Enable zooming and scrolling
                _controller.runJavaScript('''
                  // Enable pinch-to-zoom
                  document.documentElement.style.touchAction = 'auto';
                  document.body.style.overflowX = 'auto';
                  document.body.style.overflowY = 'auto';
                  document.body.style.webkitOverflowScrolling = 'touch';
                  
                  // Ensure content is properly sized for viewport
                  document.querySelector('meta[name="viewport"]').content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
                ''');
              },
              onWebResourceError: (WebResourceError error) {
                if (!_mounted) return; // Skip if not mounted
                print("Approval page web resource error: ${error.description}");
                setState(() {
                  _isLoading = false;
                });
              },
            ),
          )
          ..loadRequest(Uri.parse('https://www.google.com'));
  }

  @override
  void dispose() {
    _mounted = false; // Mark as unmounted
    super.dispose();
  }

  // Method to update the app theme
  void _updateAppTheme(String themeMode) {
    if (!_mounted) return; // Skip if not mounted

    print('Updating app theme to: $themeMode from approval page');
    // Update the app's theme using the method in MyApp
    MyApp.of(context).updateThemeMode(themeMode);

    // Show a snackbar to indicate theme change
    if (_mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Theme changed to ${_capitalize(themeMode)} mode'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Helper method for string capitalization
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return "${text[0].toUpperCase()}${text.substring(1)}";
  }

  @override
  Widget build(BuildContext context) {
    // Check current theme for UI adaptations
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          "Approvals",
          style: GoogleFonts.rubik(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        iconTheme: IconThemeData(
          color: titleColor, // Back button color
        ),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.filter_24_regular),
            onPressed: () {
              _showBottomSheetWithWebView(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Use a SingleChildScrollView to make the WebView scrollable if needed
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              // Set a minimum height to ensure scrolling works correctly
              height: MediaQuery.of(context).size.height - AppBar().preferredSize.height,
              width: MediaQuery.of(context).size.width,
              child: WebViewWidget(controller: _controller),
            ),
          ),
          if (_isLoading) _buildLoadingIndicator(),
        ],
      ),
    );
  }

  void _showBottomSheetWithWebView(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Bottom sheet handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  height: 5,
                  width: 40,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "website webview",
                        style: GoogleFonts.rubik(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      InkWell(
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                ),
                // WebView in the bottom sheet
                Expanded(
                  child: _BottomSheetWebView(url: 'https://en.wikipedia.org/wiki/Website'),
                ),
              ],
            ),
          ),
        );
      },
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
                isDarkMode ? Colors.white : Colors.black,
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

// Separate widget for the WebView in the bottom sheet
class _BottomSheetWebView extends StatefulWidget {
  final String url;

  const _BottomSheetWebView({required this.url});

  @override
  State<_BottomSheetWebView> createState() => _BottomSheetWebViewState();
}

class _BottomSheetWebViewState extends State<_BottomSheetWebView> {
  late final WebViewController _webController;
  bool _isLoading = true;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _webController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel(
            'ThemeManager',
            onMessageReceived: (JavaScriptMessage message) {
              // Handle theme change messages
              if (!_mounted) return; // Skip if not mounted anymore
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
              onPageFinished: (String url) {
                if (!_mounted) return; // Skip if not mounted anymore
                setState(() {
                  _isLoading = false;
                });

                // Inject theme handling JavaScript
                _webController.runJavaScript('''
              // Add listener for theme change buttons
              document.addEventListener('click', function(e) {
                let element = e.target;
                for (let i = 0; i < 4 && element; i++) { // Check up to 3 levels up
                  // Check if element has href attribute that matches theme modes
                  const href = element.getAttribute('href');
                  if (href) {
                    if (href.startsWith('dark-mode://')) {
                      e.preventDefault();
                      console.log('Dark mode requested from bottom sheet');
                      window.ThemeManager.postMessage('dark');
                      return false;
                    } else if (href.startsWith('light-mode://')) {
                      e.preventDefault();
                      console.log('Light mode requested from bottom sheet');
                      window.ThemeManager.postMessage('light');
                      return false;
                    } else if (href.startsWith('system-mode://')) {
                      e.preventDefault();
                      console.log('System mode requested from bottom sheet');
                      window.ThemeManager.postMessage('system');
                      return false;
                    }
                  }
                  element = element.parentElement;
                }
              }, true);
              
              console.log("Theme handling JS initialized in bottom sheet");
            ''');

                // Enable zooming and scrolling in bottom sheet webview
                _webController.runJavaScript('''
                  // Enable pinch-to-zoom and proper scrolling
                  document.documentElement.style.touchAction = 'auto';
                  document.body.style.overflowX = 'auto';
                  document.body.style.overflowY = 'auto';
                  document.body.style.webkitOverflowScrolling = 'touch';
                  
                  // Ensure content is properly sized for viewport
                  document.querySelector('meta[name="viewport"]').content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
                ''');
              },
              onPageStarted: (String url) {
                if (!_mounted) return; // Skip if not mounted anymore
                setState(() {
                  _isLoading = true;
                });
              },
              onNavigationRequest: (NavigationRequest request) {
                // Skip state changes if not mounted
                if (!_mounted) return NavigationDecision.navigate;

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
                }
                return NavigationDecision.navigate;
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

  // Method to update the app theme
  void _updateAppTheme(String themeMode) {
    if (!_mounted) return; // Skip if not mounted anymore
    print('Updating app theme to: $themeMode from bottom sheet');
    // Update the app's theme using the method in MyApp
    MyApp.of(context).updateThemeMode(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Use SingleChildScrollView for the bottom sheet WebView too
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            // Set a minimum height to ensure scrolling works correctly
            height: MediaQuery.of(context).size.height * 0.8,
            width: MediaQuery.of(context).size.width,
            child: WebViewWidget(controller: _webController),
          ),
        ),
        if (_isLoading)
          Container(
            color: isDarkMode ? const Color(0xFF121212) : Colors.white,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
      ],
    );
  }
}