import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'package:ERPForever/services/alert_service.dart';
import 'package:ERPForever/services/refresh_state_manager.dart';


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
  final Map<int, bool> _refreshChannelAdded = {};
  final Map<int, String> _refreshChannelNames = {};

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
        _refreshChannelAdded[i] = false; // ADD THIS LINE
        _refreshChannelNames[i] =
            'MainScreenRefresh_${i}_${DateTime.now().millisecondsSinceEpoch}';
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
  return Consumer<RefreshStateManager>(
    builder: (context, refreshManager, child) {
      // Cache the refresh state to avoid calling shouldAllowRefresh during build
      final isRefreshAllowed = refreshManager.isRefreshEnabled;
      
      return NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) => false,
        child: RefreshIndicator(
          // Use cached value instead of method call
          onRefresh: isRefreshAllowed
              ? () => _refreshWebView(index)
              : () async {
                  debugPrint('🚫 Refresh blocked - sheet is open');
                  return;
                },
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height -
                  kToolbarHeight -
                  kBottomNavigationBarHeight -
                  MediaQuery.of(context).padding.top,
              child: Stack(
                children: [
                  _buildWebView(index, mainIcon.link),
                  if (_loadingStates[index] == true ||
                      _isRefreshingStates[index] == true)
                    const LoadingWidget(),
                  // Use cached value for refresh indicator visibility
                  if (_isAtTopStates[index] == true &&
                      _isRefreshingStates[index] == false &&
                      isRefreshAllowed) // Use cached value
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
    },
  );
}
  Future<void> _refreshWebView(int index) async {
      final refreshManager = Provider.of<RefreshStateManager>(context, listen: false);
  
  if (!refreshManager.shouldAllowRefresh()) {
    debugPrint('🚫 Refresh blocked by RefreshStateManager');
    return;
  }
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

    // FIXED: Check if refresh channel is already added to prevent duplicate channel error
    if (_refreshChannelAdded[index] != true) {
      final refreshChannelName = _refreshChannelNames[index]!;
      try {
        controller.addJavaScriptChannel(
          refreshChannelName,
          onMessageReceived: (JavaScriptMessage message) {
            if (message.message == 'refresh') {
              debugPrint(
                '🔄 Pull-to-refresh triggered from JavaScript for tab $index',
              );
              _handleJavaScriptRefresh(index);
            }
          },
        );
        _refreshChannelAdded[index] = true;
        debugPrint(
          '✅ Pull-to-refresh channel added for tab $index: $refreshChannelName',
        );
      } catch (e) {
        debugPrint('❌ Error adding refresh channel for tab $index: $e');
        _refreshChannelAdded[index] = false;
      }
    } else {
      debugPrint(
        '📍 Pull-to-refresh channel already added for tab $index, skipping...',
      );
    }

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          debugPrint('🔄 Page started loading for tab $index: $url');
          if (mounted) {
            setState(() {
              _loadingStates[index] = true;
              _isAtTopStates[index] = true;
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

          // Add native pull-to-refresh after page loads
          Future.delayed(const Duration(milliseconds: 800), () {
            _injectNativePullToRefresh(controller, index);
          });
        },
        onWebResourceError: (WebResourceError error) {
          if (mounted) {
            setState(() {
              _loadingStates[index] = false;
            });
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          // Update controller reference before handling navigation
          WebViewService().updateController(controller, context);
          return _handleNavigationRequest(request);
        },
      ),
    );

    return WebViewWidget(controller: controller);
  }

void _injectNativePullToRefresh(WebViewController controller, int index) {
  try {
    final refreshChannelName = _refreshChannelNames[index]!;

    debugPrint('🔄 Injecting STRICT pull-to-refresh (must pull to END) for tab $index...');

    controller.runJavaScript('''
    (function() {
      console.log('🔄 Starting STRICT pull-to-refresh (must complete pull) for main screen tab $index...');
      
      // STRICT configuration - must pull all the way
      const PULL_THRESHOLD = 450;  // Must pull THIS far to activate (INCREASED FOR TESTING)
      const MIN_PULL_SPEED = 150;   // Minimum pull distance to even start
      const channelName = '$refreshChannelName';
      const tabIndex = $index;
      
      // Remove any existing refresh elements
      const existing = document.getElementById('strict-refresh-main-' + tabIndex);
      if (existing) existing.remove();
      
      // State variables
      let startY = 0;
      let currentPull = 0;
      let maxPull = 0;  // Track maximum pull distance
      let isPulling = false;
      let isRefreshing = false;
      let canPull = false;
      let hasReachedThreshold = false;  // NEW: Must reach threshold to refresh
      let refreshBlocked = false;
      
      // Function to check if refresh is allowed
      function isRefreshAllowed() {
        return !refreshBlocked;
      }
      
      // Function for Flutter to update refresh state
      window.setRefreshBlocked = function(blocked) {
        refreshBlocked = blocked;
        console.log('🔄 Main screen tab $index refresh state updated:', blocked ? 'BLOCKED' : 'ALLOWED');
        
        if (blocked && isPulling) {
          isPulling = false;
          currentPull = 0;
          maxPull = 0;
          canPull = false;
          hasReachedThreshold = false;
          if (refreshDiv) {
            hideRefresh();
          }
        }
      };
      
      // Create simple animation-only refresh indicator
      const refreshDiv = document.createElement('div');
      refreshDiv.id = 'strict-refresh-main-' + tabIndex;
      
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
      
      // Simple, fixed positioning - NO BLACK AREA
      refreshDiv.style.cssText = \`
        position: fixed;
        top: 10px;
        left: 50%;
        transform: translateX(-50%);
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
          #strict-refresh-main-\${tabIndex} {
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
      
      // Update simple animation indicator
      function updateRefresh(distance) {
        const progress = Math.min(distance / PULL_THRESHOLD, 1);
        
        // Show indicator only when pulling
        refreshDiv.style.opacity = progress > 0.1 ? '1' : '0';
        
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
        
        console.log(\`🔄 Main screen tab $index animation: \${Math.round(progress * 100)}%\`);
      }
      
      // Hide simple indicator
      function hideRefresh() {
        refreshDiv.style.opacity = '0';
        refreshDiv.classList.remove('refresh-ready', 'refresh-spinning');
        refreshDiv.querySelector('.refresh-progress').style.strokeDashoffset = '63';
        hasReachedThreshold = false;
      }
      
      // Start simple refreshing animation
      function doRefresh() {
        if (isRefreshing || !hasReachedThreshold || !isRefreshAllowed()) {
          console.log(\`❌ Main screen tab $index refresh denied\`);
          hideRefresh();
          return;
        }
        
        console.log('✅ MAIN SCREEN TAB $index REFRESH TRIGGERED!');
        isRefreshing = true;
        
        // Show simple spinning animation
        refreshDiv.classList.remove('refresh-ready');
        refreshDiv.classList.add('refresh-spinning');
        refreshDiv.style.opacity = '1';
        
        // Send refresh signal
        if (window[channelName]) {
          window[channelName].postMessage('refresh');
          console.log('📤 Main screen tab $index refresh message sent');
        }
        
        // Auto-hide after 1.5 seconds
        setTimeout(() => {
          hideRefresh();
          isRefreshing = false;
        }, 1500);
      }
      
      // STRICT Touch handlers
      document.addEventListener('touchstart', function(e) {
        if (isRefreshing || !isRefreshAllowed()) return;
        
        if (isAtTop()) {
          canPull = true;
          startY = e.touches[0].clientY;
          currentPull = 0;
          maxPull = 0;
          isPulling = false;
          hasReachedThreshold = false;
          console.log('👆 MAIN SCREEN TAB $index: Touch start at top - ready to pull');
        } else {
          canPull = false;
        }
      }, { passive: false });
      
      // STRICT Touch move - only show indicator after minimum pull
      document.addEventListener('touchmove', function(e) {
        if (!canPull || isRefreshing || !isRefreshAllowed()) return;
        
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
        if (!isPulling || isRefreshing || !isRefreshAllowed()) {
          // Reset states even if not pulling
          isPulling = false;
          canPull = false;
          hasReachedThreshold = false;
          return;
        }
        
        console.log(\`🖱️ MAIN SCREEN TAB $index STRICT RELEASE:
          - Current pull: \${Math.round(currentPull)}px
          - Max pull reached: \${Math.round(maxPull)}px  
          - Threshold: \${PULL_THRESHOLD}px
          - Threshold reached: \${hasReachedThreshold}
          - Will refresh: \${hasReachedThreshold}\`);
        
        if (hasReachedThreshold && maxPull >= PULL_THRESHOLD) {
          console.log('✅ MAIN SCREEN TAB $index STRICT SUCCESS: User pulled to threshold - refreshing!');
          doRefresh();
        } else {
          console.log(\`❌ MAIN SCREEN TAB $index STRICT FAIL: Not enough pull (max: \${Math.round(maxPull)}px, needed: \${PULL_THRESHOLD}px)\`);
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
        console.log('❌ MAIN SCREEN TAB $index STRICT: Touch cancelled - resetting');
        hideRefresh();
        isPulling = false;
        canPull = false;
        hasReachedThreshold = false;
        currentPull = 0;
        maxPull = 0;
      }, { passive: true });
      
      console.log('✅ MAIN SCREEN TAB $index STRICT pull-to-refresh ready!');
      console.log(\`📋 MAIN SCREEN TAB $index STRICT Rules:
        - Must be at top of page
        - Must pull at least \${MIN_PULL_SPEED}px to start
        - Must pull \${PULL_THRESHOLD}px to activate refresh
        - Must RELEASE while in green state to refresh
        - Any incomplete pull will bounce back\`);
      
      // Test function
      window.testStrictRefreshMain = function() {
        console.log('🧪 Testing strict refresh for main screen tab $index...');
        hasReachedThreshold = true;
        doRefresh();
      };
      
      // Status function
      window.getRefreshStatusMain = function() {
        return {
          tabIndex: $index,
          isPulling: isPulling,
          currentPull: currentPull,
          maxPull: maxPull,
          hasReachedThreshold: hasReachedThreshold,
          isRefreshing: isRefreshing,
          canPull: canPull,
          refreshBlocked: refreshBlocked
        };
      };
      
    })();
    ''');

    debugPrint('✅ STRICT pull-to-refresh injected for main screen tab $index');
  } catch (e) {
    debugPrint('❌ Error injecting STRICT refresh for main screen tab $index: $e');
  }
}
  Future<void> _handleJavaScriptRefresh(int index) async {
     final refreshManager = Provider.of<RefreshStateManager>(context, listen: false);
  
  if (!refreshManager.shouldAllowRefresh()) {
    debugPrint('🚫 JavaScript refresh blocked - sheet is open');
    return;
  }

    debugPrint('🔄 Handling JavaScript refresh request for tab $index');

    if (_isRefreshingStates[index] == true) {
      debugPrint('❌ Already refreshing tab $index, ignoring request');
      return;
    }

    try {
      setState(() {
        _isRefreshingStates[index] = true;
        _loadingStates[index] = true; 
      });

      final controller = _controllerManager.getController(index, '', context);
      await controller.reload();

      // Wait for page to start loading
      await Future.delayed(const Duration(milliseconds: 800));

      debugPrint('✅ JavaScript refresh completed successfully for tab $index');
    } catch (e) {
      debugPrint('❌ Error during JavaScript refresh for tab $index: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingStates[index] = false;
          // Note: Don't set _loadingStates[index] = false here
          // Let the onPageFinished callback handle it
        });
      }
    }
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
      final refreshManager = Provider.of<RefreshStateManager>(context, listen: false);
  refreshManager.registerController(controller);
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    debugPrint("Navigation request: ${request.url}");

    // NEW: Handle external URLs with ?external=1 parameter
    if (request.url.contains('?external=1')) {
      _handleExternalNavigation(request.url);
      return NavigationDecision.prevent;
    }

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

    // Contacts requests
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

    if (request.url.startsWith('alert://') ||
        request.url.startsWith('confirm://') ||
        request.url.startsWith('prompt://')) {
      _handleAlertRequest(request.url);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _handleExternalNavigation(String url) {
    debugPrint('🌐 External navigation detected in MainScreen: $url');

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

  // NEW: Add this helper method to show URL errors
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

  void _handleAlertRequest(String url) async {
    debugPrint('🚨 Alert request received in main screen: $url');

    try {
      Map<String, dynamic> result;
      String alertType = AlertService().getAlertType(url);

      switch (alertType) {
        case 'alert':
          result = await AlertService().showAlertFromUrl(url, context);
          break;
        case 'confirm':
          result = await AlertService().showConfirmFromUrl(url, context);
          break;
        case 'prompt':
          result = await AlertService().showPromptFromUrl(url, context);
          break;
        default:
          result = await AlertService().showAlertFromUrl(url, context);
          break;
      }

      // Send result back to WebView
      _sendAlertResultToCurrentWebView(result, alertType);
    } catch (e) {
      debugPrint('❌ Error handling alert in main screen: $e');

      _sendAlertResultToCurrentWebView({
        'success': false,
        'error': 'Failed to handle alert: ${e.toString()}',
        'errorCode': 'UNKNOWN_ERROR',
      }, 'alert');
    }
  }

  // Add this method to send alert results to the current WebView:
  void _sendAlertResultToCurrentWebView(
    Map<String, dynamic> result,
    String alertType,
  ) {
    final controller = _controllerManager.getController(
      _selectedIndex,
      '',
      context,
    );

    final success = result['success'] ?? false;
    final error = (result['error'] ?? '').replaceAll('"', '\\"');
    final errorCode = result['errorCode'] ?? '';
    final message = (result['message'] ?? '').replaceAll('"', '\\"');
    final userResponse = (result['userResponse'] ?? '').replaceAll('"', '\\"');
    final userInput = (result['userInput'] ?? '').replaceAll('"', '\\"');
    final confirmed = result['confirmed'] ?? false;
    final cancelled = result['cancelled'] ?? false;
    final dismissed = result['dismissed'] ?? false;

    controller.runJavaScript('''
    try {
      console.log("🚨 Alert result from main screen: Type=$alertType, Success=$success");
      
      var alertResult = {
        success: $success,
        type: "$alertType",
        message: "$message",
        userResponse: "$userResponse",
        userInput: "$userInput",
        confirmed: $confirmed,
        cancelled: $cancelled,
        dismissed: $dismissed,
        error: "$error",
        errorCode: "$errorCode"
      };
      
      // Try specific callback functions
      if ("$alertType" === "alert" && typeof getAlertCallback === 'function') {
        getAlertCallback($success, "$message", "$userResponse", "$error");
      } else if ("$alertType" === "confirm" && typeof getConfirmCallback === 'function') {
        getConfirmCallback($success, "$message", $confirmed, $cancelled, "$error");
      } else if ("$alertType" === "prompt" && typeof getPromptCallback === 'function') {
        getPromptCallback($success, "$message", "$userInput", $confirmed, "$error");
      } else if (typeof handleAlertResult === 'function') {
        handleAlertResult(alertResult);
      } else {
        var event = new CustomEvent('alertResult', { detail: alertResult });
        document.dispatchEvent(event);
      }
      
    } catch (error) {
      console.error("❌ Error handling alert result:", error);
    }
  ''');
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
    // FIXED: Changed default URL to mobile.erpforever.com
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

      // Update WebViewService with the new active controller
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          final controller = _controllerManager.getController(
            index,
            '',
            context,
          );
          WebViewService().updateController(controller, context);
        }
      });
    }
  }

  @override
  void dispose() {
    // Clear WebViewService controller reference
    WebViewService().clearCurrentController();

    // Clean up when disposing
    _controllerManager.clearControllers();

    super.dispose();
  }
}