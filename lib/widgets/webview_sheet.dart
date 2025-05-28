// lib/widgets/webview_sheet.dart - Complete Improved Native JS Pull-to-Refresh with Perfect Scrolling
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
  Timer? _loadingTimer;
  final String _channelName = 'SheetScrollMonitor_${DateTime.now().millisecondsSinceEpoch}';
  final String _refreshChannelName = 'SheetPullToRefreshChannel_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    // Use WebViewService.createController() to get all JavaScript bridges
    _controller = WebViewService().createController(widget.url, context);

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
            debugPrint('📍 Sheet scroll position: ${isAtTop ? "TOP" : "SCROLLED"}');
          }
        } catch (e) {
          debugPrint('❌ Error parsing scroll message: $e');
        }
      },
    );

    // Add JavaScript channel for pull-to-refresh
    _controller.addJavaScriptChannel(
      _refreshChannelName,
      onMessageReceived: (JavaScriptMessage message) {
        if (message.message == 'refresh') {
          debugPrint('🔄 Pull-to-refresh triggered from JavaScript in sheet');
          _handleJavaScriptRefresh();
        }
      },
    );

    // Set proper navigation delegate to handle page reloads
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          debugPrint('⏳ Sheet page started loading: $url');
          if (mounted) {
            setState(() {
              _isLoading = true;
            });
          }
        },
        onPageFinished: (String url) {
          debugPrint('✅ Sheet page finished loading: $url');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          
          // Enhanced page setup for sheets
          _setupSheetPage();
          
          // Re-inject services and monitoring
          Future.delayed(const Duration(milliseconds: 800), () {
            _reinjectWebViewServiceJS();
            _injectScrollAndRefreshMonitoring();
          });
        },
        onWebResourceError: (WebResourceError error) {
          debugPrint('❌ Sheet web resource error: ${error.description}');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      ),
    );

    // Start monitoring loading state
    _startLoadingMonitor();
  }

  // Handle refresh triggered from JavaScript
  Future<void> _handleJavaScriptRefresh() async {
    debugPrint('🔄 Handling JavaScript refresh request in sheet');
    
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      
      await _controller.reload();
      debugPrint('✅ JavaScript refresh completed successfully in sheet');
    } catch (e) {
      debugPrint('❌ Error during JavaScript refresh in sheet: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startLoadingMonitor() {
    // Monitor loading state and navigation
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        // Check if we can go back
        final canGoBack = await _controller.canGoBack();
        
        if (mounted && _canGoBack != canGoBack) {
          setState(() {
            _canGoBack = canGoBack;
          });
        }
        
        // Stop timer after initial setup
        if (timer.tick >= 10 && !_isLoading) {
          timer.cancel();
        }
      } catch (e) {
        debugPrint('Loading monitor error: $e');
      }
    });
  }

  void _setupSheetPage() {
    _controller.runJavaScript('''
      console.log('🔧 Setting up sheet page for optimal scrolling...');
      
      // Enhanced scrolling setup for sheet
      function setupSheetScrolling() {
        // Remove any CSS that might prevent scrolling
        document.body.style.overflow = 'auto';
        document.body.style.overflowY = 'auto';
        document.body.style.webkitOverflowScrolling = 'touch';
        document.body.style.height = 'auto';
        document.body.style.minHeight = '100vh';
        document.body.style.position = 'relative';
        
        // Ensure html allows scrolling
        document.documentElement.style.overflow = 'auto';
        document.documentElement.style.height = 'auto';
        document.documentElement.style.position = 'relative';
        
        // Remove fixed positioning that might interfere with sheet scrolling
        var elements = document.querySelectorAll('*');
        for(var i = 0; i < elements.length; i++) {
          var element = elements[i];
          var computedStyle = window.getComputedStyle(element);
          
          if(computedStyle.position === 'fixed' && element.tagName !== 'BODY' && element.tagName !== 'HTML') {
            // Only change position if it's not critical UI element
            if (!element.classList.contains('keep-fixed') && !element.id.includes('native-refresh')) {
              element.style.position = 'absolute';
              console.log('Changed fixed element to absolute:', element.tagName, element.className);
            }
          }
          
          // Remove any transform3d that might cause issues
          if (computedStyle.transform && computedStyle.transform !== 'none') {
            if (!element.id.includes('native-refresh')) {
              element.style.transform = 'none';
            }
          }
        }
        
        // Ensure smooth scrolling
        document.documentElement.style.scrollBehavior = 'smooth';
        document.body.style.scrollBehavior = 'smooth';
        
        // Remove any overflow hidden on container elements
        var containers = document.querySelectorAll('div, main, section, article');
        for(var i = 0; i < containers.length; i++) {
          var container = containers[i];
          var style = window.getComputedStyle(container);
          if (style.overflow === 'hidden' && !container.id.includes('native-refresh')) {
            container.style.overflow = 'visible';
          }
        }
        
        console.log('✅ Sheet scrolling setup completed');
      }
      
      // Run setup immediately and after a delay
      setupSheetScrolling();
      setTimeout(setupSheetScrolling, 500);
      setTimeout(setupSheetScrolling, 1000);
      
      // Re-run setup when DOM changes
      var observer = new MutationObserver(function(mutations) {
        var shouldResetup = false;
        mutations.forEach(function(mutation) {
          if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
            shouldResetup = true;
          }
        });
        
        if (shouldResetup) {
          setTimeout(setupSheetScrolling, 100);
        }
      });
      
      observer.observe(document.body, {
        childList: true,
        subtree: true
      });
    ''');
  }

  // Re-inject all WebViewService JavaScript functionality
  void _reinjectWebViewServiceJS() {
    debugPrint('💉 Re-injecting WebViewService JavaScript in sheet...');

    _controller.runJavaScript('''
      console.log("🚀 ERPForever WebView JavaScript loading in sheet...");
      
      // Enhanced click handler with full protocol support
      if (!window.sheetClickHandlerAdded) {
        document.addEventListener('click', function(e) {
          let element = e.target;
          
          for (let i = 0; i < 4 && element; i++) {
            const href = element.getAttribute('href');
            const textContent = element.textContent?.toLowerCase() || '';
            
            // Handle all URL protocols FIRST
            if (href) {
              console.log('🔍 WebViewSheet: Click detected on href:', href);
              
              // PRIORITY: Handle new-web:// - Let NavigationDelegate handle this
              if (href.startsWith('new-web://')) {
                console.log('🌐 WebViewSheet: new-web:// link clicked');
                return;
              }
              // PRIORITY: Handle new-sheet:// - Let NavigationDelegate handle this
              else if (href.startsWith('new-sheet://')) {
                console.log('📋 WebViewSheet: new-sheet:// link clicked');
                return;
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
              // Auth requests
              else if (href.startsWith('logout://')) {
                e.preventDefault();
                if (window.AuthManager) {
                  window.AuthManager.postMessage('logout');
                  console.log("🚪 WebViewSheet: Logout triggered via URL");
                } else {
                  console.error("❌ AuthManager not available");
                }
                return false;
              } 
              // Service requests
              else if (href.startsWith('get-location://')) {
                e.preventDefault();
                if (window.LocationManager) window.LocationManager.postMessage('getCurrentLocation');
                return false;
              } 
              else if (href.startsWith('get-contacts://')) {
                e.preventDefault();
                if (window.ContactsManager) window.ContactsManager.postMessage('getAllContacts');
                return false;
              } 
              else if (href.startsWith('take-screenshot://')) {
                e.preventDefault();
                if (window.ScreenshotManager) window.ScreenshotManager.postMessage('takeScreenshot');
                return false;
              } 
              else if (href.startsWith('save-image://')) {
                e.preventDefault();
                if (window.ImageSaver) window.ImageSaver.postMessage(href);
                return false;
              } 
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
              else if (href?.includes('barcode') || href?.includes('scan')) {
                e.preventDefault();
                if (window.BarcodeScanner) {
                  window.BarcodeScanner.postMessage('scan');
                  console.log("📱 Barcode scan triggered via href");
                }
                return false;
              }
              
              element = element.parentElement;
              continue;
            }
            
            // Text-based detection for services (only if no href)
            if (textContent.includes('logout') || textContent.includes('log out') || textContent.includes('sign out')) {
              e.preventDefault();
              if (window.AuthManager) {
                window.AuthManager.postMessage('logout');
                console.log("🚪 WebViewSheet: Logout triggered via text");
              } else {
                console.error("❌ AuthManager not available in WebViewSheet");
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
        
        window.sheetClickHandlerAdded = true;
      }

      // Enhanced utility object with complete feature set
      window.ERPForever = window.ERPForever || {};
      Object.assign(window.ERPForever, {
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
        
        // Service methods
        getAllContacts: function() {
          console.log('📞 Getting all contacts...');
          if (window.ContactsManager) {
            window.ContactsManager.postMessage('getAllContacts');
          } else {
            console.error('❌ ContactsManager not available');
          }
        },
        
        takeScreenshot: function() {
          console.log('📸 Taking screenshot...');
          if (window.ScreenshotManager) {
            window.ScreenshotManager.postMessage('takeScreenshot');
          } else {
            console.error('❌ ScreenshotManager not available');
          }
        },
        
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
        
        getCurrentLocation: function() {
          console.log('🌍 Getting current location...');
          if (window.LocationManager) {
            window.LocationManager.postMessage('getCurrentLocation');
          } else {
            console.error('❌ LocationManager not available');
          }
        },
        
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
        
        logout: function() {
          console.log('🚪 Logging out...');
          if (window.AuthManager) {
            window.AuthManager.postMessage('logout');
          } else {
            console.error('❌ AuthManager not available');
          }
        },
        
        version: '1.2.0'
      });

      console.log("✅ ERPForever WebView JavaScript ready in sheet!");
      console.log("🔧 All services reinjected in WebViewSheet");
    ''');
  }

  void _injectScrollAndRefreshMonitoring() {
    _controller.runJavaScript('''
      (function() {
        console.log('🔄 Initializing enhanced scroll monitoring and pull-to-refresh in sheet...');
        
        // Clean up any existing refresh indicators
        var existingIndicator = document.getElementById('native-refresh-indicator-sheet');
        if (existingIndicator) {
          existingIndicator.remove();
        }
        
        // Scroll monitoring variables
        let isAtTop = true;
        let scrollTimeout;
        const scrollChannelName = '$_channelName';
        
        // Pull-to-refresh configuration - matching WebViewPage
        const PULL_THRESHOLD = 80; // Same as WebViewPage
        const MAX_PULL_DISTANCE = 120; // Same as WebViewPage
        const refreshChannelName = '$_refreshChannelName';
        
        // Pull-to-refresh state variables
        let startY = 0;
        let currentY = 0;
        let pullDistance = 0;
        let isPulling = false;
        let isRefreshing = false;
        let canPull = false;
        let touchStartTime = 0;
        
        // Create refresh indicator element - without arrow
        const refreshIndicator = document.createElement('div');
        refreshIndicator.id = 'native-refresh-indicator-sheet';
        refreshIndicator.className = 'keep-fixed'; // Prevent position changes
        refreshIndicator.innerHTML = \`
          <div class="refresh-content">
            <div class="refresh-text">Pull to refresh</div>
          </div>
        \`;
        
        // CSS styles - without icon styles
        const style = document.createElement('style');
        style.textContent = \`
          #native-refresh-indicator-sheet {
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
          
          .refresh-text {
            font-size: 16px;
            font-weight: 500;
            opacity: 0.9;
          }
          
          #native-refresh-indicator-sheet.ready .refresh-text::after {
            content: ' - Release to refresh';
          }
          
          #native-refresh-indicator-sheet.refreshing .refresh-text {
            animation: pulse 1s ease-in-out infinite;
          }
          
          @keyframes pulse {
            0%, 100% { opacity: 0.7; }
            50% { opacity: 1; }
          }
          
          body {
            overscroll-behavior-y: contain;
          }
          
          @media (prefers-color-scheme: dark) {
            #native-refresh-indicator-sheet {
              background: linear-gradient(135deg, #434343 0%, #000000 100%);
            }
          }
        \`;
        
        document.head.appendChild(style);
        document.body.appendChild(refreshIndicator);
        
        // Scroll monitoring - matching WebViewPage threshold
        function checkScrollPosition() {
          const scrollTop = Math.max(
            window.pageYOffset || 0,
            document.documentElement.scrollTop || 0,
            document.body.scrollTop || 0
          );
          const newIsAtTop = scrollTop <= 5; // Same as WebViewPage
          
          if (newIsAtTop !== isAtTop) {
            isAtTop = newIsAtTop;
            
            if (window[scrollChannelName] && window[scrollChannelName].postMessage) {
              window[scrollChannelName].postMessage(isAtTop.toString());
            }
          }
        }
        
        // Check if user is at the top - matching WebViewPage
        function isAtPageTop() {
          const scrollTop = Math.max(
            window.pageYOffset || 0,
            document.documentElement.scrollTop || 0,
            document.body.scrollTop || 0
          );
          return scrollTop <= 5; // Same as WebViewPage
        }
        
        // Update refresh indicator - without icon manipulation
        function updateRefreshIndicator() {
          const progress = Math.min(pullDistance / PULL_THRESHOLD, 1);
          const translateY = Math.min(pullDistance * 0.6, MAX_PULL_DISTANCE * 0.6);
          
          refreshIndicator.style.transform = \`translateY(\${translateY + 120}px)\`;
          
          if (pullDistance >= PULL_THRESHOLD) {
            refreshIndicator.classList.add('ready');
            refreshIndicator.querySelector('.refresh-text').textContent = 'Release to refresh';
          } else {
            refreshIndicator.classList.remove('ready');
            refreshIndicator.querySelector('.refresh-text').textContent = 'Pull to refresh';
          }
        }
        
        // Refresh function - without icon manipulation
        function startRefreshing() {
          isRefreshing = true;
          refreshIndicator.classList.add('refreshing');
          refreshIndicator.querySelector('.refresh-text').textContent = 'Refreshing...';
          refreshIndicator.style.transform = 'translateY(80px)';
          
          console.log('🔄 Sending refresh message via channel:', refreshChannelName);
          
          if (window[refreshChannelName]) {
            console.log('✅ Channel found, sending refresh message');
            if (window[refreshChannelName].postMessage) {
              window[refreshChannelName].postMessage('refresh');
              console.log('✅ Refresh message sent successfully');
            } else {
              console.error('❌ postMessage method not found on channel');
            }
          } else {
            console.error('❌ Refresh channel not found:', refreshChannelName);
          }
          
          setTimeout(() => {
            endRefreshing();
          }, 2000);
        }
        
        // End refreshing animation - without icon reset
        function endRefreshing() {
          isRefreshing = false;
          refreshIndicator.classList.remove('refreshing', 'ready');
          refreshIndicator.style.transform = 'translateY(-120px)';
          refreshIndicator.querySelector('.refresh-text').textContent = 'Pull to refresh';
        }
        
        // Touch handlers - matching WebViewPage behavior
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
        
        // Optimized scroll listener
        function onScroll() {
          if (scrollTimeout) {
            clearTimeout(scrollTimeout);
          }
          scrollTimeout = setTimeout(checkScrollPosition, 30);
        }
        
        // Remove existing listeners to prevent duplicates
        window.removeEventListener('scroll', onScroll);
        document.removeEventListener('touchstart', handleTouchStart);
        document.removeEventListener('touchmove', handleTouchMove);
        document.removeEventListener('touchend', handleTouchEnd);
        
        // Add enhanced event listeners
        window.addEventListener('scroll', onScroll, { passive: true });
        document.addEventListener('touchstart', handleTouchStart, { passive: false });
        document.addEventListener('touchmove', handleTouchMove, { passive: false });
        document.addEventListener('touchend', handleTouchEnd, { passive: false });
        
        // Handle touch cancel - matching WebViewPage
        document.addEventListener('touchcancel', function(e) {
          if (isPulling) {
            refreshIndicator.style.transform = 'translateY(-120px)';
            refreshIndicator.classList.remove('ready');
            isPulling = false;
            pullDistance = 0;
            canPull = false;
          }
        }, { passive: true });
        
        // Initial check
        setTimeout(checkScrollPosition, 200);
        
        console.log('✅ Enhanced scroll monitoring and pull-to-refresh initialized in sheet');
        console.log('🔧 Refresh channel name:', refreshChannelName);
        
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
        
        // Expose refresh function globally
        window.ERPForever = window.ERPForever || {};
        window.ERPForever.triggerRefresh = function() {
          if (!isRefreshing) {
            startRefreshing();
          }
        };
        
      })();
    ''');
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
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<VerticalDragGestureRecognizer>(
                VerticalDragGestureRecognizer.new,
              ),
              Factory<PanGestureRecognizer>(
                PanGestureRecognizer.new,
              ),
            },
          ),
          if (_isLoading) 
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
        color: (isDarkMode ? Colors.black : Colors.white).withOpacity(0.95),
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
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Loading...',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
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