// lib/widgets/webview_sheet.dart - Updated to use WebViewService
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:ERPForever/services/webview_service.dart';

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
  bool _isAtTop = true;
  bool _isRefreshing = false;
  Timer? _loadingTimer;
  final String _channelName = 'SheetScrollMonitor_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    // Use WebViewService.createController() to get all JavaScript bridges
    _controller = WebViewService().createController(widget.url, context);

    // Add JavaScript channel for scroll monitoring (additional to WebViewService channels)
    _controller.addJavaScriptChannel(
      _channelName,
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final isAtTop = message.message == 'true';
          
          if (mounted && _isAtTop != isAtTop) {
            setState(() {
              _isAtTop = isAtTop;
            });
          }
        } catch (e) {
          debugPrint('Error parsing scroll message: $e');
        }
      },
    );

    // Start monitoring loading state without overriding NavigationDelegate
    _startLoadingMonitor();
  }

  void _startLoadingMonitor() {
    // Monitor loading state periodically
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        // Check if we can go back
        final canGoBack = await _controller.canGoBack();
        
        if (mounted) {
          setState(() {
            _canGoBack = canGoBack;
          });
        }
        
        // After a few checks, assume page is loaded
        if (timer.tick >= 5) {
          timer.cancel();
          
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            
            _enableScrolling();
            
            // Wait a bit more then inject scroll monitoring
            await Future.delayed(const Duration(milliseconds: 500));
            _injectScrollMonitoring();
          }
        }
      } catch (e) {
        // Controller might not be ready yet, continue monitoring
        debugPrint('Loading monitor error: $e');
      }
    });
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
      
      console.log('✅ Sheet WebView scrolling enabled');
    ''');
  }

  void _injectScrollMonitoring() {
    _controller.runJavaScript('''
      (function() {
        let isAtTop = true;
        let scrollTimeout;
        const channelName = '$_channelName';
        
        function checkScrollPosition() {
          const scrollTop = Math.max(
            window.pageYOffset || 0,
            document.documentElement.scrollTop || 0,
            document.body.scrollTop || 0
          );
          const newIsAtTop = scrollTop <= 5;
          
          if (newIsAtTop !== isAtTop) {
            isAtTop = newIsAtTop;
            
            if (window[channelName] && window[channelName].postMessage) {
              window[channelName].postMessage(isAtTop.toString());
            }
          }
        }
        
        function onScroll() {
          if (scrollTimeout) {
            clearTimeout(scrollTimeout);
          }
          scrollTimeout = setTimeout(checkScrollPosition, 50);
        }
        
        window.removeEventListener('scroll', onScroll);
        window.addEventListener('scroll', onScroll, { passive: true });
        
        setTimeout(checkScrollPosition, 100);
        console.log('✅ Sheet scroll monitoring initialized');
        
        // Log available services for debugging
        console.log('🔧 Available services in sheet WebView:', {
          BarcodeScanner: !!window.BarcodeScanner,
          LocationManager: !!window.LocationManager,
          ContactsManager: !!window.ContactsManager,
          ScreenshotManager: !!window.ScreenshotManager,
          ImageSaver: !!window.ImageSaver,
          PdfSaver: !!window.PdfSaver,
          AlertManager: !!window.AlertManager,
          ThemeManager: !!window.ThemeManager,
          AuthManager: !!window.AuthManager,
          ERPForever: !!window.ERPForever
        });
      })();
    ''');
  }

  Future<void> _refreshWebView() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _controller.reload();
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (e) {
      debugPrint('Error refreshing WebView: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      final canGoBack = await _controller.canGoBack();
      if (mounted) {
        setState(() {
          _canGoBack = canGoBack;
        });
      }
      return false;
    }
    return true;
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      final canGoBack = await _controller.canGoBack();
      if (mounted) {
        setState(() {
          _canGoBack = canGoBack;
        });
      }
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
              child: _buildWebViewContent(isDarkMode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebViewContent(bool isDarkMode) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
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
          if (_isLoading || _isRefreshing) 
            _buildLoadingIndicator(isDarkMode),
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
          
          // Header with title, back button, and close button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 8, 16),
            child: Row(
              children: [
                // Back button
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: _canGoBack 
                      ? (isDarkMode ? Colors.white : Colors.black)
                      : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                    size: 25,
                  ),
                  onPressed: _canGoBack ? _goBack : null,
                  tooltip: 'Go Back',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Title
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Refresh button
                if (_isAtTop && !_isLoading)
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: isDarkMode ? Colors.white : Colors.black,
                      size: 22,
                    ),
                    onPressed: _isRefreshing ? null : _refreshWebView,
                    tooltip: 'Refresh',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
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
              _isRefreshing ? 'Refreshing...' : 'Loading...',
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

  @override
  void dispose() {
    _loadingTimer?.cancel();
    WebViewService().dispose();
    super.dispose();
  }
}