// lib/pages/webview_page.dart - Working navigation + All services
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/widgets/loading_widget.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({Key? key, required this.url, required this.title})
    : super(key: key);

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isAtTop = true;
  final String _channelName =
      'RegularWebViewScrollMonitor_${DateTime.now().millisecondsSinceEpoch}';
      final String _refreshChannelName =
    'PullToRefreshChannel_${DateTime.now().millisecondsSinceEpoch}';
      late String _pageId; // ADD THIS LINE

    

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

void _initializeWebView() {
  // Create controller using WebViewService to get all JavaScript bridges
  _controller = WebViewService().createController(widget.url, context);

  // CRITICAL: Register this controller with WebViewService
final pageId = 'WebViewPage_${widget.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
WebViewService().pushController(_controller, context, pageId);

// Store the page ID for cleanup
_pageId = pageId;

debugPrint('📋 WebViewPage controller pushed to stack with ID: $pageId');
  // Add JavaScript channel for scroll monitoring
  _controller.addJavaScriptChannel(
    _channelName,
    onMessageReceived: (JavaScriptMessage message) {
      try {
        final isAtTop = message.message == 'true';

        if (mounted && _isAtTop != isAtTop) {
          setState(() {
            _isAtTop = isAtTop;
          });
          debugPrint(
            'Regular WebView scroll: ${isAtTop ? "TOP" : "SCROLLED"}',
          );
        }
      } catch (e) {
        debugPrint('Error parsing scroll message: $e');
      }
    },
  );

  // Add JavaScript channel for pull-to-refresh
  _controller.addJavaScriptChannel(
    _refreshChannelName,
    onMessageReceived: (JavaScriptMessage message) {
      if (message.message == 'refresh') {
        debugPrint('🔄 Pull-to-refresh triggered from JavaScript');
        _handleJavaScriptRefresh();
      }
    },
  );

  // IMPORTANT: Override the navigation delegate to handle new-web:// properly
  _controller.setNavigationDelegate(
    NavigationDelegate(
      onPageStarted: (String url) {
        debugPrint('⏳ Page started loading: $url');
        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }
      },
      onPageFinished: (String url) {


        debugPrint('✅ Page finished loading: $url');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }



        // CRITICAL: Re-inject all WebViewService JavaScript after page loads
        _reinjectWebViewServiceJS();

        // Then inject scroll monitoring
        Future.delayed(const Duration(milliseconds: 500), () {
          _injectScrollMonitoring();
        });
        _injectPullToRefresh();
      },
      onNavigationRequest: (NavigationRequest request) {
        debugPrint('🔍 WebViewPage Navigation request: ${request.url}');
        

        
        return _handleNavigationRequest(request);
      },
      onWebResourceError: (WebResourceError error) {
        debugPrint('❌ Web resource error: ${error.description}');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    ),
  );
}
  // Inject native JavaScript pull-to-refresh functionality
