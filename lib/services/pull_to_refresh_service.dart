// lib/services/pull_to_refresh_service.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum RefreshContext {
  mainScreen,
  webViewPage,
  sheetWebView,
}

class PullToRefreshService {
  static final PullToRefreshService _instance = PullToRefreshService._internal();
  factory PullToRefreshService() => _instance;
  PullToRefreshService._internal();

  /// Inject native pull-to-refresh functionality into a WebView
  /// 
  /// Parameters:
  /// - [controller]: The WebViewController to inject the refresh functionality into
  /// - [context]: The context type (mainScreen, webViewPage, or sheetWebView)
  /// - [tabIndex]: For main screen tabs (optional, defaults to 0)
  /// - [refreshChannelName]: The JavaScript channel name for refresh communication
  /// - [flutterContext]: Flutter BuildContext for theme detection
  void injectNativePullToRefresh({
    required WebViewController controller,
    required RefreshContext context,
    required String refreshChannelName,
    int tabIndex = 0,
    BuildContext? flutterContext,
  }) {
    try {
      final contextName = _getContextName(context);
      final elementId = _getElementId(context, tabIndex);
      final thresholds = _getThresholds(context);
      final positioning = _getPositioning(context);
      
      debugPrint('🔄 Injecting STRICT pull-to-refresh for $contextName...');

      // Get current theme from Flutter
      String currentFlutterTheme = 'light';
      if (flutterContext != null) {
        final brightness = Theme.of(flutterContext).brightness;
        currentFlutterTheme = brightness == Brightness.dark ? 'dark' : 'light';
      }

      controller.runJavaScript('''
      (function() {
        console.log('🔄 Starting STRICT pull-to-refresh with Flutter theme sync for $contextName...');
        
        // Configuration
        const PULL_THRESHOLD = ${thresholds['pullThreshold']};
        const MIN_PULL_SPEED = ${thresholds['minPullSpeed']};
        const channelName = '$refreshChannelName';
        const contextName = '$contextName';
        const elementId = '$elementId';
        ${tabIndex > 0 ? 'const tabIndex = $tabIndex;' : ''}
        
        // Remove any existing refresh elements
        const existing = document.getElementById(elementId);
        if (existing) existing.remove();
        
        // State variables
        let startY = 0;
        let currentPull = 0;
        let maxPull = 0;
        let isPulling = false;
        let isRefreshing = false;
        let canPull = false;
        let hasReachedThreshold = false;
        let refreshBlocked = false;
        let currentTheme = '$currentFlutterTheme'; // Start with Flutter's current theme
        
        // Function to detect current theme (enhanced with Flutter preference)
        function detectCurrentTheme() {
          return currentTheme;
        }
        
        // Function to get theme colors
        function getThemeColors(theme) {
          if (theme === 'dark') {
            return {
              background: 'rgba(40, 40, 40, 0.95)',
              progressDefault: '#60A5FA',
              progressReady: '#34D399',
              shadow: '0 4px 12px rgba(0, 0, 0, 0.4)'
            };
          } else {
            return {
              background: 'rgba(255, 255, 255, 0.95)',
              progressDefault: '#0078d7',
              progressReady: '#28a745',
              shadow: '0 2px 8px rgba(0, 0, 0, 0.15)'
            };
          }
        }
        
        // Function to check if refresh is allowed
        function isRefreshAllowed() {
          return !refreshBlocked;
        }
        
        // Function for Flutter to update refresh state
        window.setRefreshBlocked = function(blocked) {
          refreshBlocked = blocked;
          console.log('🔄 ' + contextName + ' refresh state updated:', blocked ? 'BLOCKED' : 'ALLOWED');
          
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
        
        // Function for Flutter to update theme
        window.updateRefreshTheme = function(newTheme) {
          if (newTheme && newTheme !== currentTheme) {
            console.log('🎨 Flutter theme update for ' + contextName + ': ' + currentTheme + ' → ' + newTheme);
            currentTheme = newTheme;
            updateIndicatorTheme();
            return true;
          }
          return false;
        };
        
        // Create refresh indicator with dynamic theming
        const refreshDiv = document.createElement('div');
        refreshDiv.id = elementId;
        
        refreshDiv.innerHTML = \`
          <div class="refresh-circle">
            <svg class="refresh-svg" width="24" height="24" viewBox="0 0 24 24">
              <circle class="refresh-progress" cx="12" cy="12" r="10" fill="none" stroke-width="2" 
                      stroke-linecap="round" stroke-dasharray="63" stroke-dashoffset="63" 
                      transform="rotate(-90 12 12)"/>
            </svg>
          </div>
        \`;
        
        // Function to update indicator theme
        function updateIndicatorTheme() {
          const theme = detectCurrentTheme();
          const colors = getThemeColors(theme);
          console.log('🎨 Updating ' + contextName + ' refresh indicator theme to:', theme);
          
          refreshDiv.style.background = colors.background;
          refreshDiv.style.boxShadow = colors.shadow;
          
          const progressCircle = refreshDiv.querySelector('.refresh-progress');
          if (progressCircle) {
            if (hasReachedThreshold) {
              progressCircle.style.stroke = colors.progressReady;
            } else {
              progressCircle.style.stroke = colors.progressDefault;
            }
          }
          
          document.documentElement.style.setProperty('--refresh-default-color', colors.progressDefault);
          document.documentElement.style.setProperty('--refresh-ready-color', colors.progressReady);
        }
        
        // Set positioning based on context
        refreshDiv.style.cssText = \`
          position: ${positioning['position']};
          top: ${positioning['top']};
          left: 50%;
          transform: ${positioning['transform']};
          width: 40px;
          height: 40px;
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 9999;
          border-radius: 50%;
          opacity: 0;
          transition: all 0.2s ease;
          pointer-events: none;
        \`;
        
        // Add styles
        const circleStyles = document.createElement('style');
        circleStyles.innerHTML = \`
          :root {
            --refresh-default-color: #0078d7;
            --refresh-ready-color: #28a745;
          }
          
          .refresh-circle {
            width: 24px;
            height: 24px;
          }
          
          .refresh-svg {
            width: 100%;
            height: 100%;
          }
          
          .refresh-progress {
            transition: stroke-dashoffset 0.1s ease-out, stroke 0.2s ease;
            stroke: var(--refresh-default-color);
          }
          
          .refresh-ready .refresh-progress {
            stroke: var(--refresh-ready-color) !important;
          }
          
          .refresh-spinning .refresh-svg {
            animation: simpleRefreshSpin 1s linear infinite;
          }
          
          .refresh-spinning .refresh-progress {
            stroke: var(--refresh-default-color) !important;
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
        \`;
        
        document.head.appendChild(circleStyles);
        document.body.appendChild(refreshDiv);
        
        // Initial theme setup
        updateIndicatorTheme();
        
        // Prevent overscroll
        document.body.style.cssText += \`
          overscroll-behavior-y: contain;
          overflow-anchor: none;
          -webkit-overflow-scrolling: touch;
        \`;
        
        // Check if at top of page - MORE STRICT
        function isAtTop() {
          const scrollTop = Math.max(
            window.pageYOffset || 0,
            document.documentElement.scrollTop || 0,
            document.body.scrollTop || 0
          );
          
          // Be very strict - must be exactly at the top
          const isExactlyAtTop = scrollTop === 0;
          
          // Log for debugging
          if (scrollTop > 0 && scrollTop <= 10) {
            console.log('🔍 ' + contextName + ' scroll position:', scrollTop, 'isAtTop:', isExactlyAtTop);
          }
          
          return isExactlyAtTop;
        }
        
        // Update refresh indicator
        function updateRefresh(distance) {
          const progress = Math.min(distance / PULL_THRESHOLD, 1);
          
          refreshDiv.style.opacity = progress > 0.1 ? '1' : '0';
          
          ${_getUpdateRefreshLogic(context)}
          
          const circleProgress = progress * 100;
          const strokeDashoffset = 63 - (circleProgress * 0.63);
          const progressCircle = refreshDiv.querySelector('.refresh-progress');
          progressCircle.style.strokeDashoffset = strokeDashoffset;
          
          refreshDiv.classList.remove('refresh-ready');
          if (progress >= 1) {
            hasReachedThreshold = true;
            refreshDiv.classList.add('refresh-ready');
          } else {
            hasReachedThreshold = false;
          }
          
          updateIndicatorTheme();
          
          console.log(\`🔄 \${contextName} animation: \${Math.round(progress * 100)}% (theme: \${currentTheme})\`);
        }
        
        // Hide indicator
        function hideRefresh() {
          refreshDiv.style.opacity = '0';
          refreshDiv.classList.remove('refresh-ready', 'refresh-spinning');
          refreshDiv.querySelector('.refresh-progress').style.strokeDashoffset = '63';
          hasReachedThreshold = false;
          ${_getHideRefreshLogic(context)}
          updateIndicatorTheme();
        }
        
        // Start refreshing animation
        function doRefresh() {
          if (isRefreshing || !hasReachedThreshold || !isRefreshAllowed()) {
            console.log(\`❌ \${contextName} refresh denied\`);
            hideRefresh();
            return;
          }
          
          console.log('✅ ' + contextName.toUpperCase() + ' REFRESH TRIGGERED!');
          isRefreshing = true;
          
          refreshDiv.classList.remove('refresh-ready');
          refreshDiv.classList.add('refresh-spinning');
          refreshDiv.style.opacity = '1';
          ${_getDoRefreshLogic(context)}
          updateIndicatorTheme();
          
          if (window[channelName]) {
            window[channelName].postMessage('refresh');
            console.log('📤 ' + contextName + ' refresh message sent');
          }
          
          setTimeout(() => {
            hideRefresh();
            isRefreshing = false;
          }, 1500);
        }
        
        // Touch event handlers - ENHANCED with better top detection
        document.addEventListener('touchstart', function(e) {
          if (isRefreshing || !isRefreshAllowed()) return;
          
          // Double-check that we're really at the top
          const currentlyAtTop = isAtTop();
          
          if (currentlyAtTop) {
            canPull = true;
            startY = e.touches[0].clientY;
            currentPull = 0;
            maxPull = 0;
            isPulling = false;
            hasReachedThreshold = false;
            console.log('👆 ' + contextName + ': Touch start at TOP - ready to pull (scrollTop: 0)');
          } else {
            canPull = false;
            const scrollTop = Math.max(
              window.pageYOffset || 0,
              document.documentElement.scrollTop || 0,
              document.body.scrollTop || 0
            );
            console.log('🚫 ' + contextName + ': Touch start NOT at top - scroll position:', scrollTop);
          }
        }, { passive: false });
        
        document.addEventListener('touchmove', function(e) {
          if (!canPull || isRefreshing || !isRefreshAllowed()) return;
          
          const currentY = e.touches[0].clientY;
          const deltaY = currentY - startY;
          
          // TRIPLE CHECK: Only allow pull if we're at top AND pulling down
          if (deltaY > 0 && isAtTop()) {
            currentPull = deltaY;
            maxPull = Math.max(maxPull, deltaY);
            
            if (deltaY >= MIN_PULL_SPEED) {
              e.preventDefault();
              isPulling = true;
              updateRefresh(deltaY);
            }
          } else if (isPulling) {
            // If user scrolls up or away from top, immediately reset
            isPulling = false;
            hideRefresh();
            canPull = false; // Disable pulling until next touchstart
            console.log('🛑 ' + contextName + ': Stopped pulling - not at top or scrolling up');
          }
        }, { passive: false });
        
        document.addEventListener('touchend', function(e) {
          if (!isPulling || isRefreshing || !isRefreshAllowed()) {
            // Reset all states
            isPulling = false;
            canPull = false;
            hasReachedThreshold = false;
            return;
          }
          
          // FINAL CHECK: Make sure we're still at top when releasing
          if (hasReachedThreshold && maxPull >= PULL_THRESHOLD && isAtTop()) {
            console.log('✅ ' + contextName.toUpperCase() + ' STRICT SUCCESS: User pulled to threshold at top - refreshing!');
            doRefresh();
          } else {
            console.log(\`❌ \${contextName.toUpperCase()} STRICT FAIL: Not enough pull or not at top\`);
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
        
        document.addEventListener('touchcancel', function(e) {
          hideRefresh();
          isPulling = false;
          canPull = false;
          hasReachedThreshold = false;
          currentPull = 0;
          maxPull = 0;
        }, { passive: true });
        
        console.log('✅ ' + contextName.toUpperCase() + ' pull-to-refresh with Flutter theme sync ready!');
        console.log('🎨 Current theme from Flutter:', currentTheme);
        
      })();
      ''');

      debugPrint('✅ STRICT pull-to-refresh injected for $contextName');
    } catch (e) {
    }
  }

