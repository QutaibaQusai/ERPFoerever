// lib/pages/webview_page.dart - Updated to use WebViewService
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/widgets/loading_widget.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;
  
  const WebViewPage({
    Key? key, 
    required this.url,
    required this.title,
  }) : super(key: key);

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isAtTop = true; 
  bool _isRefreshing = false; 
  final String _channelName = 'RegularWebViewScrollMonitor_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {

    _controller = WebViewService().createController(widget.url, context);
    
    _controller.addJavaScriptChannel(
      _channelName,
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final isAtTop = message.message == 'true';
          
          if (mounted && _isAtTop != isAtTop) {
            setState(() {
              _isAtTop = isAtTop;
            });
            debugPrint('Regular WebView scroll: ${isAtTop ? "TOP" : "SCROLLED"}');
          }
        } catch (e) {
          debugPrint('Error parsing scroll message: $e');
        }
      },
    );
    
    _setupLoadingListener();
  }

  void _setupLoadingListener() {

    _checkLoadingState();
  }
  
  void _checkLoadingState() async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      _injectScrollMonitoring();
    }
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
          const newIsAtTop = scrollTop <= 5; // Same threshold as main_icons
          
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
        console.log('✅ Regular WebView scroll monitoring initialized');
        
        // Log available services for debugging
        console.log('🔧 Available services in regular WebView:', {
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
    
    debugPrint('🔄 Refreshing Regular WebView');
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _controller.reload();
      
      await Future.delayed(const Duration(milliseconds: 800));
      
      debugPrint('✅ Regular WebView refreshed successfully');
    } catch (e) {
      debugPrint('❌ Error refreshing Regular WebView: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.rubik(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      body: _buildRefreshableWebViewContent(isDarkMode),
    );
  }

  Widget _buildRefreshableWebViewContent(bool isDarkMode) {
    return RefreshIndicator(
      backgroundColor: isDarkMode?Colors.black:Colors.white,
      color: isDarkMode?Colors.white:Colors.black,
      onRefresh: _refreshWebView,
      child: SingleChildScrollView(
        physics: _isAtTop 
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 
                 kToolbarHeight - 
                 MediaQuery.of(context).padding.top,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading || _isRefreshing) 
                LoadingWidget(
                  message: _isRefreshing ? "Refreshing..." : "Loading...",
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up WebViewService
    WebViewService().dispose();
    super.dispose();
  }
}