void _injectPullToRefresh() {
  _controller.runJavaScript('''
    (function() {
      console.log('🔄 Initializing native pull-to-refresh...');
      
      // Configuration
      const PULL_THRESHOLD = 80; // Distance needed to trigger refresh
      const MAX_PULL_DISTANCE = 120; // Maximum pull distance
      const channelName = '$_refreshChannelName';
      
      // State variables
      let startY = 0;
      let currentY = 0;
      let pullDistance = 0;
      let isPulling = false;
      let isRefreshing = false;
      let canPull = false;
      
      // Create refresh indicator element
      const refreshIndicator = document.createElement('div');
      refreshIndicator.id = 'native-refresh-indicator';
      refreshIndicator.innerHTML = `
        <div class="refresh-content">
          <div class="refresh-icon">↓</div>
          <div class="refresh-text">Pull to refresh</div>
        </div>
      `;
      
      // CSS styles for the refresh indicator
      const style = document.createElement('style');
      style.textContent = \`
        #native-refresh-indicator {
          position: fixed;
          top: -120px;
          left: 0;
          right: 0;
          height: 80px;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          z-index: 9999;
          transition: transform 0.3s cubic-bezier(0.2, 0.8, 0.2, 1);
          box-shadow: 0 2px 10px rgba(0,0,0,0.1);
          display: flex;
          align-items: center;
          justify-content: center;
        }
        
        .refresh-content {
          display: flex;
          flex-direction: column;
          align-items: center;
          color: white;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        
        .refresh-icon {
          font-size: 24px;
          margin-bottom: 4px;
          transition: transform 0.3s ease;
        }
        
        .refresh-text {
          font-size: 14px;
          font-weight: 500;
          opacity: 0.9;
        }
        
        #native-refresh-indicator.ready .refresh-icon {
          transform: rotate(180deg);
        }
        
        #native-refresh-indicator.ready .refresh-text::after {
          content: ' - Release to refresh';
        }
        
        #native-refresh-indicator.refreshing .refresh-icon {
          animation: spin 1s linear infinite;
        }
        
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
        
        body {
          overscroll-behavior-y: contain;
        }
        
        @media (prefers-color-scheme: dark) {
          #native-refresh-indicator {
            background: linear-gradient(135deg, #434343 0%, #000000 100%);
          }
        }
      \`;
      
      document.head.appendChild(style);
      document.body.appendChild(refreshIndicator);
      
      // Check if user is at the top of the page
      function isAtPageTop() {
        const scrollTop = Math.max(
          window.pageYOffset || 0,
          document.documentElement.scrollTop || 0,
          document.body.scrollTop || 0
        );
        return scrollTop <= 5;
      }
      
      // Update refresh indicator based on pull distance
      function updateRefreshIndicator() {
        const progress = Math.min(pullDistance / PULL_THRESHOLD, 1);
        const translateY = Math.min(pullDistance * 0.6, MAX_PULL_DISTANCE * 0.6);
        
        refreshIndicator.style.transform = \`translateY(\${translateY}px)\`;
        
        if (pullDistance >= PULL_THRESHOLD) {
          refreshIndicator.classList.add('ready');
          refreshIndicator.querySelector('.refresh-text').textContent = 'Release to refresh';
        } else {
          refreshIndicator.classList.remove('ready');
          refreshIndicator.querySelector('.refresh-text').textContent = 'Pull to refresh';
        }
        
        const rotation = progress * 180;
        refreshIndicator.querySelector('.refresh-icon').style.transform = \`rotate(\${rotation}deg)\`;
      }
      
      // Start refreshing animation
      function startRefreshing() {
        isRefreshing = true;
        refreshIndicator.classList.add('refreshing');
        refreshIndicator.querySelector('.refresh-text').textContent = 'Refreshing...';
        refreshIndicator.querySelector('.refresh-icon').textContent = '⟳';
        refreshIndicator.style.transform = 'translateY(80px)';
        
        if (window[channelName] && window[channelName].postMessage) {
          window[channelName].postMessage('refresh');
        }
        
        setTimeout(() => {
          endRefreshing();
        }, 2000);
      }
      
      // End refreshing animation
      function endRefreshing() {
        isRefreshing = false;
        refreshIndicator.classList.remove('refreshing', 'ready');
        refreshIndicator.style.transform = 'translateY(-120px)';
        refreshIndicator.querySelector('.refresh-text').textContent = 'Pull to refresh';
        refreshIndicator.querySelector('.refresh-icon').textContent = '↓';
        refreshIndicator.querySelector('.refresh-icon').style.transform = 'rotate(0deg)';
      }
      
      // Touch event handlers
      function handleTouchStart(e) {
        if (isRefreshing) return;
        canPull = isAtPageTop();
        if (!canPull) return;
        startY = e.touches[0].clientY;
        isPulling = false;
        pullDistance = 0;
      }
      
      function handleTouchMove(e) {
        if (isRefreshing || !canPull) return;
        currentY = e.touches[0].clientY;
        const deltaY = currentY - startY;
        
        if (deltaY > 0 && isAtPageTop()) {
          e.preventDefault();
          isPulling = true;
          pullDistance = Math.min(deltaY * 0.5, MAX_PULL_DISTANCE);
          updateRefreshIndicator();
        }
      }
      
      function handleTouchEnd(e) {
        if (isRefreshing || !isPulling) return;
        
        if (pullDistance >= PULL_THRESHOLD) {
          startRefreshing();
        } else {
          refreshIndicator.style.transform = 'translateY(-120px)';
          refreshIndicator.classList.remove('ready');
        }
        
        isPulling = false;
        pullDistance = 0;
        canPull = false;
      }
      
      // Add event listeners
      document.addEventListener('touchstart', handleTouchStart, { passive: false });
      document.addEventListener('touchmove', handleTouchMove, { passive: false });
      document.addEventListener('touchend', handleTouchEnd, { passive: false });
      
      console.log('✅ Native pull-to-refresh initialized successfully');
      
      // Expose refresh function globally
      window.ERPForever.triggerRefresh = function() {
        if (!isRefreshing) {
          startRefreshing();
        }
      };
      
    })();
  ''');
}
// Handle refresh triggered from JavaScript
Future<void> _handleJavaScriptRefresh() async {
  debugPrint('🔄 Handling JavaScript refresh request');
  
  try {
    await _controller.reload();
    debugPrint('✅ JavaScript refresh completed successfully');
  } catch (e) {
    debugPrint('❌ Error during JavaScript refresh: $e');
  }
}
  // CRITICAL: Re-inject all WebViewService JavaScript functionality
  void _reinjectWebViewServiceJS() {
    debugPrint('💉 Re-injecting WebViewService JavaScript...');

    _controller.runJavaScript('''
      console.log("🚀 ERPForever WebView JavaScript loading...");
      
      // Enhanced click handler with full protocol support - FIXED VERSION
      document.addEventListener('click', function(e) {
        let element = e.target;
        
        for (let i = 0; i < 4 && element; i++) {
          const href = element.getAttribute('href');
          const textContent = element.textContent?.toLowerCase() || '';
          
          // Handle all URL protocols FIRST - if we find href, process it and skip text checks
          if (href) {
            console.log('🔍 WebViewPage: Click detected on href:', href);
            
            // PRIORITY: Handle new-web:// - Let NavigationDelegate handle this
            if (href.startsWith('new-web://')) {
              console.log('🌐 WebViewPage: new-web:// link clicked - letting NavigationDelegate handle it');
              // DON'T prevent - let it go to NavigationDelegate
              // IMPORTANT: Exit immediately to prevent logout detection
              return; // Exit the entire click handler
            }
            // PRIORITY: Handle new-sheet:// - Let NavigationDelegate handle this
            else if (href.startsWith('new-sheet://')) {
              console.log('📋 WebViewPage: new-sheet:// link clicked - letting NavigationDelegate handle it');
              // DON'T prevent - let it go to NavigationDelegate
              // IMPORTANT: Exit immediately
              return; // Exit the entire click handler
            }
            // Alert requests
            else if (href.startsWith('alert://')) {
              e.preventDefault();
              if (window.AlertManager) {
                window.AlertManager.postMessage(href);
                console.log("🚨 Alert triggered via URL:", href);
              } else {
                console.error("❌ AlertManager not available");
              }
              return false;
            } else if (href.startsWith('confirm://')) {
              e.preventDefault();
              if (window.AlertManager) {
                window.AlertManager.postMessage(href);
                console.log("❓ Confirm triggered via URL:", href);
              } else {
                console.error("❌ AlertManager not available");
              }
              return false;
            } else if (href.startsWith('prompt://')) {
              e.preventDefault();
              if (window.AlertManager) {
                window.AlertManager.postMessage(href);
                console.log("✏️ Prompt triggered via URL:", href);
              } else {
                console.error("❌ AlertManager not available");
              }
              return false;
            }
            // Theme requests
            else if (href.startsWith('dark-mode://')) {
              e.preventDefault();
              if (window.ThemeManager) window.ThemeManager.postMessage('dark');
              return false;
            } else if (href.startsWith('light-mode://')) {
              e.preventDefault();
              if (window.ThemeManager) window.ThemeManager.postMessage('light');
              return false;
            } else if (href.startsWith('system-mode://')) {
              e.preventDefault();
              if (window.ThemeManager) window.ThemeManager.postMessage('system');
              return false;
            } 
            // Auth requests - ONLY handle via JavaScript
            else if (href.startsWith('logout://')) {
              e.preventDefault();
              if (window.AuthManager) {
                window.AuthManager.postMessage('logout');
                console.log("🚪 WebViewPage: Logout triggered via URL (handled by JS)");
              } else {
                console.error("❌ AuthManager not available");
              }
              return false;
            } 
            // Location requests
            else if (href.startsWith('get-location://')) {
              e.preventDefault();
              if (window.LocationManager) window.LocationManager.postMessage('getCurrentLocation');
              return false;
            } 
            // Contacts requests
            else if (href.startsWith('get-contacts://')) {
              e.preventDefault();
              if (window.ContactsManager) window.ContactsManager.postMessage('getAllContacts');
              return false;
            } 
            // Screenshot requests
            else if (href.startsWith('take-screenshot://')) {
              e.preventDefault();
              if (window.ScreenshotManager) window.ScreenshotManager.postMessage('takeScreenshot');
              return false;
            } 
            // Image save requests
            else if (href.startsWith('save-image://')) {
              e.preventDefault();
              if (window.ImageSaver) window.ImageSaver.postMessage(href);
              return false;
            } 
            // PDF save requests
            else if (href.startsWith('save-pdf://')) {
              e.preventDefault();
              if (window.PdfSaver) {
                window.PdfSaver.postMessage(href);
                console.log("📄 PDF save triggered via URL:", href);
              } else {
                console.error("❌ PdfSaver not available");
              }
              return false;
            }
            // Barcode detection
            else if (href?.includes('barcode') || href?.includes('scan')) {
              e.preventDefault();
              if (window.BarcodeScanner) {
                window.BarcodeScanner.postMessage('scan');
                console.log("📱 Barcode scan triggered via href");
              }
              return false;
            }
            
            // If we found an href but it's not a special protocol, continue to next element
            // DON'T do text-based detection on elements that have href attributes
            element = element.parentElement;
            continue; // Skip text-based detection for this element
          }
          
          // ONLY do text-based detection if NO href was found
          // Text-based detection for services (only if no href)
          if (textContent.includes('logout') || textContent.includes('log out') || textContent.includes('sign out')) {
            e.preventDefault();
            if (window.AuthManager) {
              window.AuthManager.postMessage('logout');
              console.log("🚪 WebViewPage: Logout triggered via text (handled by JS)");
            } else {
              console.error("❌ AuthManager not available in WebViewPage");
            }
            return false;
          }
          
          if (textContent.includes('get location') || textContent.includes('current location') || textContent.includes('my location')) {
            e.preventDefault();
            if (window.LocationManager) {
              window.LocationManager.postMessage('getCurrentLocation');
              console.log("🌍 Location request triggered via text");
            }
            return false;
          }
          
          if (textContent.includes('get contacts') || textContent.includes('load contacts') || textContent.includes('contact list')) {
            e.preventDefault();
            if (window.ContactsManager) {
              window.ContactsManager.postMessage('getAllContacts');
              console.log("📞 Contacts request triggered via text");
            }
            return false;
          }
          
          if (textContent.includes('screenshot') || textContent.includes('capture screen') || textContent.includes('take screenshot')) {
            e.preventDefault();
            if (window.ScreenshotManager) {
              window.ScreenshotManager.postMessage('takeScreenshot');
              console.log("📸 Screenshot triggered via text");
            }
            return false;
          }
          
          if (textContent.includes('scan barcode') || textContent.includes('qr code')) {
            e.preventDefault();
            if (window.BarcodeScanner) {
              window.BarcodeScanner.postMessage('scan');
              console.log("📱 Barcode scan triggered via text");
            }
            return false;
          }
          
          element = element.parentElement;
        }
      }, true);

      // Enhanced utility object with complete feature set
      window.ERPForever = {
        // Alert System
        showAlert: function(message) {
          console.log('🚨 Showing alert:', message);
          if (window.AlertManager) {
            if (typeof message === 'string' && message.trim()) {
              window.AlertManager.postMessage('alert://' + encodeURIComponent(message));
            } else {
              console.error('❌ Invalid alert message');
            }
          } else {
            console.error('❌ AlertManager not available');
          }
        },
        
        showConfirm: function(message) {
          console.log('❓ Showing confirm:', message);
          if (window.AlertManager) {
            if (typeof message === 'string' && message.trim()) {
              window.AlertManager.postMessage('confirm://' + encodeURIComponent(message));
            } else {
              console.error('❌ Invalid confirm message');
            }
          } else {
            console.error('❌ AlertManager not available');
          }
        },
        
        showPrompt: function(message, defaultValue = '') {
          console.log('✏️ Showing prompt:', message, 'default:', defaultValue);
          if (window.AlertManager) {
            if (typeof message === 'string' && message.trim()) {
              let promptUrl = 'prompt://message=' + encodeURIComponent(message);
              if (defaultValue) {
                promptUrl += '&default=' + encodeURIComponent(defaultValue);
              }
              window.AlertManager.postMessage(promptUrl);
            } else {
              console.error('❌ Invalid prompt message');
            }
          } else {
            console.error('❌ AlertManager not available');
          }
        },
        
        // Contact System
        getAllContacts: function() {
          console.log('📞 Getting all contacts...');
          if (window.ContactsManager) {
            window.ContactsManager.postMessage('getAllContacts');
          } else {
            console.error('❌ ContactsManager not available');
          }
        },
        
        // Screenshot System
        takeScreenshot: function() {
          console.log('📸 Taking screenshot...');
          if (window.ScreenshotManager) {
            window.ScreenshotManager.postMessage('takeScreenshot');
          } else {
            console.error('❌ ScreenshotManager not available');
          }
        },
        
        // Image Save System
        saveImage: function(imageUrl) {
          console.log('🖼️ Saving image:', imageUrl);
          if (window.ImageSaver) {
            if (!imageUrl.startsWith('save-image://')) {
              imageUrl = 'save-image://' + imageUrl;
            }
            window.ImageSaver.postMessage(imageUrl);
          } else {
            console.error('❌ ImageSaver not available');
          }
        },
        
        // PDF Save System
        savePdf: function(pdfUrl) {
          console.log('📄 Saving PDF:', pdfUrl);
          if (window.PdfSaver) {
            if (!pdfUrl || typeof pdfUrl !== 'string') {
              console.error('❌ Invalid PDF URL provided');
              return false;
            }
            
            if (!pdfUrl.startsWith('save-pdf://')) {
              pdfUrl = 'save-pdf://' + pdfUrl;
            }
            
            window.PdfSaver.postMessage(pdfUrl);
            return true;
          } else {
            console.error('❌ PdfSaver not available');
            return false;
          }
        },
        
        // Location System
        getCurrentLocation: function() {
          console.log('🌍 Getting current location...');
          if (window.LocationManager) {
            window.LocationManager.postMessage('getCurrentLocation');
          } else {
            console.error('❌ LocationManager not available');
          }
        },
        
        // Barcode System
        scanBarcode: function() {
          console.log('📸 Scanning barcode...');
          if (window.BarcodeScanner) {
            window.BarcodeScanner.postMessage('scan');
          } else {
            console.error('❌ BarcodeScanner not available');
          }
        },
        
        scanBarcodeContinuous: function() {
          console.log('📸 Scanning barcode (continuous)...');
          if (window.BarcodeScanner) {
            window.BarcodeScanner.postMessage('scanContinuous');
          } else {
            console.error('❌ BarcodeScanner not available');
          }
        },
        
        // Theme System
        setTheme: function(theme) {
          console.log('🎨 Setting theme to:', theme);
          if (window.ThemeManager) {
            if (['dark', 'light', 'system'].includes(theme)) {
              window.ThemeManager.postMessage(theme);
            } else {
              console.error('❌ Invalid theme. Use: dark, light, or system');
            }
          } else {
            console.error('❌ ThemeManager not available');
          }
        },
        
        // Auth System
        logout: function() {
          console.log('🚪 Logging out...');
          if (window.AuthManager) {
            window.AuthManager.postMessage('logout');
          } else {
            console.error('❌ AuthManager not available');
          }
        },
        
        version: '1.1.0'
      };

      console.log("✅ ERPForever WebView JavaScript ready!");
      console.log("🔧 All services reinjected in WebViewPage");
    ''');
  }

  // Handle navigation requests properly
  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    debugPrint('🔍 Handling navigation in WebViewPage: ${request.url}');

    // Handle new-web:// requests - PREVENT and open new WebView layer
    if (request.url.startsWith('new-web://')) {
      _handleNewWebNavigation(request.url);
      return NavigationDecision.prevent; // CRITICAL: Prevent the navigation
    }

    // Handle new-sheet:// requests
    if (request.url.startsWith('new-sheet://')) {
      _handleSheetNavigation(request.url);
      return NavigationDecision.prevent;
    }

    // For loggedin:// requests, also prevent to avoid issues
    if (request.url.startsWith('loggedin://')) {
      debugPrint(
        '🔐 Login success detected in WebViewPage - but user is already logged in',
      );
      return NavigationDecision.prevent;
    }

    // For all service-related URLs, prevent navigation (they'll be handled by JavaScript)
    if (request.url.startsWith('dark-mode://') ||
        request.url.startsWith('light-mode://') ||
        request.url.startsWith('system-mode://') ||
        request.url.startsWith('logout://') ||
        request.url.startsWith('get-location://') ||
        request.url.startsWith('get-contacts://') ||
        request.url.startsWith('take-screenshot://') ||
        request.url.startsWith('save-image://') ||
        request.url.startsWith('save-pdf://') ||
        request.url.startsWith('alert://') ||
        request.url.startsWith('confirm://') ||
        request.url.startsWith('prompt://') ||
        request.url.contains('barcode') ||
        request.url.contains('scan')) {
      // These will be handled by the re-injected JavaScript
      return NavigationDecision.prevent;
    }

    // Allow normal navigation for other URLs
    return NavigationDecision.navigate;
  }

  // Handle new-web:// navigation by opening another WebViewPage
  void _handleNewWebNavigation(String url) {
    debugPrint('🌐 Opening new WebView layer from: $url');

    String targetUrl = 'https://mobile.erpforever.com/';

    if (url.contains('?')) {
      try {
        Uri uri = Uri.parse(url.replaceFirst('new-web://', 'https://'));
        if (uri.queryParameters.containsKey('url')) {
          targetUrl = uri.queryParameters['url']!;
        }
      } catch (e) {
        debugPrint("Error parsing URL parameters: $e");
      }
    }

    // Navigate to another WebViewPage (creating a layer)
   // Navigate to another WebViewPage (creating a layer)
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => WebViewPage(url: targetUrl, title: 'Web View'),
  ),
).then((_) {
  // When returning from the new WebViewPage, re-register this controller
  if (mounted && context.mounted) {
    Future.delayed(const Duration(milliseconds: 100), () {
      WebViewService().pushController(_controller, context, _pageId);
    });
  }
});
  }

  // Handle new-sheet:// navigation - Open CURRENT page in sheet
  void _handleSheetNavigation(String url) {
    debugPrint('📋 WebViewPage: Opening current page in sheet: $url');

    // Use the CURRENT page URL instead of parsing the new-sheet:// URL
    String targetUrl = widget.url; // Use the current WebViewPage URL

    // Only parse parameters if you want to override the current URL
    if (url.contains('?url=')) {
      try {
        Uri uri = Uri.parse(url.replaceFirst('new-sheet://', 'https://'));
        if (uri.queryParameters.containsKey('url')) {
          targetUrl = uri.queryParameters['url']!;
        }
      } catch (e) {
        debugPrint('❌ Error parsing URL parameters: $e');
      }
    }

    debugPrint('📋 WebViewPage: Opening sheet with CURRENT URL: $targetUrl');

    // Use WebViewService to open the CURRENT page in sheet format
    WebViewService().navigate(
      context,
      url: targetUrl,
      linkType: 'sheet_webview',
      title: widget.title, // Use current page title
    );
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

 
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
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
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
body: _buildWebViewContent(isDarkMode),    );
  }

 Widget _buildWebViewContent(bool isDarkMode) {
  return SizedBox(
    height: MediaQuery.of(context).size.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top,
    child: Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          LoadingWidget(
            message: "Loading...",
          ),
      ],
    ),
  );
}

@override
void dispose() {
  debugPrint('🧹 WebViewPage disposing - popping controller from stack: $_pageId');
  
  // Pop this specific controller from the stack
  WebViewService().popController(_pageId);
  
  super.dispose();
}
}