  String _getContextName(RefreshContext context) {
    switch (context) {
      case RefreshContext.mainScreen:
        return 'MAIN SCREEN';
      case RefreshContext.webViewPage:
        return 'WEBVIEW PAGE';
      case RefreshContext.sheetWebView:
        return 'WEBVIEW SHEET';
    }
  }

  String _getElementId(RefreshContext context, int tabIndex) {
    switch (context) {
      case RefreshContext.mainScreen:
        return 'strict-refresh-main-$tabIndex';
      case RefreshContext.webViewPage:
        return 'strict-refresh-page';
      case RefreshContext.sheetWebView:
        return 'strict-refresh-sheet';
    }
  }

  Map<String, int> _getThresholds(RefreshContext context) {
    switch (context) {
      case RefreshContext.mainScreen:
        return {'pullThreshold': 450, 'minPullSpeed': 150};
      case RefreshContext.webViewPage:
        return {'pullThreshold': 450, 'minPullSpeed': 150};
      case RefreshContext.sheetWebView:
        return {'pullThreshold': 350, 'minPullSpeed': 150};
    }
  }

  Map<String, String> _getPositioning(RefreshContext context) {
    switch (context) {
      case RefreshContext.mainScreen:
        return {
          'position': 'fixed',
          'top': '10px',
          'transform': 'translateX(-50%)',
        };
      case RefreshContext.webViewPage:
        return {
          'position': 'fixed',
          'top': '10px',
          'transform': 'translateX(-50%)',
        };
      case RefreshContext.sheetWebView:
        return {
          'position': 'absolute',
          'top': '80px',
          'transform': 'translateX(-50%) translateY(-100px)',
        };
    }
  }

  String _getUpdateRefreshLogic(RefreshContext context) {
    switch (context) {
      case RefreshContext.mainScreen:
      case RefreshContext.webViewPage:
        return '// Standard positioning - no special transform needed';
      case RefreshContext.sheetWebView:
        return '''
          // Sheet-specific positioning
          const translateY = Math.min(distance * 0.3, 60) - 100;
          refreshDiv.style.transform = \`translateX(-50%) translateY(\${translateY}px)\`;
        ''';
    }
  }

  String _getHideRefreshLogic(RefreshContext context) {
    switch (context) {
      case RefreshContext.mainScreen:
      case RefreshContext.webViewPage:
        return '// Standard hide - no special positioning';
      case RefreshContext.sheetWebView:
        return "refreshDiv.style.transform = 'translateX(-50%) translateY(-100px)';";
    }
  }

  String _getDoRefreshLogic(RefreshContext context) {
    switch (context) {
      case RefreshContext.mainScreen:
      case RefreshContext.webViewPage:
        return '// Standard refresh positioning';
      case RefreshContext.sheetWebView:
        return "refreshDiv.style.transform = 'translateX(-50%) translateY(20px)';";
    }
  }
}