import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ERPForever/services/config_service.dart';
import 'package:ERPForever/services/webview_service.dart';
import 'package:ERPForever/services/webview_controller_manager.dart';
import 'package:ERPForever/services/theme_service.dart';
import 'package:ERPForever/services/auth_service.dart';
import 'package:ERPForever/widgets/dynamic_bottom_navigation.dart';
import 'package:ERPForever/widgets/dynamic_app_bar.dart';
import 'package:ERPForever/widgets/loading_widget.dart';
import 'package:ERPForever/pages/barcode_scanner_page.dart';
import 'package:ERPForever/pages/login_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late ConfigService _configService;
  late WebViewControllerManager _controllerManager;

  final Map<int, bool> _loadingStates = {};
  final Map<int, bool> _isAtTopStates = {};
  final Map<int, bool> _isRefreshingStates = {};
  final Map<int, bool> _channelAdded = {};

  @override
  void initState() {
    super.initState();
    _configService = ConfigService();
    _controllerManager = WebViewControllerManager();

    _initializeLoadingStates();
  }

  void _initializeLoadingStates() {
    final config = _configService.config;
    if (config != null) {
      for (int i = 0; i < config.mainIcons.length; i++) {
        _loadingStates[i] = true;
        _isAtTopStates[i] = true; 
        _isRefreshingStates[i] = false;
        _channelAdded[i] = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigService>(
      builder: (context, configService, child) {
        if (!configService.isLoaded) {
          return const Scaffold(
            body: Center(
              child: LoadingWidget(message: "Loading configuration..."),
            ),
          );
        }

        if (configService.error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Configuration Error',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      configService.error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => configService.reloadConfig(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildMainScaffold(configService.config!);
      },
    );
  }

  Widget _buildMainScaffold(config) {
    return Scaffold(
      appBar: DynamicAppBar(selectedIndex: _selectedIndex),
      body: _buildBody(config),
      bottomNavigationBar: DynamicBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildBody(config) {
    if (config.mainIcons.isEmpty) {
      return const Center(child: Text('No navigation items configured'));
    }

    return IndexedStack(
      index: _selectedIndex,
      children: List.generate(
        config.mainIcons.length,
        (index) => _buildTabContent(index, config.mainIcons[index]),
      ),
    );
  }

  Widget _buildTabContent(int index, mainIcon) {
    if (mainIcon.linkType == 'sheet_webview') {
      return const Center(child: Text('This tab opens as a sheet'));
    }

    return _buildRefreshableWebViewContent(index, mainIcon);
  }

  Widget _buildRefreshableWebViewContent(int index, mainIcon) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) => false, // Don't handle here
      child: RefreshIndicator(
        onRefresh: () => _refreshWebView(index),
        // Custom condition: only allow refresh when webview is at top
        child: SingleChildScrollView(
          physics:
              _isAtTopStates[index] == true
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height:
                MediaQuery.of(context).size.height -
                kToolbarHeight -
                kBottomNavigationBarHeight -
                MediaQuery.of(context).padding.top,
            child: Stack(
              children: [
                _buildWebView(index, mainIcon.link),
                if (_loadingStates[index] == true ||
                    _isRefreshingStates[index] == true)
                  const LoadingWidget(),
                // Custom refresh indicator when at top
                if (_isAtTopStates[index] == true &&
                    _isRefreshingStates[index] == false)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(height: 2, color: Colors.transparent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshWebView(int index) async {
    if (_isRefreshingStates[index] == true)
      return; // Prevent multiple refreshes

    debugPrint('🔄 Refreshing WebView at index $index');

    setState(() {
      _isRefreshingStates[index] = true;
    });

    try {
      final controller = _controllerManager.getController(index, '', context);
      await controller.reload();

      // Wait for page to start loading
      await Future.delayed(const Duration(milliseconds: 800));

      debugPrint('✅ WebView refreshed successfully');
    } catch (e) {
      debugPrint('❌ Error refreshing WebView: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingStates[index] = false;
        });
      }
    }
  }

  Widget _buildWebView(int index, String url) {
    final controller = _controllerManager.getController(index, url, context);

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          if (mounted) {
            setState(() {
              _loadingStates[index] = true;
              _isAtTopStates[index] = true; // Reset to top when new page loads
            });
          }
        },
        onPageFinished: (String url) {
          if (mounted) {
            setState(() {
              _loadingStates[index] = false;
            });
          }
          _injectScrollMonitoring(controller, index);
        },
        onWebResourceError: (WebResourceError error) {
          if (mounted) {
            setState(() {
              _loadingStates[index] = false;
            });
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          return _handleNavigationRequest(request);
        },
      ),
    );

    return WebViewWidget(controller: controller);
  }

  void _injectScrollMonitoring(WebViewController controller, int index) {
    // FIXED: Check if channel is already added to prevent duplicate channel error
    if (_channelAdded[index] == true) {
      debugPrint(
        '📍 JavaScript channel already added for tab $index, skipping...',
      );
      return;
    }

    try {
      // Add JavaScript channel first
      controller.addJavaScriptChannel(
        'ScrollMonitor_$index',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final isAtTop = message.message == 'true';

            if (mounted && _isAtTopStates[index] != isAtTop) {
              setState(() {
                _isAtTopStates[index] = isAtTop;
              });
              debugPrint(
                '📍 Tab $index scroll position: ${isAtTop ? "TOP" : "SCROLLED"}',
              );
            }
          } catch (e) {
            debugPrint('❌ Error parsing scroll message: $e');
          }
        },
      );

      // Mark channel as added
      _channelAdded[index] = true;
      debugPrint('✅ JavaScript channel added for tab $index');

      // Then inject the monitoring script
      controller.runJavaScript('''
        (function() {
          let isAtTop = true;
          let scrollTimeout;
          const channelName = 'ScrollMonitor_$index';
          
          function checkScrollPosition() {
            const scrollTop = window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop || 0;
            const newIsAtTop = scrollTop <= 5; // Very small threshold
            
            if (newIsAtTop !== isAtTop) {
              isAtTop = newIsAtTop;
              
              // Send to Flutter
              if (window[channelName] && window[channelName].postMessage) {
                window[channelName].postMessage(isAtTop.toString());
              }
            }
          }
          
          // Optimized scroll listener
          function onScroll() {
            if (scrollTimeout) {
              clearTimeout(scrollTimeout);
            }
            scrollTimeout = setTimeout(checkScrollPosition, 50);
          }
          
          // Remove existing listeners
          window.removeEventListener('scroll', onScroll);
          
          // Add scroll listener
          window.addEventListener('scroll', onScroll, { passive: true });
          
          // Initial check
          setTimeout(checkScrollPosition, 100);
          
          console.log('✅ Scroll monitoring initialized for tab $index');
        })();
      ''');
    } catch (e) {
      debugPrint('❌ Error adding JavaScript channel for tab $index: $e');
      _channelAdded[index] = false;
    }
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    debugPrint("Navigation request: ${request.url}");

    // Theme requests
    if (request.url.startsWith('dark-mode://') ||
        request.url.startsWith('light-mode://') ||
        request.url.startsWith('system-mode://')) {
      _handleThemeChangeRequest(request.url);
      return NavigationDecision.prevent;
    }

    // Auth requests
    if (request.url.startsWith('logout://')) {
      _handleLogoutRequest();
      return NavigationDecision.prevent;
    }

    // Location requests
    if (request.url.startsWith('get-location://')) {
      _handleLocationRequest();
      return NavigationDecision.prevent;
    }

    // Contacts requests - ADD THIS
    if (request.url.startsWith('get-contacts://')) {
      _handleContactsRequest();
      return NavigationDecision.prevent;
    }

    // Other navigation requests
    if (request.url.startsWith('new-web://')) {
      _handleNewWebNavigation(request.url);
      return NavigationDecision.prevent;
    }

    if (request.url.startsWith('new-sheet://')) {
      _handleSheetNavigation(request.url);
      return NavigationDecision.prevent;
    }

    // Barcode requests
    if (request.url.contains('barcode') || request.url.contains('scan')) {
      _handleBarcodeScanning(request.url);
      return NavigationDecision.prevent;
    }
     if (request.url.startsWith('take-screenshot://')) {
    _handleScreenshotRequest();
    return NavigationDecision.prevent;
  }
  // Image save requests
if (request.url.startsWith('save-image://')) {
  _handleImageSaveRequest(request.url);
  return NavigationDecision.prevent;
}
if (request.url.startsWith('save-pdf://')) {
  _handlePdfSaveRequest(request.url);
  return NavigationDecision.prevent;
}

    return NavigationDecision.navigate;
  }
  void _handlePdfSaveRequest(String url) {
  debugPrint('📄 PDF save requested from WebView: $url');

  final controller = _controllerManager.getController(
    _selectedIndex,
    '',
    context,
  );

  controller.runJavaScript('''
    if (window.PdfSaver && window.PdfSaver.postMessage) {
      window.PdfSaver.postMessage("$url");
      console.log("✅ PDF save request sent");
    } else {
      console.log("❌ PdfSaver not found");
    }
  ''');
}
  void _handleImageSaveRequest(String url) {
  debugPrint('🖼️ Image save requested from WebView: $url');

  final controller = _controllerManager.getController(
    _selectedIndex,
    '',
    context,
  );

  controller.runJavaScript('''
    if (window.ImageSaver && window.ImageSaver.postMessage) {
      window.ImageSaver.postMessage("$url");
      console.log("✅ Image save request sent");
    } else {
      console.log("❌ ImageSaver not found");
    }
  ''');
}
  void _handleScreenshotRequest() {
  debugPrint('📸 Screenshot requested from WebView');

  final controller = _controllerManager.getController(
    _selectedIndex,
    '',
    context,
  );

  controller.runJavaScript('''
    if (window.ScreenshotManager && window.ScreenshotManager.postMessage) {
      window.ScreenshotManager.postMessage('takeScreenshot');
      console.log("✅ Screenshot request sent");
    } else {
      console.log("❌ ScreenshotManager not found");
    }
  ''');
}

  void _handleContactsRequest() {
    debugPrint('📞 Contacts requested from WebView');

    final controller = _controllerManager.getController(
      _selectedIndex,
      '',
      context,
    );

    controller.runJavaScript('''
    if (window.ContactsManager && window.ContactsManager.postMessage) {
      window.ContactsManager.postMessage('getAllContacts');
      console.log("✅ Contacts request sent");
    } else {
      console.log("❌ ContactsManager not found");
    }
  ''');
  }

  void _handleLocationRequest() {
    debugPrint('🌍 Location requested from WebView');

    // The WebViewService will handle the actual location logic
    // We just need to trigger it through the current controller
    final controller = _controllerManager.getController(
      _selectedIndex,
      '',
      context,
    );

    // This will trigger the location service through JavaScript
    controller.runJavaScript('''
      if (window.LocationManager && window.LocationManager.postMessage) {
        window.LocationManager.postMessage('getCurrentLocation');
        console.log("✅ Location request forwarded to LocationManager");
      } else {
        console.log("❌ LocationManager not found");
      }
    ''');
  }

  void _handleLogoutRequest() {
    debugPrint('🚪 Logout requested from WebView');
    _performLogout();
  }

  void _performLogout() async {
    try {
      // Get the AuthService and logout
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();

      debugPrint('✅ User logged out successfully');

      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error during logout: $e');

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error during logout'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleThemeChangeRequest(String url) {
    String themeMode = 'system';

    if (url.startsWith('dark-mode://')) {
      themeMode = 'dark';
    } else if (url.startsWith('light-mode://')) {
      themeMode = 'light';
    } else if (url.startsWith('system-mode://')) {
      themeMode = 'system';
    }

    final themeService = Provider.of<ThemeService>(context, listen: false);
    themeService.updateThemeMode(themeMode);
  }

  void _handleNewWebNavigation(String url) {
    String targetUrl = 'https://www.erpforever.com/mobile/test';

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

    WebViewService().navigate(
      context,
      url: targetUrl,
      linkType: 'regular_webview',
      title: 'Web View',
    );
  }

  void _handleSheetNavigation(String url) {
    String targetUrl = 'https://mujeer.com';

    if (url.contains('?')) {
      try {
        Uri uri = Uri.parse(url.replaceFirst('new-sheet://', 'https://'));
        if (uri.queryParameters.containsKey('url')) {
          targetUrl = uri.queryParameters['url']!;
        }
      } catch (e) {
        debugPrint("Error parsing URL parameters: $e");
      }
    }

    WebViewService().navigate(
      context,
      url: targetUrl,
      linkType: 'sheet_webview',
      title: 'Web View',
    );
  }

  void _handleBarcodeScanning(String url) {
    debugPrint("Barcode scanning triggered: $url");

    bool isContinuous =
        url.contains('continuous') || url.contains('Continuous');

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (context) => BarcodeScannerPage(
              isContinuous: isContinuous,
              onBarcodeScanned: (String barcode) {
                _handleBarcodeResult(barcode);
              },
            ),
      ),
    );
  }

  void _handleBarcodeResult(String barcode) {
    debugPrint("Barcode scanned: $barcode");

    final controller = _controllerManager.getController(
      _selectedIndex,
      '',
      context,
    );

    controller.runJavaScript('''
      if (typeof getBarcode === 'function') {
        getBarcode("$barcode");
        console.log("Called getBarcode() with: $barcode");
      } else if (typeof window.handleBarcodeResult === 'function') {
        window.handleBarcodeResult("$barcode");
        console.log("Called handleBarcodeResult with: $barcode");
      } else {
        var inputs = document.querySelectorAll('input[type="text"]');
        if(inputs.length > 0) {
          inputs[0].value = "$barcode";
          inputs[0].dispatchEvent(new Event('input'));
          console.log("Filled input field with: $barcode");
        }
        
        var event = new CustomEvent('barcodeScanned', { detail: { result: "$barcode" } });
        document.dispatchEvent(event);
      }
    ''');
  }

  void _onItemTapped(int index) {
    final config = _configService.config;
    if (config == null) return;

    final item = config.mainIcons[index];

    if (item.linkType == 'sheet_webview') {
      WebViewService().navigate(
        context,
        url: item.link,
        linkType: item.linkType,
        title: item.title,
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  void dispose() {
    // Clean up when disposing
    _controllerManager.clearControllers();
    super.dispose();
  }
}
