import 'dart:async';
import 'package:ERPForever/pages/webview_page.dart';
import 'package:ERPForever/services/refresh_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final String _channelName =
      'SheetScrollMonitor_${DateTime.now().millisecondsSinceEpoch}';
  final String _refreshChannelName =
      'SheetPullToRefreshChannel_${DateTime.now().millisecondsSinceEpoch}';
  late String _pageId;
  RefreshStateManager? _refreshManager;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Store reference to RefreshStateManager safely
    _refreshManager = Provider.of<RefreshStateManager>(context, listen: false);

    // Delay the state change to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshManager?.setSheetOpen(true);
      debugPrint('📋 WebViewSheet opened - background refresh DISABLED');
    });
  }

  void _initializeWebView() {
    // Use WebViewService.createController() to get all JavaScript bridges
    _controller = WebViewService().createController(widget.url, context);

    // CRITICAL: Register this controller with WebViewService - SAME AS WebViewPage
    final pageId =
        'WebViewSheet_${widget.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    WebViewService().pushController(_controller, context, pageId);

    // Store the page ID for cleanup - SAME AS WebViewPage
    _pageId = pageId;

    debugPrint('📋 WebViewSheet controller pushed to stack with ID: $pageId');

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
              '📍 Sheet scroll position: ${isAtTop ? "TOP" : "SCROLLED"}',
            );
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

          // CRITICAL: Re-inject all WebViewService JavaScript after page loads - SAME AS WebViewPage
          _reinjectWebViewServiceJS();

          // Enhanced page setup for sheets
          _setupSheetPage();

          // Re-inject services and monitoring
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              _injectScrollAndRefreshMonitoring();
            }
          });
        },
        onNavigationRequest: (NavigationRequest request) {
          debugPrint('🔍 Sheet Navigation request: ${request.url}');

          // SAME AS WebViewPage - Handle navigation requests
          return _handleNavigationRequest(request);
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

  // ADD THIS METHOD - Same as WebViewPage
  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    debugPrint('🔍 Handling navigation in WebViewPage: ${request.url}');

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
        '🔐 Login success detected in WebViewSheet - but user is already logged in',
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
    debugPrint('🌐 External navigation detected in WebViewSheet: $url');

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

  // Add this new method to WebViewSheet
  Future<void> _launchInDefaultBrowser(String url) async {
    try {
      debugPrint('🌐 Opening URL in default browser: $url');

      final Uri uri = Uri.parse(url);

      // Check if the URL can be launched
      if (await canLaunchUrl(uri)) {
        // Launch in external browser (not in-app)
        final bool launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Force external browser
        );

        if (launched) {
          debugPrint('✅ Successfully opened URL in default browser');

          // Show success feedback
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening in browser...'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
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

  void _handleNewWebNavigation(String url) {
    debugPrint('🌐 Opening new WebView from sheet: $url');

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

    // Navigate to another WebViewPage - SAME AS WebViewPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewPage(url: targetUrl, title: 'Web View'),
      ),
    ).then((_) {
      // When returning from the new WebViewPage, re-register this controller - SAME AS WebViewPage
      if (mounted && context.mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          WebViewService().pushController(_controller, context, _pageId);
        });
      }
    });
  }

  void _handleSheetNavigation(String url) {
    debugPrint('📋 Opening new sheet from current sheet: $url');

    String targetUrl = widget.url; // Use current URL as default

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

    // Open another sheet
    WebViewService().navigate(
      context,
      url: targetUrl,
      linkType: 'sheet_webview',
      title: widget.title,
    );
  }

  void _showUrlError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleJavaScriptRefresh() async {
    debugPrint('🔄 Processing sheet refresh request...');

    try {
      // Just reload the page - keep it simple (SAME AS WEBVIEWPAGE)
      await _controller.reload();

      debugPrint('✅ Sheet page reloaded successfully');
    } catch (e) {
      debugPrint('❌ Error reloading sheet page: $e');
    }
  }

  void _startLoadingMonitor() {
    // Monitor loading state and navigation
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 200), (
      timer,
    ) async {
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

  void _reinjectWebViewServiceJS() {
    debugPrint('💉 Re-injecting WebViewService JavaScript in WebViewSheet...');

    _controller.runJavaScript('''
    console.log("🚀 ERPForever WebView JavaScript loading in WebViewSheet...");
    
    // Enhanced click handler with full protocol support - SAME AS WebViewPage
    document.addEventListener('click', function(e) {
      let element = e.target;
      
      for (let i = 0; i < 4 && element; i++) {
        const href = element.getAttribute('href');
        const textContent = element.textContent?.toLowerCase() || '';
        
        // Handle all URL protocols FIRST - if we find href, process it and skip text checks
        if (href) {
          console.log('🔍 WebViewSheet: Click detected on href:', href);
          
          // PRIORITY: Handle external URLs with ?external=1 parameter
          if (href.includes('?external=1')) {
            console.log('🌐 WebViewSheet: External URL detected, letting NavigationDelegate handle it');
            return; // Let NavigationDelegate handle this
          }
          
          // PRIORITY: Handle new-web:// - Let NavigationDelegate handle this
          if (href.startsWith('new-web://')) {
            console.log('🌐 WebViewSheet: new-web:// link clicked - letting NavigationDelegate handle it');
            return; // Exit the entire click handler
          }
          // PRIORITY: Handle new-sheet:// - Let NavigationDelegate handle this
          else if (href.startsWith('new-sheet://')) {
            console.log('📋 WebViewSheet: new-sheet:// link clicked - letting NavigationDelegate handle it');
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
              console.log("🚪 WebViewSheet: Logout triggered via URL (handled by JS)");
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
            
            // Enhanced continuous detection for WebViewSheet
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
              console.log("📱 WebViewSheet: Barcode scan triggered via href - Type:", message, "URL:", href, "Continuous detected:", isContinuous);
            } else {
              console.error("❌ BarcodeScanner not available in WebViewSheet");
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
            console.log("🚪 WebViewSheet: Logout triggered via specific logout element");
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
        
        // Enhanced barcode text detection with continuous support for WebViewSheet
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
            console.log("📱 WebViewSheet: Barcode scan triggered via text - Type:", message, "Text:", textContent, "Continuous detected:", isContinuous);
          } else {
            console.error("❌ BarcodeScanner not available in WebViewSheet");
          }
          return false;
        }
        
        element = element.parentElement;
      }
    }, true);

    // Enhanced utility object with complete feature set - SAME AS WebViewPage
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
      
      // Barcode System with enhanced continuous support for WebViewSheet
      scanBarcode: function() {
        console.log('📸 WebViewSheet: Scanning barcode (single)...');
        if (window.BarcodeScanner) {
          window.BarcodeScanner.postMessage('scan');
        } else {
          console.error('❌ BarcodeScanner not available');
        }
      },
      
      scanBarcodeContinuous: function() {
        console.log('📸 WebViewSheet: Scanning barcode (continuous)...');
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
          
          console.log('📱 WebViewSheet: Auto-detecting barcode scan type - continuous:', isContinuous);
          
          if (isContinuous) {
            this.scanBarcodeContinuous();
          } else {
            this.scanBarcode();
          }
        } else {
          console.log('📱 WebViewSheet: No element provided, defaulting to single scan');
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

    console.log("✅ ERPForever WebView JavaScript ready in WebViewSheet!");
    console.log("🔧 All services reinjected in WebViewSheet with FIXED barcode detection");
    
    // Log debug info for barcode detection
    console.log("📱 WebViewSheet Barcode Detection Enhanced:");
    console.log("  - href detection: barcode, scan + continuous variations");
    console.log("  - text detection: scan barcode, qr code + continuous variations");
    console.log("  - attribute detection: data-scan-type, data-continuous, .continuous-scan");
    console.log("  - API: window.ERPForever.scanBarcode(), scanBarcodeContinuous(), scanBarcodeAuto(element)");
  ''');
  }

  void _injectScrollAndRefreshMonitoring() {
    _controller.runJavaScript('''
    (function () {
      console.log('🔄 Starting STRICT pull-to-refresh (must complete pull) for WebViewSheet...');
      
      // STRICT configuration - must pull all the way
      const PULL_THRESHOLD = 350;  // Must pull THIS far to activate
      const MIN_PULL_SPEED = 150;   // Minimum pull distance to even start
      const scrollChannelName = '$_channelName';
      const refreshChannelName = '$_refreshChannelName';
      
      // Remove any existing refresh elements
      const existing = document.getElementById('strict-refresh-sheet');
      if (existing) existing.remove();
      
      // State variables
      let startY = 0;
      let currentPull = 0;
      let maxPull = 0;  // Track maximum pull distance
      let isPulling = false;
      let isRefreshing = false;
      let canPull = false;
      let hasReachedThreshold = false;  // Must reach threshold to refresh
      let scrollTimeout;
      
      // Create simple animation-only refresh indicator
      const refreshDiv = document.createElement('div');
      refreshDiv.id = 'strict-refresh-sheet';
      
      // Simple circular animation only - NO TEXT
      refreshDiv.innerHTML = \`
        <div class="refresh-circle">
          <svg class="refresh-svg" width="24" height="24" viewBox="0 0 24 24">
            <circle class="refresh-progress" cx="12" cy="12" r="10" fill="none" stroke="#0078d7" stroke-width="2" 
                    stroke-linecap="round" stroke-dasharray="63" stroke-dashoffset="63" 
                    transform="rotate(-90 12 12)"/>
          </svg>
        </div>
      \`;
      
      // FIXED: Position relative to WebView content area in sheet
      refreshDiv.style.cssText = \`
        position: absolute;
        top: 80px;
        left: 50%;
        transform: translateX(-50%) translateY(-100px);
        width: 40px;
        height: 40px;
        background: rgba(255,255,255,0.95);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 9999;
        border-radius: 50%;
        box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        opacity: 0;
        transition: all 0.2s ease;
        pointer-events: none;
      \`;
      
      // Simple animation styles
      const circleStyles = document.createElement('style');
      circleStyles.innerHTML = \`
        .refresh-circle {
          width: 24px;
          height: 24px;
        }
        
        .refresh-svg {
          width: 100%;
          height: 100%;
        }
        
        .refresh-progress {
          transition: stroke-dashoffset 0.1s ease-out;
        }
        
        /* Ready state - green */
        .refresh-ready .refresh-progress {
          stroke: #28a745 !important;
        }
        
        /* Refreshing state - spinning */
        .refresh-spinning .refresh-svg {
          animation: simpleRefreshSpin 1s linear infinite;
        }
        
        .refresh-spinning .refresh-progress {
          stroke: #0078d7 !important;
          stroke-dasharray: 16;
          stroke-dashoffset: 0;
          animation: simpleRefreshProgress 1.2s ease-in-out infinite;
        }
        
        @keyframes simpleRefreshSpin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
        
        @keyframes simpleRefreshProgress {
          0% { stroke-dasharray: 16; stroke-dashoffset: 16; }
          50% { stroke-dasharray: 16; stroke-dashoffset: 0; }
          100% { stroke-dasharray: 16; stroke-dashoffset: -16; }
        }
        
        @media (prefers-color-scheme: dark) {
          #strict-refresh-sheet {
            background: rgba(40,40,40,0.95) !important;
          }
        }
      \`;
      
      document.head.appendChild(circleStyles);
      document.body.appendChild(refreshDiv);
      
      // PREVENT BLACK AREA - Fix body overflow
      document.body.style.cssText += \`
        overscroll-behavior-y: contain;
        overflow-anchor: none;
        -webkit-overflow-scrolling: touch;
      \`;
      
      // Check if at top of page
      function isAtTop() {
        const scrollTop = Math.max(
          window.pageYOffset || 0,
          document.documentElement.scrollTop || 0,
          document.body.scrollTop || 0
        );
        return scrollTop <= 3;
      }
      
      // Update simple animation indicator - FIXED for sheet positioning
      function updateRefresh(distance) {
        const progress = Math.min(distance / PULL_THRESHOLD, 1);
        
        // Show indicator only when pulling
        refreshDiv.style.opacity = progress > 0.1 ? '1' : '0';
        
        // FIXED: Move indicator down as user pulls, starting from sheet header area
        const translateY = Math.min(distance * 0.3, 60) - 100; // Starts at -100px, moves down
        refreshDiv.style.transform = \`translateX(-50%) translateY(\${translateY}px)\`;
        
        // Update circular progress (0-100%)
        const circleProgress = progress * 100;
        const strokeDashoffset = 63 - (circleProgress * 0.63); // 63 is circumference
        const progressCircle = refreshDiv.querySelector('.refresh-progress');
        progressCircle.style.strokeDashoffset = strokeDashoffset;
        
        // Update color based on progress - ANIMATION ONLY
        refreshDiv.classList.remove('refresh-ready');
        if (progress >= 1) {
          hasReachedThreshold = true;
          refreshDiv.classList.add('refresh-ready');
        } else {
          hasReachedThreshold = false;
        }
        
        console.log(\`🔄 WebViewSheet animation: \${Math.round(progress * 100)}%\`);
      }
      
      // Hide simple indicator - FIXED for sheet positioning
      function hideRefresh() {
        refreshDiv.style.opacity = '0';
        refreshDiv.style.transform = 'translateX(-50%) translateY(-100px)'; // Return to hidden position
        refreshDiv.classList.remove('refresh-ready', 'refresh-spinning');
        refreshDiv.querySelector('.refresh-progress').style.strokeDashoffset = '63';
        hasReachedThreshold = false;
      }
      
      // Start simple refreshing animation - FIXED for sheet positioning
      function doRefresh() {
        if (isRefreshing || !hasReachedThreshold) {
          console.log(\`❌ WebViewSheet refresh denied\`);
          hideRefresh();
          return;
        }
        
        console.log('✅ WEBVIEWSHEET REFRESH TRIGGERED!');
        isRefreshing = true;
        
        // Show simple spinning animation in visible area
        refreshDiv.classList.remove('refresh-ready');
        refreshDiv.classList.add('refresh-spinning');
        refreshDiv.style.opacity = '1';
        refreshDiv.style.transform = 'translateX(-50%) translateY(20px)'; // Position in visible area
        
        // Send refresh signal
        if (window[refreshChannelName]) {
          window[refreshChannelName].postMessage('refresh');
          console.log('📤 WebViewSheet refresh message sent');
        }
        
        // Auto-hide after 1.5 seconds
        setTimeout(() => {
          hideRefresh();
          isRefreshing = false;
        }, 1500);
      }
      
      // STRICT Touch handlers
      document.addEventListener('touchstart', function(e) {
        if (isRefreshing) return;
        
        if (isAtTop()) {
          canPull = true;
          startY = e.touches[0].clientY;
          currentPull = 0;
          maxPull = 0;
          isPulling = false;
          hasReachedThreshold = false;
          console.log('👆 WEBVIEWSHEET: Touch start at top - ready to pull');
        } else {
          canPull = false;
        }
      }, { passive: false });
      
      // STRICT Touch move - only show indicator after minimum pull
      document.addEventListener('touchmove', function(e) {
        if (!canPull || isRefreshing) return;
        
        const currentY = e.touches[0].clientY;
        const deltaY = currentY - startY;
        
        if (deltaY > 0 && isAtTop()) {
          currentPull = deltaY;
          maxPull = Math.max(maxPull, deltaY);  // Track maximum pull reached
          
          // Only start showing indicator after minimum pull distance
          if (deltaY >= MIN_PULL_SPEED) {
            e.preventDefault(); // Prevent default scroll
            isPulling = true;
            updateRefresh(deltaY);
          }
        } else if (isPulling) {
          // If user scrolls up or away from top, reset
          isPulling = false;
          hideRefresh();
        }
      }, { passive: false });
      
      // STRICT Touch end - ONLY refresh if threshold was reached
      document.addEventListener('touchend', function(e) {
        if (!isPulling || isRefreshing) {
          // Reset states even if not pulling
          isPulling = false;
          canPull = false;
          hasReachedThreshold = false;
          return;
        }
        
        console.log(\`🖱️ WEBVIEWSHEET STRICT RELEASE:
          - Current pull: \${Math.round(currentPull)}px
          - Max pull reached: \${Math.round(maxPull)}px  
          - Threshold: \${PULL_THRESHOLD}px
          - Threshold reached: \${hasReachedThreshold}
          - Will refresh: \${hasReachedThreshold}\`);
        
        if (hasReachedThreshold && maxPull >= PULL_THRESHOLD) {
          console.log('✅ WEBVIEWSHEET STRICT SUCCESS: User pulled to threshold - refreshing!');
          doRefresh();
        } else {
          console.log(\`❌ WEBVIEWSHEET STRICT FAIL: Not enough pull (max: \${Math.round(maxPull)}px, needed: \${PULL_THRESHOLD}px)\`);
          hideRefresh();
        }
        
        // Reset all states
        isPulling = false;
        canPull = false;
        currentPull = 0;
        maxPull = 0;
        startY = 0;
        hasReachedThreshold = false;
      }, { passive: false });
      
      // Touch cancel - always reset
      document.addEventListener('touchcancel', function(e) {
        console.log('❌ WEBVIEWSHEET STRICT: Touch cancelled - resetting');
        hideRefresh();
        isPulling = false;
        canPull = false;
        hasReachedThreshold = false;
        currentPull = 0;
        maxPull = 0;
      }, { passive: true });
      
      // Scroll monitoring for Flutter
      function checkScroll() {
        if (window[scrollChannelName] && window[scrollChannelName].postMessage) {
          window[scrollChannelName].postMessage(isAtTop().toString());
        }
      }
      
      // Optimized scroll listener
      window.removeEventListener('scroll', checkScroll);
      window.addEventListener('scroll', function() {
        clearTimeout(scrollTimeout);
        scrollTimeout = setTimeout(checkScroll, 50);
      }, { passive: true });
      
      // Initial scroll check
      setTimeout(checkScroll, 100);
      
      console.log('✅ WEBVIEWSHEET STRICT pull-to-refresh ready!');
      console.log(\`📋 WEBVIEWSHEET STRICT Rules:
        - Must be at top of page
        - Must pull at least \${MIN_PULL_SPEED}px to start
        - Must pull \${PULL_THRESHOLD}px to activate refresh
        - Must RELEASE while in green state to refresh
        - Any incomplete pull will bounce back\`);
      
      // Manual trigger function
      window.ERPForever = window.ERPForever || {};
      window.ERPForever.triggerRefresh = function() {
        if (!isRefreshing) {
          console.log('🧪 Testing WebViewSheet refresh...');
          hasReachedThreshold = true;
          doRefresh();
        }
      };
      
      // Status function for debugging
      window.getRefreshStatusSheet = function() {
        return {
          isPulling: isPulling,
          currentPull: currentPull,
          maxPull: maxPull,
          hasReachedThreshold: hasReachedThreshold,
          isRefreshing: isRefreshing,
          canPull: canPull
        };
      };
      
      console.log('✅ WebViewSheet STRICT pull-to-refresh initialized successfully');
    })();
  ''');
  }

  Future<bool> _onWillPop() async {
    try {
      if (await _controller.canGoBack()) {
        await _controller.goBack();
        final canGoBack = await _controller.canGoBack();
        if (mounted) {
          setState(() {
            _canGoBack = canGoBack;
          });
          // Re-register controller after navigation - SAME AS WebViewPage
          WebViewService().pushController(_controller, context, _pageId);
        }
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error in _onWillPop: $e');
    }

    // Sheet is closing, clear controller reference - SAME AS WebViewPage
    _clearControllerReference();
    return true;
  }

  // ADD THIS METHOD - Same as WebViewPage
  void _clearControllerReference() {
    debugPrint('🧹 WebViewSheet clearing controller reference: $_pageId');

    // Pop this specific controller from the stack - SAME AS WebViewPage
    WebViewService().popController(_pageId);
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
            Expanded(child: _buildWebViewContent(isDarkMode)),
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
              Factory<PanGestureRecognizer>(PanGestureRecognizer.new),
            },
          ),
          if (_isLoading) _buildLoadingIndicator(isDarkMode),
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
            padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
            child: Row(
              children: [
                if (_canGoBack)
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: isDarkMode ? Colors.white : Colors.black,
                      size: 24,
                    ),
                    onPressed: _goBack,
                    tooltip: 'Back',
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
                  onPressed: () {
                    _clearControllerReference();
                    // FIXED: Use stored reference instead of Provider.of
                    if (_refreshManager != null) {
                      _refreshManager!.setSheetOpen(false);
                      debugPrint(
                        '📋 WebViewSheet closing via close button - background refresh ENABLED',
                      );
                    }
                    Navigator.pop(context);
                  },
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
    debugPrint(
      '🧹 WebViewSheet disposing - popping controller from stack: $_pageId',
    );

    // Cancel any timers
    _loadingTimer?.cancel();

    // Pop this specific controller from the stack
    WebViewService().popController(_pageId);

    // FIXED: Re-enable background refresh using stored reference
    if (_refreshManager != null) {
      _refreshManager!.setSheetOpen(false);
      debugPrint('📋 WebViewSheet closing - background refresh ENABLED');
    }

    super.dispose();
  }
}
