// Fixed lib/widgets/webview_sheet.dart - Enable WebView Scrolling
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

class WebViewSheet extends StatefulWidget {
  final String url;
  final String title;
  final double heightFactor;

  const WebViewSheet({
    super.key,
    required this.url,
    required this.title,
    this.heightFactor = 0.9,
  });

  @override
  State<WebViewSheet> createState() => _WebViewSheetState();
}

class _WebViewSheetState extends State<WebViewSheet> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    // Create controller with proper scrolling settings
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // Enable user interaction and scrolling
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              // Inject CSS to ensure scrolling works
              _enableScrolling();
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _enableScrolling() {
    // Inject JavaScript to ensure the page is scrollable
    _controller.runJavaScript('''
      // Remove any CSS that might prevent scrolling
      document.body.style.overflow = 'auto';
      document.body.style.overflowY = 'auto';
      document.body.style.webkitOverflowScrolling = 'touch';
      document.body.style.height = 'auto';
      document.body.style.minHeight = '100vh';
      
      // Remove fixed positioning that might interfere
      var elements = document.querySelectorAll('*');
      for(var i = 0; i < elements.length; i++) {
        var computedStyle = window.getComputedStyle(elements[i]);
        if(computedStyle.position === 'fixed' && elements[i].tagName !== 'BODY') {
          elements[i].style.position = 'relative';
        }
      }
      
      // Ensure html and body allow scrolling
      document.documentElement.style.overflow = 'auto';
      document.documentElement.style.height = 'auto';
      
      console.log('✅ WebView scrolling enabled');
    ''');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * widget.heightFactor,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Fixed header
          _buildSheetHeader(context, isDarkMode),
          const Divider(height: 1),
          
          // WebView in a container that allows scrolling
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  // WebView with gesture detection enabled
                  WebViewWidget(
                    controller: _controller,
                    gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
                      // Enable vertical drag gestures for scrolling
                      Factory<VerticalDragGestureRecognizer>(
                        VerticalDragGestureRecognizer.new,
                      ),
                    },
                  ),
                  if (_isLoading) _buildLoadingIndicator(isDarkMode),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetHeader(BuildContext context, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            height: 5,
            width: 40,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          
          // Header with title and close button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: (isDarkMode ? Colors.black : Colors.white).withOpacity(0.9),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
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
              'Loading...',
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

