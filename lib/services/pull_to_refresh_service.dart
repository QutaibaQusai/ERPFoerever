import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum RefreshContext { mainScreen, webViewPage, sheetWebView }

class PullToRefreshService {
  static final PullToRefreshService _instance =
      PullToRefreshService._internal();
  factory PullToRefreshService() => _instance;
  PullToRefreshService._internal();

  /// Inject native pull-to-refresh functionality into a WebView
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

      debugPrint(
        '🔄 Injecting ENHANCED pull-to-refresh for $contextName (tab: $tabIndex)...',
      );

      // Get current theme from Flutter
      String currentFlutterTheme = 'light';
      if (flutterContext != null) {
        final brightness = Theme.of(flutterContext).brightness;
        currentFlutterTheme = brightness == Brightness.dark ? 'dark' : 'light';
      }

      controller.runJavaScript('''
      (function() {
        console.log('🔄 Starting ENHANCED pull-to-refresh for $contextName (tab: $tabIndex)...');
        
        // Configuration
        const PULL_THRESHOLD = ${thresholds['pullThreshold']};
        const MIN_PULL_SPEED = ${thresholds['minPullSpeed']};
        const channelName = '$refreshChannelName';
        const contextName = '$contextName';
        const elementId = '$elementId';
        const isSheetContext = '$contextName' === 'WEBVIEW SHEET';
        const isMainScreen = '$contextName' === 'MAIN SCREEN';
        const tabIndex = $tabIndex;
        
        // Remove any existing refresh elements for this tab
        const existing = document.getElementById(elementId);
        if (existing) {
          existing.remove();
          console.log('🗑️ Removed existing refresh element for ' + contextName);
        }
        
        // State variables
        let startY = 0;
        let currentPull = 0;
        let maxPull = 0;
        let isPulling = false;
        let isRefreshing = false;
        let canPull = false;
        let hasReachedThreshold = false;
        let refreshBlocked = false;
        let currentTheme = '$currentFlutterTheme';
        
        // ENHANCED: Unified content tracking for both main screen and sheet
        window.lastContentChangeTime = window.lastContentChangeTime || 0;
        
        // Function to detect current theme
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
        
        // 🆕 UNIFIED: Enhanced top detection for BOTH main screen AND sheet
        function isAtTop() {
          const scrollTop1 = window.pageYOffset || 0;
          const scrollTop2 = document.documentElement.scrollTop || 0;
          const scrollTop3 = document.body.scrollTop || 0;
          const scrollTop = Math.max(scrollTop1, scrollTop2, scrollTop3);
          
          // ✅ UNIFIED LOGIC: Use same sophisticated detection for BOTH contexts
          const isExactlyAtTop = scrollTop === 0;
          
          // Enhanced content change detection (for chatbots, dynamic content)
          const hasRecentContentChange = window.lastContentChangeTime && 
            (Date.now() - window.lastContentChangeTime) < 1000;
          
          // Enhanced container detection (same for both main screen and sheet)
          const dynamicContentSelectors = [
            '[style*="overflow"]',
            '.chat-container', 
            '.message-container', 
            '.content-container',
            '[data-dynamic-content="true"]',
            '[class*="chat"]',
            '[class*="message"]',
            '[class*="conversation"]',
            '[id*="chat"]',
            '[id*="message"]',
            'div[style*="overflow-y"]',
            'div[style*="scroll"]',
            '.scroll',
            '.scrollable',
            'main',
            'section',
            'article'
          ];
          
          const scrollableElements = document.querySelectorAll(dynamicContentSelectors.join(', '));
          let allContainersAtTop = true;
          let maxContainerScroll = 0;
          
          for (let element of scrollableElements) {
            const elementScrollTop = element.scrollTop || 0;
            if (elementScrollTop > 0) {
              allContainersAtTop = false;
              maxContainerScroll = Math.max(maxContainerScroll, elementScrollTop);
            }
          }
          
          // Check all divs with dynamic scrolling
          const allDivs = document.querySelectorAll('div');
          for (let div of allDivs) {
            const style = window.getComputedStyle(div);
            const hasOverflow = style.overflowY === 'scroll' || style.overflowY === 'auto';
            const hasHeight = div.scrollHeight > div.clientHeight;
            const scrollTop = div.scrollTop || 0;
            
            if (hasOverflow && hasHeight && scrollTop > 0) {
              allContainersAtTop = false;
              maxContainerScroll = Math.max(maxContainerScroll, scrollTop);
            }
          }
          
          // Enhanced scroll velocity detection
          const now = Date.now();
          const timeDiff = now - (window.lastScrollCheck || now);
          const scrollDiff = scrollTop - (window.lastScrollPosition || scrollTop);
          const scrollVelocity = timeDiff > 0 ? Math.abs(scrollDiff / timeDiff) : 0;
          
          window.lastScrollCheck = now;
          window.lastScrollPosition = scrollTop;
          
          // ✅ CONTEXT-SPECIFIC VELOCITY THRESHOLDS
          const velocityThreshold = isMainScreen ? 1.0 : 0.5;
          const isActivelyScrolling = scrollVelocity > velocityThreshold;
          
          const result = isExactlyAtTop && 
                         allContainersAtTop && 
                         !hasRecentContentChange && 
                         !isActivelyScrolling &&
                         maxContainerScroll === 0;
          
          // Enhanced logging for main screen (same as sheet)
          if (!result && isMainScreen && tabIndex === 0) {
            console.log('📍 Main Screen tab ' + tabIndex + ' NOT at top (ENHANCED):', {
              scrollTop: scrollTop,
              allContainersAtTop: allContainersAtTop,
              maxContainerScroll: maxContainerScroll,
              hasRecentContentChange: hasRecentContentChange,
              isActivelyScrolling: isActivelyScrolling,
              scrollVelocity: scrollVelocity.toFixed(2)
            });
          }
          
          return result;
        }
        
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
        
        // ✅ ENHANCED: Setup dynamic content monitoring for MAIN SCREEN (same as sheet)
        if (isMainScreen) {
          console.log('🔧 Setting up ENHANCED content monitoring for main screen...');
          
          // Enhanced content monitoring (same as sheet)
          let contentObserver = new MutationObserver(function(mutations) {
            let hasSignificantChange = false;
            
            mutations.forEach(function(mutation) {
              if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                for (let node of mutation.addedNodes) {
                  if (node.nodeType === Node.ELEMENT_NODE && 
                      (node.textContent.length > 10 || node.querySelectorAll('*').length > 0)) {
                    hasSignificantChange = true;
                    break;
                  }
                }
              }
              
              if (mutation.type === 'characterData' && mutation.target.textContent.length > 10) {
                hasSignificantChange = true;
              }
              
              if (mutation.type === 'attributes' && 
                  (mutation.attributeName === 'class' || mutation.attributeName === 'style') &&
                  mutation.target.closest('.chat-container, .message-container, .content-container, [data-dynamic-content="true"]')) {
                hasSignificantChange = true;
              }
            });
            
            if (hasSignificantChange) {
              window.lastContentChangeTime = Date.now();
              
              if (isPulling) {
                console.log('🛑 Main Screen: Cancelling pull due to content change');
                isPulling = false;
                hideRefresh();
                canPull = false;
              }
            }
          });
          
          contentObserver.observe(document.body, {
            childList: true,
            subtree: true,
            characterData: true,
            attributes: true,
            attributeFilter: ['class', 'style']
          });
        }
        
        // Prevent overscroll and setup proper scroll area
        if (isSheetContext) {
          document.body.style.cssText += \`
            overscroll-behavior-y: contain;
            overflow-anchor: none;
            -webkit-overflow-scrolling: touch;
            padding-top: 0px;
          \`;
          document.documentElement.style.scrollPaddingTop = '0px';
          document.body.style.marginTop = '0px';
        } else {
          document.body.style.cssText += \`
            overscroll-behavior-y: contain;
            overflow-anchor: none;
            -webkit-overflow-scrolling: touch;
          \`;
        }
        
        // Update refresh indicator
        function updateRefresh(distance) {
          const progress = Math.min(distance / PULL_THRESHOLD, 1);
          
          refreshDiv.style.opacity = progress > 0.1 ? '1' : '0';
          
          if (isSheetContext) {
            const translateY = Math.min(distance * 0.5, 80) - 60;
            refreshDiv.style.transform = \`translateX(-50%) translateY(\${translateY}px)\`;
            
            if (progress > 0.1) {
              const bodyTransform = Math.min(distance * 0.3, 30);
              document.body.style.transform = \`translateY(\${bodyTransform}px)\`;
              document.body.style.transition = 'transform 0.1s ease-out';
            }
          }
          
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
        }
        
        // Hide indicator
        function hideRefresh() {
          refreshDiv.style.opacity = '0';
          refreshDiv.classList.remove('refresh-ready', 'refresh-spinning');
          refreshDiv.querySelector('.refresh-progress').style.strokeDashoffset = '63';
          hasReachedThreshold = false;
          
          if (isSheetContext) {
            document.body.style.transform = 'translateY(0px)';
            document.body.style.transition = 'transform 0.2s ease-out';
            refreshDiv.style.transform = 'translateX(-50%) translateY(-60px)';
          }
          
          updateIndicatorTheme();
        }
        
        // Start refreshing animation
        function doRefresh() {
          if (isRefreshing || !hasReachedThreshold || !isRefreshAllowed()) {
            console.log(\`❌ \${contextName} refresh denied - isRefreshing: \${isRefreshing}, hasThreshold: \${hasReachedThreshold}, allowed: \${isRefreshAllowed()}\`);
            hideRefresh();
            return;
          }
          
          console.log('✅ ' + contextName + ' TAB ' + tabIndex + ' REFRESH TRIGGERED!');
          isRefreshing = true;
          
          refreshDiv.classList.remove('refresh-ready');
          refreshDiv.classList.add('refresh-spinning');
          refreshDiv.style.opacity = '1';
          
          if (isSheetContext) {
            refreshDiv.style.transform = 'translateX(-50%) translateY(20px)';
            document.body.style.transform = 'translateY(20px)';
          }
          
          updateIndicatorTheme();
          
          if (window[channelName]) {
            window[channelName].postMessage('refresh');
            console.log('📤 ' + contextName + ' tab ' + tabIndex + ' refresh message sent via channel: ' + channelName);
          } else {
            console.error('❌ Refresh channel not found: ' + channelName);
          }
          
          setTimeout(() => {
            hideRefresh();
            isRefreshing = false;
          }, 1500);
        }
        
        // ✅ ENHANCED: Touch event handlers with UNIFIED logic for both contexts
        document.addEventListener('touchstart', function(e) {
          if (isRefreshing || !isRefreshAllowed()) return;
          
          // Initialize scroll tracking (same for both contexts)
          window.lastScrollCheck = Date.now();
          window.lastScrollPosition = Math.max(
            window.pageYOffset || 0,
            document.documentElement.scrollTop || 0,
            document.body.scrollTop || 0
          );
          
          // ✅ UNIFIED: Small delay for scroll position settling (same for both contexts)
          const settleDelay = isMainScreen ? 5 : 10;
          
          setTimeout(function() {
            if (!e.defaultPrevented) {
              const currentlyAtTop = isAtTop();
              const currentScrollTop = Math.max(
                window.pageYOffset || 0,
                document.documentElement.scrollTop || 0,
                document.body.scrollTop || 0
              );
              
              if (currentlyAtTop) {
                canPull = true;
                startY = e.touches[0].clientY;
                currentPull = 0;
                maxPull = 0;
                isPulling = false;
                hasReachedThreshold = false;
                
                console.log('👆 ' + contextName + ' tab ' + tabIndex + ': Touch start at TOP (scroll: ' + currentScrollTop + 'px) - ready to pull');
              } else {
                canPull = false;
                if (isMainScreen && tabIndex === 0) {
                  console.log('🚫 ' + contextName + ' tab ' + tabIndex + ': Touch start NOT at top - scroll: ' + currentScrollTop + 'px');
                }
              }
            }
          }, settleDelay);
          
        }, { passive: false });
        
        document.addEventListener('touchmove', function(e) {
          if (!canPull || isRefreshing || !isRefreshAllowed()) return;
          
          const currentY = e.touches[0].clientY;
          const deltaY = currentY - startY;
          
          const currentScrollTop = Math.max(
            window.pageYOffset || 0,
            document.documentElement.scrollTop || 0,
            document.body.scrollTop || 0
          );
          
          // ✅ UNIFIED: Enhanced detection logic for BOTH contexts
          const isExactlyAtTop = currentScrollTop === 0;
          
          // Check for dynamic content changes
          const hasContentChanged = window.lastContentChangeTime && 
            (Date.now() - window.lastContentChangeTime) < 500;
          
          // Enhanced container scroll detection
          const dynamicContentSelectors = [
            '[style*="overflow"]', '.chat-container', '.message-container', 
            '.content-container', '[data-dynamic-content="true"]',
            '[class*="chat"]', '[class*="message"]', '[class*="conversation"]',
            '[id*="chat"]', '[id*="message"]', 'div[style*="overflow-y"]',
            'div[style*="scroll"]', '.scroll', '.scrollable', 'main', 'section', 'article'
          ];
          
          const scrollableElements = document.querySelectorAll(dynamicContentSelectors.join(', '));
          let allContainersAtTop = true;
          let maxContainerScroll = 0;
          
          for (let element of scrollableElements) {
            const elementScrollTop = element.scrollTop || 0;
            if (elementScrollTop > 0) {
              allContainersAtTop = false;
              maxContainerScroll = Math.max(maxContainerScroll, elementScrollTop);
            }
          }
          
          const allDivs = document.querySelectorAll('div');
          for (let div of allDivs) {
            const style = window.getComputedStyle(div);
            const hasOverflow = style.overflowY === 'scroll' || style.overflowY === 'auto';
            const hasHeight = div.scrollHeight > div.clientHeight;
            const scrollTop = div.scrollTop || 0;
            
            if (hasOverflow && hasHeight && scrollTop > 0) {
              allContainersAtTop = false;
              maxContainerScroll = Math.max(maxContainerScroll, scrollTop);
            }
          }
          
          // Check for any scrolling changes
          if (currentScrollTop !== window.lastScrollPosition) {
            console.log('🛑 ' + contextName + ': Page scrolling detected - cancelling pull');
            isPulling = false;
            hideRefresh();
            canPull = false;
            return;
          }
          
          if (maxContainerScroll > 0) {
            console.log('🛑 ' + contextName + ': Container scrolling detected - cancelling');
            isPulling = false;
            hideRefresh();
            canPull = false;
            return;
          }
          
          if (hasContentChanged) {
            console.log('🛑 ' + contextName + ': Content change detected - cancelling pull');
            isPulling = false;
            hideRefresh();
            canPull = false;
            return;
          }
          
          const stillAtTop = isExactlyAtTop && allContainersAtTop;
          
          if (!stillAtTop) {
            console.log('🛑 ' + contextName + ': NO LONGER at top - cancelling pull');
            isPulling = false;
            hideRefresh();
            canPull = false;
            return;
          }
          
          if (deltaY > 0 && stillAtTop && currentScrollTop === 0 && !hasContentChanged && maxContainerScroll === 0) {
            currentPull = deltaY;
            maxPull = Math.max(maxPull, deltaY);
            
            if (deltaY >= MIN_PULL_SPEED) {
              e.preventDefault();
              isPulling = true;
              updateRefresh(deltaY);
              console.log('🔄 ' + contextName + ' tab ' + tabIndex + ': Valid pull - ' + deltaY + 'px');
            }
          } else {
            isPulling = false;
            hideRefresh();
            canPull = false;
          }
          
        }, { passive: false });
        
        document.addEventListener('touchend', function(e) {
          if (!isPulling || isRefreshing || !isRefreshAllowed()) {
            isPulling = false;
            canPull = false;
            hasReachedThreshold = false;
            return;
          }
          
          const finallyAtTop = isAtTop();
          const validPull = hasReachedThreshold && maxPull >= PULL_THRESHOLD;
          
          console.log('🏁 ' + contextName + ' tab ' + tabIndex + ' FINAL CHECK:', {
            finallyAtTop: finallyAtTop,
            validPull: validPull,
            maxPull: maxPull,
            threshold: PULL_THRESHOLD,
            hasReachedThreshold: hasReachedThreshold
          });
          
          if (validPull && finallyAtTop) {
            console.log('✅ ' + contextName + ' tab ' + tabIndex + ' SUCCESS: Valid pull-to-refresh!');
            doRefresh();
          } else {
            console.log('❌ ' + contextName + ' tab ' + tabIndex + ' FAIL: Invalid pull-to-refresh');
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
        
        console.log('✅ ' + contextName + ' TAB ' + tabIndex + ' pull-to-refresh ready with ENHANCED detection!');
        console.log('🎨 Theme from Flutter:', currentTheme);
        console.log('📋 Context-specific mode:', contextName);
        console.log('🔗 Channel name:', channelName);
        console.log('🔧 Enhanced content monitoring:', isMainScreen ? 'ENABLED' : 'SHEET_MODE');
        
      })();
      ''');

      debugPrint(
        '✅ ENHANCED pull-to-refresh injected for $contextName (tab: $tabIndex) with unified detection',
      );
    } catch (e) {
      debugPrint('❌ Error injecting enhanced pull-to-refresh: $e');
    }
  }

  // Keep existing helper methods unchanged...
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
        return 'enhanced-refresh-main-$tabIndex';
      case RefreshContext.webViewPage:
        return 'enhanced-refresh-page';
      case RefreshContext.sheetWebView:
        return 'enhanced-refresh-sheet';
    }
  }

  Map<String, int> _getThresholds(RefreshContext context) {
    switch (context) {
      case RefreshContext.mainScreen:
        // MAIN SCREEN: Enhanced thresholds for better chatbot support
        return {'pullThreshold': 450, 'minPullSpeed': 150};
      case RefreshContext.webViewPage:
        return {'pullThreshold': 450, 'minPullSpeed': 150};
      case RefreshContext.sheetWebView:
        // SHEET: Higher thresholds for better control with dynamic content
        return {'pullThreshold': 500, 'minPullSpeed': 200};
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
          'top': '0px',
          'transform': 'translateX(-50%) translateY(-60px)',
        };
    }
  }
}
