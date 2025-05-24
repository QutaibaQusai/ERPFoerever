// Updated lib/widgets/webview_sheet.dart - Complete with back navigation
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
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
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
          onPageFinished: (String url) async {
            if (mounted) {
              // Update navigation state
              final canGoBack = await _controller.canGoBack();
              final canGoForward = await _controller.canGoForward();
              
              setState(() {
                _isLoading = false;
                _canGoBack = canGoBack;
                _canGoForward = canGoForward;
              });
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

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      _updateNavigationState();
      return false; // Don't close the sheet
    }
    return true; // Close the sheet
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      _updateNavigationState();
    }
  }





  Future<void> _updateNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    
    if (mounted) {
      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Container(
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
            _buildSheetHeader(context, isDarkMode),
            const Divider(height: 1),
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
                    WebViewWidget(
                      controller: _controller,
                      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
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
          
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: Row(
              children: [
                // Back button
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: _canGoBack 
                      ? (isDarkMode ? Colors.white : Colors.black)
                      : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                    size: 20,
                  ),
                  onPressed: _canGoBack ? _goBack : null,
                  tooltip: 'Go Back',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                
  
              
                
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

                // Close button
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
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