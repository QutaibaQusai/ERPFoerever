// lib/pages/webview_page.dart - Working navigation + All services
import 'package:ERPForever/services/pull_to_refresh_service.dart';
import 'package:ERPForever/services/refresh_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final pageId =
        'WebViewPage_${widget.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
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
          _injectNativePullToRefresh();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final refreshManager = Provider.of<RefreshStateManager>(
          context,
          listen: false,
        );
        refreshManager.registerController(_controller);
        debugPrint(
          '✅ WebViewPage controller registered with RefreshStateManager',
        );
      } catch (e) {
        debugPrint('❌ Error registering WebViewPage controller: $e');
      }
    });
  }

  void _injectNativePullToRefresh() {
    try {
      debugPrint('🔄 Using PullToRefreshService for WebViewPage...');

      // Use the reusable service
      PullToRefreshService().injectNativePullToRefresh(
        controller: _controller,
        context: RefreshContext.webViewPage,
        refreshChannelName: _refreshChannelName,
        flutterContext: context, // Pass Flutter context for theme detection
      );

      debugPrint('✅ PullToRefreshService injected for WebViewPage');
    } catch (e) {
      debugPrint('❌ Error injecting refresh for WebViewPage: $e');
    }
  }

  // Simplified refresh handler
  Future<void> _handleJavaScriptRefresh() async {
    final refreshManager = Provider.of<RefreshStateManager>(
      context,
      listen: false,
    );

    if (!refreshManager.shouldAllowRefresh()) {
      debugPrint('🚫 Refresh blocked - sheet is open');
      return;
    }

    debugPrint('🔄 Processing refresh request...');

    try {
      // Just reload the page - keep it simple
      await _controller.reload();

      debugPrint('✅ Page reloaded successfully');
    } catch (e) {
      debugPrint('❌ Error reloading page: $e');
    }
  }

  void _reinjectWebViewServiceJS() {
    debugPrint('💉 Re-injecting WebViewService JavaScript in WebViewPage...');

    _controller.runJavaScript('''
    console.log("🚀 ERPForever WebView JavaScript loading in WebViewPage...");
    
    // Enhanced click handler with full protocol support - SAME AS WebViewPage
    document.addEventListener('click', function(e) {
      let element = e.target;
      
      for (let i = 0; i < 4 && element; i++) {
        const href = element.getAttribute('href');
        const textContent = element.textContent?.toLowerCase() || '';
        
        // Handle all URL protocols FIRST - if we find href, process it and skip text checks
        if (href) {
          console.log('🔍 WebViewPage: Click detected on href:', href);
          
          // PRIORITY: Handle external URLs with ?external=1 parameter
          if (href.includes('?external=1')) {
            console.log('🌐 WebViewPage: External URL detected, letting NavigationDelegate handle it');
            return; // Let NavigationDelegate handle this
          }
          
          // PRIORITY: Handle new-web:// - Let NavigationDelegate handle this
          if (href.startsWith('new-web://')) {
            console.log('🌐 WebViewPage: new-web:// link clicked - letting NavigationDelegate handle it');
            return; // Exit the entire click handler
          }
          // PRIORITY: Handle new-sheet:// - Let NavigationDelegate handle this
          else if (href.startsWith('new-sheet://')) {
            console.log('📋 WebViewPage: new-sheet:// link clicked - letting NavigationDelegate handle it');
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
          // Auth requests - ONLY handle via JavaScript - MAKE MORE SPECIFIC
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
          // FIXED: Barcode detection with proper continuous checking
          else if (href?.includes('barcode') || href?.includes('scan')) {
            e.preventDefault();
            
            // Enhanced continuous detection for WebViewPage
            const isContinuous = href.includes('continuous') || 
                                href.includes('Continuous') || 
                                href.includes('scanContinuous') ||
                                href.toLowerCase().includes('continuous') ||
                                textContent.includes('continuous') ||
                                element.classList.contains('continuous-scan') ||
                                element.getAttribute('data-scan-type') === 'continuous' ||
                                element.getAttribute('data-continuous') === 'true';
            
            if (window.BarcodeScanner) {
              const message = isContinuous ? 'scanContinuous' : 'scan';
              window.BarcodeScanner.postMessage(message);
              console.log("📱 WebViewPage: Barcode scan triggered via href - Type:", message, "URL:", href, "Continuous detected:", isContinuous);
            } else {
              console.error("❌ BarcodeScanner not available in WebViewPage");
            }
            return false;
          }
          
          // If we found an href but it's not a special protocol, continue to next element
          // DON'T do text-based detection on elements that have href attributes
          element = element.parentElement;
          continue; // Skip text-based detection for this element
        }
        
        // ONLY do text-based detection if NO href was found
        // Text-based detection for services (only if no href) - MAKE MORE SPECIFIC
        
        // REMOVED AUTOMATIC LOGOUT DETECTION - Only trigger logout on specific elements
        // Check if element has specific logout classes or data attributes
        if ((element.classList && (element.classList.contains('logout-btn') || element.classList.contains('sign-out-btn'))) ||
            element.getAttribute('data-action') === 'logout' ||
            element.getAttribute('data-logout') === 'true') {
          e.preventDefault();
          if (window.AuthManager) {
            window.AuthManager.postMessage('logout');
            console.log("🚪 WebViewPage: Logout triggered via specific logout element");
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
        
        // FIXED: Enhanced barcode text detection with continuous support
        if (textContent.includes('scan barcode') || textContent.includes('qr code') || textContent.includes('scan qr') || textContent.includes('barcode scan')) {
          e.preventDefault();
          
          // Enhanced continuous detection for text-based triggers
          const isContinuous = textContent.includes('continuous') || 
                              textContent.includes('scan continuously') ||
                              textContent.includes('continuous scan') ||
                              textContent.includes('continuously') ||
                              element.classList.contains('continuous-scan') ||
                              element.getAttribute('data-scan-type') === 'continuous' ||
                              element.getAttribute('data-continuous') === 'true' ||
                              element.closest('[data-scan-type="continuous"]') !== null ||
                              element.closest('.continuous-scan') !== null ||
                              element.closest('[data-continuous="true"]') !== null;
          
          if (window.BarcodeScanner) {
            const message = isContinuous ? 'scanContinuous' : 'scan';
            window.BarcodeScanner.postMessage(message);
            console.log("📱 WebViewPage: Barcode scan triggered via text - Type:", message, "Text:", textContent, "Continuous detected:", isContinuous);
          } else {
            console.error("❌ BarcodeScanner not available in WebViewPage");
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
      
      // FIXED: Barcode System with enhanced continuous support for WebViewPage
      scanBarcode: function() {
        console.log('📸 WebViewPage: Scanning barcode (single)...');
        if (window.BarcodeScanner) {
          window.BarcodeScanner.postMessage('scan');
        } else {
          console.error('❌ BarcodeScanner not available');
        }
      },
      
      scanBarcodeContinuous: function() {
        console.log('📸 WebViewPage: Scanning barcode (continuous)...');
        if (window.BarcodeScanner) {
          window.BarcodeScanner.postMessage('scanContinuous');
        } else {
          console.error('❌ BarcodeScanner not available');
        }
      },
      
      // Auto-detect scan type from URL or element
      scanBarcodeAuto: function(element) {
        if (element && typeof element === 'object') {
          const isContinuous = element.classList?.contains('continuous-scan') ||
                              element.getAttribute('data-scan-type') === 'continuous' ||
                              element.getAttribute('data-continuous') === 'true' ||
                              element.textContent?.toLowerCase().includes('continuous');
          
          console.log('📱 WebViewPage: Auto-detecting barcode scan type - continuous:', isContinuous);
          
          if (isContinuous) {
            this.scanBarcodeContinuous();
          } else {
            this.scanBarcode();
          }
        } else {
          console.log('📱 WebViewPage: No element provided, defaulting to single scan');
          this.scanBarcode(); // Default to single scan
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
      
      // NEW: External URL function
      openExternal: function(url) {
        console.log('🌐 Opening external URL:', url);
        if (url && typeof url === 'string') {
          // Add external parameter and navigate
          const separator = url.includes('?') ? '&' : '?';
          window.location.href = url + separator + 'external=1';
        } else {
          console.error('❌ Invalid URL for external navigation');
        }
      },
      
      version: '1.1.0'
    };

    // WebViewPage refresh blocking support - NEW ADDITION
    let webViewPageRefreshBlocked = false;
    
    // Function for Flutter to update refresh state in WebViewPage
    window.setRefreshBlocked = function(blocked) {
      webViewPageRefreshBlocked = blocked;
      console.log('🔄 WebViewPage refresh state updated:', blocked ? 'BLOCKED' : 'ALLOWED');
      
      // Update any existing pull-to-refresh indicators
      if (blocked) {
        // Disable any active refresh operations
        const refreshIndicators = document.querySelectorAll('[id*="refresh-indicator"]');
        refreshIndicators.forEach(indicator => {
          if (indicator.style) {
            indicator.style.display = 'none';
          }
        });
      } else {
        // Re-enable refresh indicators
        const refreshIndicators = document.querySelectorAll('[id*="refresh-indicator"]');
        refreshIndicators.forEach(indicator => {
          if (indicator.style) {
            indicator.style.display = '';
          }
        });
      }
    };
    
    // Enhanced touch event handling for refresh blocking
    let touchStartY = 0;
    let isAtPageTop = false;
    
    // Function to check if we're at the top of the page
    function checkIfAtTop() {
      const scrollTop = Math.max(
        window.pageYOffset || 0,
        document.documentElement.scrollTop || 0,
        document.body.scrollTop || 0
      );
      isAtPageTop = scrollTop <= 5;
      return isAtPageTop;
    }
    
    // Override touch events when refresh is blocked
    document.addEventListener('touchstart', function(e) {
      if (webViewPageRefreshBlocked) {
        checkIfAtTop();
        if (isAtPageTop && e.touches && e.touches.length > 0) {
          touchStartY = e.touches[0].clientY;
          console.log('🔄 WebViewPage: Touch start at top, monitoring for refresh gesture');
        }
      }
    }, { passive: true });
    
    document.addEventListener('touchmove', function(e) {
      if (webViewPageRefreshBlocked && isAtPageTop && e.touches && e.touches.length > 0) {
        const currentY = e.touches[0].clientY;
        const deltaY = currentY - touchStartY;
        
        // If pulling down from the top, prevent the default behavior
        if (deltaY > 10) { // Small threshold to avoid blocking normal scrolling
          if (e.cancelable) {
            e.preventDefault();
            console.log('🚫 WebViewPage: Blocked pull-to-refresh gesture (deltaY:', deltaY, ')');
          }
        }
      }
    }, { passive: false });
    
    document.addEventListener('touchend', function(e) {
      if (webViewPageRefreshBlocked) {
        touchStartY = 0;
        isAtPageTop = false;
      }
    }, { passive: true });
    
    // Scroll event listener to update top position
    window.addEventListener('scroll', function() {
      if (webViewPageRefreshBlocked) {
        checkIfAtTop();
      }
    }, { passive: true });

    console.log("✅ ERPForever WebView JavaScript ready in WebViewPage!");
    console.log("🔧 All services reinjected in WebViewPage with FIXED barcode detection and refresh blocking");
    
    // Log debug info for barcode detection
    console.log("📱 WebViewPage Barcode Detection Enhanced:");
    console.log("  - href detection: barcode, scan + continuous variations");
    console.log("  - text detection: scan barcode, qr code + continuous variations");
    console.log("  - attribute detection: data-scan-type, data-continuous, .continuous-scan");
    console.log("  - API: window.ERPForever.scanBarcode(), scanBarcodeContinuous(), scanBarcodeAuto(element)");
    console.log("🔄 WebViewPage Refresh Blocking: Initialized and ready");
  ''');
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    debugPrint('🔍 Handling navigation in WebViewPage: ${request.url}');

    // PRIORITY: Handle toast requests FIRST
    if (request.url.startsWith('toast://')) {
      _handleToastRequest(request.url);
      return NavigationDecision.prevent;
    }

    // PRIORITY: Handle external URLs with ?external=1 parameter
    if (request.url.contains('?external=1')) {
      _handleExternalNavigation(request.url);
      return NavigationDecision.prevent;
    }

    // Handle new-web:// requests - PREVENT and open new WebView layer
    if (request.url.startsWith('new-web://')) {
      _handleNewWebNavigation(request.url);
      return NavigationDecision.prevent;
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

  void _handleExternalNavigation(String url) {
    debugPrint('🌐 External navigation detected in WebViewPage: $url');

    try {
      // Remove the ?external=1 parameter to get the clean URL
      String cleanUrl = url.replaceAll('?external=1', '');

      // Also handle case where there are other parameters after external=1
      cleanUrl = cleanUrl.replaceAll('&external=1', '');
      cleanUrl = cleanUrl.replaceAll('external=1&', '');
      cleanUrl = cleanUrl.replaceAll('external=1', '');

      // Clean up any leftover ? or & at the end
      if (cleanUrl.endsWith('?') || cleanUrl.endsWith('&')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      debugPrint('🔗 Clean URL for external browser: $cleanUrl');

      // Validate URL
      if (cleanUrl.isEmpty ||
          (!cleanUrl.startsWith('http://') &&
              !cleanUrl.startsWith('https://'))) {
        debugPrint('❌ Invalid URL for external navigation: $cleanUrl');
        _showUrlError('Invalid URL format');
        return;
      }

      // Launch in default browser
      _launchInDefaultBrowser(cleanUrl);
    } catch (e) {
      debugPrint('❌ Error handling external navigation: $e');
      _showUrlError('Failed to open external URL');
    }
  }

  // Add this new method to WebViewPage
  Future<void> _launchInDefaultBrowser(String url) async {
    try {
      debugPrint('🌐 Opening URL in default browser: $url');

      final Uri uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        final bool launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          debugPrint('✅ Successfully opened URL in default browser');

          // Use web scripts instead of native SnackBar
          if (mounted) {
            _controller.runJavaScript('''
            if (window.ToastManager) {
              window.ToastManager.postMessage('toast://' + encodeURIComponent('Opening in browser...'));
            } else {
              window.location.href = 'toast://' + encodeURIComponent('Opening in browser...');
            }
          ''');
          }
        } else {
          debugPrint('❌ Failed to launch URL in browser');
          _showUrlError('Could not open URL in browser');
        }
      } else {
        debugPrint('❌ Cannot launch URL: $url');
        _showUrlError('Cannot open this type of URL');
      }
    } catch (e) {
      debugPrint('❌ Error launching URL in browser: $e');
      _showUrlError('Failed to open browser: ${e.toString()}');
    }
  }

  void _showUrlError(String message) {
    if (mounted) {
      _controller.runJavaScript('''
      const errorMessage = '$message';
      if (window.AlertManager) {
        window.AlertManager.postMessage('alert://' + encodeURIComponent(errorMessage));
      } else {
        window.location.href = 'alert://' + encodeURIComponent(errorMessage);
      }
    ''');
    }
  }

  void _handleToastRequest(String url) {
    debugPrint('🍞 Toast requested from WebView PAGE: $url');

    try {
      // Extract message from the URL
      String message = url.replaceFirst('toast://', '');

      // Decode URL encoding if present
      message = Uri.decodeComponent(message);

      debugPrint('🍞 DECODED TOAST MESSAGE: "$message"');

      // Show the toast message
      if (mounted && message.isNotEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        debugPrint('✅ Toast shown successfully: $message');
      } else {
        debugPrint('❌ Empty toast message');
      }
    } catch (e) {
      debugPrint('❌ Error handling toast request: $e');
    }
  }

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
      body: _buildWebViewContent(isDarkMode),
    );
  }

  Widget _buildWebViewContent(bool isDarkMode) {
    return Consumer<RefreshStateManager>(
      builder: (context, refreshManager, child) {
        // Cache the refresh state to avoid calling methods during build
        final isRefreshAllowed = refreshManager.isRefreshEnabled;

        return RefreshIndicator(
          // Only allow refresh when sheet is not open
          onRefresh:
              isRefreshAllowed
                  ? _handleJavaScriptRefresh
                  : () async {
                    debugPrint(
                      '🚫 WebViewPage refresh blocked - sheet is open',
                    );
                    return;
                  },
          child: SizedBox(
            height:
                MediaQuery.of(context).size.height -
                kToolbarHeight -
                MediaQuery.of(context).padding.top,
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading) LoadingWidget(message: "Loading..."),
                // Show refresh indicator only when allowed
                if (_isAtTop && !_isLoading && isRefreshAllowed)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(height: 2, color: Colors.transparent),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    debugPrint(
      '🧹 WebViewPage disposing - popping controller from stack: $_pageId',
    );

    // ADD THIS: Unregister from RefreshStateManager
    try {
      final refreshManager = Provider.of<RefreshStateManager>(
        context,
        listen: false,
      );
      refreshManager.unregisterController(_controller);
      debugPrint(
        '✅ WebViewPage controller unregistered from RefreshStateManager',
      );
    } catch (e) {
      debugPrint('❌ Error unregistering WebViewPage controller: $e');
    }

    // Pop this specific controller from the stack
    WebViewService().popController(_pageId);

    super.dispose();
  }
}
